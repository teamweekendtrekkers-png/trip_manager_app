import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/services/trip_date_utils.dart';
import 'package:trip_manager_app/services/trips_parser.dart';

void main() {
  group('Trip editor payload compatibility', () {
    test('the editor-shaped payload generates every website field', () {
      final generated = TripsParser.generateTripsDataJs(<Map<String, dynamic>>[
        _editorPayload(),
      ]);

      for (final field in <String>[
        'title:',
        'location:',
        'badge:',
        'featured:',
        'price:',
        'image:',
        'distance:',
        'elevation:',
        'difficulty:',
        'bestTime:',
        'duration:',
        'availableDates:',
        'about:',
        'highlights:',
        'itinerary:',
        'includes:',
        'excludes:',
        'thingsToCarry:',
        'boardingLocations:',
        'galleryImages:',
        'groupSize:',
        'isActive:',
      ]) {
        expect(generated, contains(field), reason: 'missing $field');
      }
      expect(generated, contains('function getTripData(tripId)'));
    });

    test('editor changes survive a production parser round-trip', () {
      final initial = TripsParser.generateTripsDataJs(<Map<String, dynamic>>[
        _editorPayload(),
      ]);
      final editable = TripsParser.parseTripsData(initial).single
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
      expect(parsedAgain['itinerary'], hasLength(2));
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

    test('source-preserving publish changes only the trips object span', () {
      final generated = TripsParser.generateTripsDataJs(<Map<String, dynamic>>[
        _editorPayload(),
      ]);
      const prefix = '// hand-maintained website prefix\n';
      const suffix = '\n// hand-maintained website suffix\n';
      final declaration = RegExp(
        r'const\s+tripsData\s*=\s*\{',
      ).firstMatch(generated)!;
      final source = '$prefix${generated.substring(declaration.start)}$suffix';
      final trips = TripsParser.parseTripsData(source);
      trips.single['price'] = '₹5,250';

      final write = TripsParser.replaceTripsDataObject(
        source: source,
        trips: trips,
      );

      expect(write.success, isTrue, reason: write.error);
      expect(write.content, startsWith(prefix));
      expect(write.content, endsWith(suffix));
      expect(
        TripsParser.parseTripsData(write.content!).single['price'],
        '₹5,250',
      );
    });
  });
}

Map<String, dynamic> _editorPayload() => <String, dynamic>{
  'id': 'netravati',
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
  'boardingLocations': <Map<String, dynamic>>[],
  'galleryImages': <String>[],
};
