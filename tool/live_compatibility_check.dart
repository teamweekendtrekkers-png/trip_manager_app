import 'dart:convert';
import 'dart:io';

import 'package:trip_manager_app/services/trip_date_utils.dart';
import 'package:trip_manager_app/services/trips_parser.dart';

const _commit = '2bf3f5003e6f14e65f32c7533c61ccf2265abd10';
const _owner = 'teamweekendtrekkers-png';
const _repository = 'teamweekendtrekkerwebsite';

Future<void> main() async {
  final client = HttpClient();
  try {
    final tripsSource = await _readRawFile(client, 'js/trips-data.js');
    final featuredSource = await _readRawFile(client, 'js/featured-trips.js');

    final document = TripsParser.parseTripsDocument(tripsSource);
    _check(document.isValid, document.errors.join('\n'));
    _check(document.trips.length == 25, 'Expected 25 trips.');
    final roundTrip = TripsParser.replaceTripsDataObject(
      source: tripsSource,
      trips: document.trips,
    );
    _check(roundTrip.success, roundTrip.error ?? 'Trip rewrite failed.');
    final reparsed = TripsParser.parseTripsDocument(roundTrip.content!);
    _check(reparsed.isValid, reparsed.errors.join('\n'));
    _check(
      _deepEquals(document.trips, reparsed.trips),
      'Trip values changed during a source-preserving round trip.',
    );
    _check(
      document.document!.prefix == reparsed.document!.prefix &&
          document.document!.suffix == reparsed.document!.suffix,
      'Source outside the tripsData object changed.',
    );

    final dates = document.trips
        .expand(
          (trip) => (trip['availableDates'] as List<dynamic>? ?? const []),
        )
        .toList();
    _check(dates.length == 116, 'Expected 116 availableDates entries.');
    final invalidDates = dates
        .where((date) => TripDateUtils.parse(date.toString()) == null)
        .toList();
    _check(invalidDates.isEmpty, 'Invalid live date values: $invalidDates');

    final featured = TripsParser.parseFeaturedTripsDocument(featuredSource);
    _check(featured.isValid, featured.errors.join('\n'));
    final embeddedFeatured = document.trips
        .where((trip) => trip['featured'] == true)
        .map((trip) => trip['id'].toString())
        .toList();
    _check(
      _sameValues(featured.ids, embeddedFeatured),
      'Featured files drift at $_commit.',
    );

    final batches = TripDateUtils.buildUpcomingBatches(
      document.trips,
      referenceDate: DateTime.utc(2026, 8, 13),
    );
    _check(
      batches.map((batch) => batch.key).toList().join('|') ==
          '2026-08-14/2026-08-16|2026-08-21/2026-08-23|2026-08-28/2026-08-30',
      'Unexpected upcoming batch ranges: '
      '${batches.map((batch) => batch.key).toList()}',
    );
    const expectedTripIds = {
      'theyyam',
      'wayanad',
      'rameshwaram-dhanushkodi',
      'wayanad-pool-party',
    };
    for (final batch in batches) {
      _check(
        batch.trips
                .map((trip) => trip.id)
                .toSet()
                .containsAll(expectedTripIds) &&
            batch.trips.length == expectedTripIds.length,
        'Unexpected trips for ${batch.key}: '
        '${batch.trips.map((trip) => trip.id).toList()}',
      );
    }

    stdout.writeln(
      'PASS $_commit: 25 trips, 116 valid date entries, '
      'featured sources synchronized, and 3 expected August batches.',
    );
  } finally {
    client.close(force: true);
  }
}

Future<String> _readRawFile(HttpClient client, String path) async {
  final uri = Uri.https(
    'raw.githubusercontent.com',
    '/$_owner/$_repository/$_commit/$path',
  );
  final request = await client.getUrl(uri);
  final response = await request.close();
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException('GET $path returned ${response.statusCode}', uri: uri);
  }
  return response.transform(utf8.decoder).join();
}

bool _sameValues(List<String> left, List<String> right) =>
    left.length == right.length &&
    List<bool>.generate(
      left.length,
      (index) => left[index] == right[index],
    ).every((matches) => matches);

bool _deepEquals(Object? left, Object? right) {
  if (identical(left, right)) return true;
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_deepEquals(left[index], right[index])) return false;
    }
    return true;
  }
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final key in left.keys) {
      if (!right.containsKey(key) || !_deepEquals(left[key], right[key])) {
        return false;
      }
    }
    return true;
  }
  return left == right;
}

Never _fail(String message) => throw StateError(message);

void _check(bool condition, String message) {
  if (!condition) _fail(message);
}
