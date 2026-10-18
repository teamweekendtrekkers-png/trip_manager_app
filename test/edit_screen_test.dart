import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/services/trip_date_utils.dart';
import 'package:trip_manager_app/services/trips_parser.dart';

void main() {
  group('Trip editor payload compatibility', () {
    test('editor changes survive a production parser round-trip', () {
      final initial = TripsParser.generateTripsDataJs(<Map<String, dynamic>>[
        _editorPayload(),
      ]);
      expect(initial, contains('"netravati-trek":'));
      expect(initial, contains('function getTripData(tripId)'));
      final document = TripsParser.parseTripsDocument(initial);
      expect(document.isValid, isTrue, reason: document.errors.join('\n'));
      final editable = document.trips.single
        ..['title'] = 'Updated Netravati Trek'
        ..['name'] = 'Updated Netravati Trek'
        ..['price'] = '₹5,000'
        ..['availableDates'] = <String>['Aug 14-16, 2026', 'Aug 21-23, 2026']
        ..['highlights'] = <String>['New highlight 1', 'New highlight 2'];

      final parsedAgain = TripsParser.parseTripsData(
        TripsParser.generateTripsDataJs(<Map<String, dynamic>>[editable]),
      ).single;

      expect(parsedAgain['title'], 'Updated Netravati Trek');
      expect(parsedAgain['price'], '₹5,000');
      expect(parsedAgain['badge'], 'Weekend Trek');
      expect(parsedAgain['distance'], '15-20 km');
      expect(parsedAgain['duration'], '2D/1N');
      expect(parsedAgain['bestTime'], 'Oct - Feb');
      expect(parsedAgain['availableDates'], <String>[
        'Aug 14-16, 2026',
        'Aug 21-23, 2026',
      ]);
      expect(parsedAgain['highlights'], <String>[
        'New highlight 1',
        'New highlight 2',
      ]);
      // Compare values, not only generated field names: omission of an
      // editable field must fail even if generation and parsing agree.
      final original = _editorPayload();
      for (final field in [
        'id', 'location', 'about', 'badge', 'image', 'distance', 'elevation',
        'difficulty', 'bestTime', 'duration', 'groupSize', 'featured',
        'isActive', 'thingsToCarry', 'boardingLocations',
        'galleryImages',
      ]) {
        expect(parsedAgain[field], original[field], reason: field);
      }
      expect(parsedAgain['name'], parsedAgain['title']);
      expect(parsedAgain['destination'], original['location']);
      expect(parsedAgain['description'], original['about']);
      expect(parsedAgain['date'], 'Aug 14-16, 2026');
      expect(parsedAgain['priceNumeric'], 5000);
      final itinerary = parsedAgain['itinerary'] as List;
      final originalItinerary = original['itinerary'] as List;
      expect(itinerary, hasLength(originalItinerary.length));
      for (var index = 0; index < itinerary.length; index++) {
        final before = originalItinerary[index] as Map;
        final after = itinerary[index] as Map;
        for (final field in ['day', 'title', 'activities']) {
          expect(after[field], before[field], reason: 'itinerary[$index].$field');
        }
        expect(after['description'], (before['activities'] as List).join('\n'));
      }
      expect(parsedAgain['inclusions'], <String>['Transport', 'Meals']);
      expect(parsedAgain['exclusions'], <String>['Personal expenses']);
    });

    test('calendar labels are canonical before entering the payload', () {
      final selected = TripDateUtils.fromDates(
        DateTime(2026, 8, 14),
        DateTime(2026, 8, 16),
      );
      final payload = _editorPayload()
        ..['availableDates'] = <String>[
          TripDateUtils.formatCanonical(selected),
        ];

      final parsed = TripsParser.parseTripsData(
        TripsParser.generateTripsDataJs(<Map<String, dynamic>>[payload]),
      ).single;

      expect(parsed['availableDates'], <String>['Aug 14-16, 2026']);
      expect(
        TripDateUtils.parse((parsed['availableDates'] as List).single)!.key,
        '2026-08-14/2026-08-16',
      );
    });
  });
}

Map<String, dynamic> _editorPayload() => <String, dynamic>{
  'id': 'netravati-trek',
  'title': 'Netravati Peak Trek',
  'name': 'Netravati Peak Trek',
  'location': 'Western Ghats, Karnataka',
  'destination': 'Western Ghats, Karnataka',
  'about': 'Test description with\nnewlines',
  'description': 'Test description with\nnewlines',
  'date': 'Jan 18-19, 2026',
  'price': '₹4,000',
  'image': 'images/trips/netravati.jpg',
  'groupSize': '20',
  'pickupPoint': 'Bangalore',
  'difficulty': 'Moderate',
  'featured': false,
  'isActive': true,
  'badge': 'Weekend Trek',
  'distance': '15-20 km',
  'elevation': '1,420 m',
  'bestTime': 'Oct - Feb',
  'duration': '2D/1N',
  'availableDates': <String>['Jan 18-19, 2026', 'Feb 15-16, 2026'],
  'highlights': <String>['Highlight 1', 'Highlight 2'],
  'itinerary': <Map<String, dynamic>>[
    <String, dynamic>{
      'day': 'Day 0',
      'title': 'Night Departure',
      'activities': <String>['10 PM - Pickup'],
    },
    <String, dynamic>{
      'day': 'Day 1',
      'title': 'Trek Day',
      'activities': <String>['6 AM - Start'],
    },
  ],
  'inclusions': <String>['Transport', 'Meals'],
  'exclusions': <String>['Personal expenses'],
  'thingsToCarry': <String>['Shoes'],
  'boardingLocations': <Map<String, dynamic>>[
    <String, dynamic>{
      'name': 'Majestic',
      'landmark': 'Metro station',
      'time': '9 PM',
      'mapLink': 'https://maps.test/majestic',
    },
  ],
  'galleryImages': <String>['images/gallery/netravati/one.jpg'],
};
