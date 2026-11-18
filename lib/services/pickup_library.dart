import 'trips_parser.dart';

String safePickupMapLink(Object? value) {
  final text = value?.toString().trim() ?? '';
  final uri = Uri.tryParse(text);
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host.contains('.') &&
          uri.userInfo.isEmpty &&
          !RegExp(r'\s').hasMatch(text)
      ? text
      : '';
}

String pickupIdentity(Map<String, dynamic> point) => [
  for (final key in ['name', 'landmark', 'time'])
    (point[key]?.toString() ?? '')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase(),
  safePickupMapLink(point['mapLink']),
].join('\u0000');

class PickupLibraryEntry {
  PickupLibraryEntry(this.point);
  final Map<String, dynamic> point;
  final Set<String> trips = {};
  String get id => pickupIdentity(point);
  bool matches(String query) => '${point.values.join(' ')} ${trips.join(' ')}'
      .toLowerCase()
      .contains(query.trim().toLowerCase());
}

/// Derive the catalogue from trip data instead of keeping a second, stale copy.
List<PickupLibraryEntry> buildPickupLibrary(List<Map<String, dynamic>> trips) {
  final entries = <String, PickupLibraryEntry>{};
  void add(Map raw, String source) {
    final point = <String, dynamic>{
      for (final key in ['name', 'landmark', 'time', 'mapLink'])
        key: raw[key]?.toString() ?? '',
    };
    if ((point['name'] as String).trim().isEmpty) return;
    final entry = entries.putIfAbsent(
      pickupIdentity(point),
      () => PickupLibraryEntry(point),
    );
    entry.trips.add(source);
  }

  final defaults = TripsParser.getDefaultPickupPoints();
  for (final point in defaults) {
    add(point, 'Website defaults');
  }
  for (final trip in trips) {
    final raw = trip['boardingLocations'];
    final points = raw is List && raw.isNotEmpty ? raw : defaults;
    final title =
        trip['title']?.toString() ?? trip['id']?.toString() ?? 'Untitled trip';
    for (final point in points.whereType<Map>()) {
      add(point, title);
    }
  }
  return entries.values.toList()..sort((a, b) {
    final byName = a.point['name'].toString().toLowerCase().compareTo(
      b.point['name'].toString().toLowerCase(),
    );
    return byName != 0 ? byName : a.id.compareTo(b.id);
  });
}

/// Preserve order and never share editable maps with another trip or defaults.
List<Map<String, dynamic>> mergePickupPoints(
  List<Map<String, dynamic>> current,
  Iterable<Map<String, dynamic>> additions,
) {
  final result = current
      .map((point) => Map<String, dynamic>.from(point))
      .toList();
  final seen = current.map(pickupIdentity).toSet();
  for (final point in additions) {
    if (seen.add(pickupIdentity(point)))
      result.add({...point, 'mapLink': safePickupMapLink(point['mapLink'])});
  }
  return result;
}
