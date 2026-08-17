import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/services/trips_parser.dart';

void main() {
  test('generated preview is parseable and preserves website fields', () {
    final trip = <String, dynamic>{
      'id': 'test-trip',
      'title': 'Test Trip',
      'location': 'Test Location',
      'price': '₹5000',
      'badge': 'Trek',
      'image': 'images/trips/test.jpg',
      'difficulty': 'Moderate',
      'distance': '10 km',
      'elevation': '1000 m',
      'bestTime': 'Oct-Feb',
      'duration': '2D/1N',
      'availableDates': ['Jan 1-2, 2027'],
      'about': 'Test description',
      'highlights': ['View', 'Trek'],
      'itinerary': [
        {
          'day': 'Day 1',
          'title': 'Trek',
          'activities': ['6AM - Start', '12PM - Summit'],
        },
      ],
      'inclusions': ['Transport'],
      'exclusions': ['Food'],
      'thingsToCarry': <String>[],
      'boardingLocations': <Map<String, dynamic>>[],
      'galleryImages': <String>[],
      'groupSize': '20',
      'featured': false,
      'isActive': true,
    };

    final generated = TripsParser.generateTripsDataJs([trip]);
    final parsed = TripsParser.parseTripsDocument(generated);

    expect(parsed.isValid, isTrue, reason: parsed.errors.join('\n'));
    expect(parsed.trips.single['id'], 'test-trip');
    expect(parsed.trips.single['availableDates'], ['Jan 1-2, 2027']);
    expect(parsed.trips.single['itinerary'], hasLength(1));
  });
}
