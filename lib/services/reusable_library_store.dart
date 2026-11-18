import 'dart:convert';
import 'draft_store.dart';
import 'pickup_library.dart';
import 'carry_library.dart';

String libraryDataId(String kind, Map<String, dynamic> data) => kind == 'pickup'
    ? pickupIdentity(data)
    : carryIdentity(data['text']?.toString() ?? '');

class LibraryRecord {
  LibraryRecord(this.key, Map<String, dynamic> value, Iterable<String> sources)
    : data = Map<String, dynamic>.from(value),
      sources = sources.toSet();
  final String key;
  final Map<String, dynamic> data;
  final Set<String> sources;
}

class LibraryChanges {
  LibraryChanges({
    Set<String>? hidden,
    Map<String, Map<String, dynamic>>? values,
  }) : hidden = {...?hidden},
       values = {
         for (final e in (values ?? <String, Map<String, dynamic>>{}).entries)
           e.key: Map<String, dynamic>.from(e.value),
       };
  final Set<String> hidden;
  final Map<String, Map<String, dynamic>> values;
  Map<String, dynamic> toJson() => {
    'hidden': hidden.toList(),
    'values': values,
  };
  LibraryChanges copy() => LibraryChanges(hidden: hidden, values: values);
  static LibraryChanges fromJson(Map data) {
    return LibraryChanges(
      hidden: (data['hidden'] is List ? data['hidden'] as List : [])
          .whereType<String>()
          .toSet(),
      values: {
        for (final e
            in (data['values'] is Map ? data['values'] as Map : {}).entries)
          if (e.key is String && e.value is Map)
            e.key as String: {
              for (final field in (e.value as Map).entries)
                if (field.key is String && field.value is String)
                  field.key as String: field.value,
            },
      },
    );
  }

  List<LibraryRecord> records(List<LibraryRecord> base) {
    final keys = base.map((r) => r.key).toSet();
    return [
      for (final record in base)
        LibraryRecord(
          record.key,
          values[record.key] ?? record.data,
          record.sources,
        ),
      for (final entry in values.entries)
        if (!keys.contains(entry.key))
          LibraryRecord(entry.key, entry.value, ['Saved on this device']),
    ];
  }
}

/// Library changes stay separate from trip data and are scoped to this checkout target.
class ReusableLibraryStore {
  ReusableLibraryStore({required this.kind, required this.scope});
  ReusableLibraryStore.memory(this.kind) : scope = null;
  final String kind;
  final String? scope;
  LibraryChanges _memory = LibraryChanges();
  String get _slot => 'reusable-library:$kind';
  LibraryChanges load() {
    if (scope == null) return _memory.copy();
    final raw = DraftStore.read(scope!, _slot)?['data'];
    return raw is Map ? LibraryChanges.fromJson(raw) : LibraryChanges();
  }

  Future<void> save(LibraryChanges changes) async {
    // Validate JSON before replacing either the disk or memory snapshot.
    final copy = LibraryChanges.fromJson(
      jsonDecode(jsonEncode(changes.toJson())) as Map,
    );
    if (scope != null) {
      if (!DraftStore.available)
        throw StateError('Local library storage unavailable');
      await DraftStore.write(scope!, _slot, copy.toJson());
    }
    _memory = copy;
  }
}

List<LibraryRecord> pickupRecords(List<PickupLibraryEntry> entries) => [
  for (final e in entries) LibraryRecord(e.id, e.point, e.trips),
];
List<LibraryRecord> carryRecords(List<CarryLibraryItem> entries) => [
  for (final e in entries) LibraryRecord(e.id, {'text': e.text}, e.trips),
];

List<PickupLibraryEntry> resolvePickupLibrary(
  List<PickupLibraryEntry> base,
  ReusableLibraryStore store,
) {
  final changes = store.load(), result = <String, PickupLibraryEntry>{};
  for (final record in changes.records(pickupRecords(base))) {
    if (changes.hidden.contains(libraryDataId('pickup', record.data))) continue;
    final data = {
      for (final key in ['name', 'landmark', 'time', 'mapLink'])
        key: record.data[key]?.toString() ?? '',
    };
    if (data['name']!.trim().isEmpty) continue;
    final entry = result.putIfAbsent(
      pickupIdentity(data),
      () => PickupLibraryEntry(data),
    );
    entry.trips.addAll(record.sources);
  }
  return result.values.toList()..sort((a, b) => a.id.compareTo(b.id));
}

List<CarryLibraryItem> resolveCarryLibrary(
  List<CarryLibraryItem> base,
  ReusableLibraryStore store,
) {
  final changes = store.load(), result = <String, CarryLibraryItem>{};
  for (final record in changes.records(carryRecords(base))) {
    if (changes.hidden.contains(libraryDataId('carry', record.data))) continue;
    final text = record.data['text']?.toString() ?? '';
    if (text.trim().isEmpty) continue;
    final entry = result.putIfAbsent(
      carryIdentity(text),
      () => CarryLibraryItem(text),
    );
    entry.trips.addAll(record.sources);
  }
  return result.values.toList()..sort((a, b) => a.id.compareTo(b.id));
}
