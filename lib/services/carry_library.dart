import 'trip_detail_defaults.dart';

String carryIdentity(String text) {
  var plain = text;
  final markers = RegExp(r'(\*{1,3})(?=\S)([\s\S]*?\S|\S)\1(?!\*)');
  for (var depth = 0; depth < 12; depth++) {
    final next = plain.replaceAllMapped(markers, (m) => m.group(2)!);
    if (next == plain) break;
    plain = next;
  }
  return plain.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

/// Recognise pasted checklists conservatively; never rewrite the source trip.
List<String> splitCarryChecklist(String text) {
  if (text.length < 200) return [text];
  final bullets = RegExp(
    r'[•▪●]\s*(?=\S)',
  ).allMatches(text).map((m) => m.start).toList();
  final lines = RegExp(
    r'(?:^|\n)[ \t]*(?:[-*]\s+|\d+[.)]\s+)',
  ).allMatches(text).map((m) => m.start).toList();
  const labels =
      r'(?:Small\s+)?Backpack|(?:Good\s+)?Trekking\s+Shoes|Water\s+Bottle|Raincoat|Extra(?:\s+Pair\s+of)?\s+Clothes|Extra\s+Socks|Flip[-\s]?flops|Slippers|Power\s+Bank|Mobile\s+Charger|Phone\s*&|Camera|(?:Extra\s+)?Cash|Personal\s+(?:Medicines|Toiletries)|Toiletries|(?:Plastic\s+)?(?:Waterproof\s*\/\s*)?Zip[-\s]?lock\s+Bags|Cap\s*(?:&|\/|$)|Sunglasses|Sunscreen|Energy\s+Snacks|Small\s+Waterproof\s+Bags';
  final emoji = RegExp(
    r'(?:🎒|💧|🧥|👕|🧦|👟|🥾|🩴|📱|🔋|📷|📸|💵|💊|🧴|🛍|🧢|🕶|🩹|🗑|🌧|🍫)\uFE0F?\s*(?=' +
        labels +
        ')',
    caseSensitive: false,
    unicode: true,
  ).allMatches(text).map((m) => m.start).toList();
  final boundaries = bullets.length >= 3
      ? bullets
      : lines.length >= 3
      ? lines
      : emoji;
  if (boundaries.length < 3) return [text];
  final notes = RegExp(
    r'(?:✨\s*(?:Pack light|Travel light)|⚠️?\s*Trek Essentials)',
    caseSensitive: false,
    unicode: true,
  ).allMatches(text).map((m) => m.start);
  final starts = {0, ...boundaries, ...notes}.toList()..sort();
  return [
    for (var i = 0; i < starts.length; i++)
      text
          .substring(
            starts[i],
            i + 1 < starts.length ? starts[i + 1] : text.length,
          )
          .trim(),
  ].where((s) => s.isNotEmpty).toList();
}

class CarryLibraryItem {
  CarryLibraryItem(this.text);
  final String text;
  final Set<String> trips = {};
  String get id => carryIdentity(text);
  bool matches(String query) => '${text.replaceAll('*', '')} ${trips.join(' ')}'
      .toLowerCase()
      .contains(query.trim().toLowerCase());
}

List<CarryLibraryItem> buildCarryLibrary(List<Map<String, dynamic>> trips) {
  final entries = <String, CarryLibraryItem>{};
  void add(String text, String source) {
    final pieces = splitCarryChecklist(text);
    for (var index = 0; index < pieces.length; index++) {
      final item = pieces[index];
      // Keep a pasted checklist's heading with its source, not the new list.
      if (pieces.length > 1 &&
          index == 0 &&
          RegExp(
            r'things\s+to\s+carry|packing\s+checklist',
            caseSensitive: false,
          ).hasMatch(item))
        continue;
      if (item.trim().isEmpty) continue;
      final entry = entries.putIfAbsent(
        carryIdentity(item),
        () => CarryLibraryItem(item),
      );
      entry.trips.add(source);
    }
  }

  for (final item in TripDetailDefaults.thingsToCarry) {
    add(item, 'Standard checklist');
  }
  for (final trip in trips) {
    final raw = trip['thingsToCarry'];
    final items = raw is List
        ? raw.whereType<String>()
        : TripDetailDefaults.thingsToCarry;
    for (final item in items) {
      add(
        item,
        trip['title']?.toString() ?? trip['id']?.toString() ?? 'Untitled trip',
      );
    }
  }
  return entries.values.toList()..sort((a, b) => a.id.compareTo(b.id));
}

Set<String> includedCarryItems(List<String> items) =>
    items.expand(splitCarryChecklist).map(carryIdentity).toSet();

List<String> mergeCarryItems(List<String> current, Iterable<String> additions) {
  final result = List<String>.from(current), seen = includedCarryItems(current);
  for (final item in additions) {
    if (item.trim().isNotEmpty && seen.add(carryIdentity(item)))
      result.add(item);
  }
  return result;
}
