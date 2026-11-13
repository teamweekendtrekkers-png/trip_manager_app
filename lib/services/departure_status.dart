import 'trip_date_utils.dart';

String departureStatus(Map<String, dynamic> trip, String key) {
  if ((trip['soldOutDepartures'] as List? ?? []).contains(key)) {
    return 'sold-out';
  }
  if ((trip['closedDepartures'] as List? ?? []).contains(key)) {
    return 'closed';
  }
  if ((trip['confirmedDepartures'] as List? ?? []).contains(key)) {
    return 'confirmed';
  }
  return 'available';
}

Map<String, dynamic> setDepartureStatus(
  Map<String, dynamic> source,
  String key,
  String status,
) {
  if (!['available', 'confirmed', 'sold-out', 'closed'].contains(status) ||
      !(source['availableDates'] as List? ?? []).any(
        (label) => TripDateUtils.parse(label.toString())?.key == key,
      )) {
    throw ArgumentError('Choose an existing departure and a valid status.');
  }
  final result = Map<String, dynamic>.from(source);
  for (final field in [
    'confirmedDepartures',
    'soldOutDepartures',
    'closedDepartures',
  ]) {
    final values = List<String>.from(source[field] as List? ?? [])
      ..removeWhere((value) => value == key);
    if ((field == 'confirmedDepartures' && status == 'confirmed') ||
        (['soldOutDepartures', 'closedDepartures'].contains(field) &&
            status == 'sold-out') ||
        (field == 'closedDepartures' && status == 'closed')) {
      values.add(key);
    }
    result[field] = values;
  }
  return result;
}
