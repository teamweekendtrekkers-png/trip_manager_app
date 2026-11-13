import 'trip_date_utils.dart';

Map<String, dynamic> setDepartureStatus(
  Map<String, dynamic> source,
  String key,
  String status,
) {
  if (!['available', 'confirmed', 'sold-out'].contains(status) ||
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
            status == 'sold-out')) {
      values.add(key);
    }
    result[field] = values;
  }
  return result;
}
