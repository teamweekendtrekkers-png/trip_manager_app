import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/services/trips_parser.dart';

void main() {
  test('embedded featured flags canonically generate the companion array', () {
    final trips = <Map<String, dynamic>>[
      {'id': 'gokarna', 'featured': true},
      {'id': 'rameshwaram', 'featured': true},
      {'id': 'nandi-hills', 'featured': false},
      {'id': 'ooty', 'featured': false},
    ];

    var generated = TripsParser.generateFeaturedTripsJs(trips);
    expect(TripsParser.parseFeaturedTripIds(generated), [
      'gokarna',
      'rameshwaram',
    ]);

    trips[2]['featured'] = true;
    generated = TripsParser.generateFeaturedTripsJs(trips);
    expect(TripsParser.parseFeaturedTripIds(generated), [
      'gokarna',
      'rameshwaram',
      'nandi-hills',
    ]);

    trips[2]['featured'] = false;
    expect(
      TripsParser.parseFeaturedTripIds(
        TripsParser.generateFeaturedTripsJs(trips),
      ),
      ['gokarna', 'rameshwaram'],
    );
  });
}
