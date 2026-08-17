import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/services/trips_parser.dart';
import 'package:trip_manager_app/services/website_settings_service.dart';

void main() {
  group('Trip Manager deterministic characterization', () {
    test('parses quoted and unquoted IDs with the complete editor schema', () {
      final source = TripsParser.generateTripsDataJs(<Map<String, dynamic>>[
        _trip(id: 'netravati', title: 'Netravati Peak Trek', featured: true),
        _trip(id: 'nandi-hills', title: 'Nandi Hills Sunrise'),
      ]);

      final document = TripsParser.parseTripsDocument(source);

      expect(document.isValid, isTrue, reason: document.errors.join('\n'));
      expect(document.trips, hasLength(2));
      expect(document.trips.map((trip) => trip['id']), <String>[
        'netravati',
        'nandi-hills',
      ]);

      final first = document.trips.first;
      expect(first['title'], 'Netravati Peak Trek');
      expect(first['name'], first['title']);
      expect(first['location'], 'Western Ghats, Karnataka');
      expect(first['destination'], first['location']);
      expect(first['about'], 'A deterministic trek fixture.');
      expect(first['badge'], 'Weekend Trek');
      expect(first['price'], '₹4,000');
      expect(first['priceNumeric'], 4000);
      expect(first['availableDates'], <String>[
        'Jan 18-19, 2026',
        'Feb 15-16, 2026',
      ]);
      expect(first['highlights'], <String>['Waterfalls', 'Camping']);
      expect(first['itinerary'], hasLength(2));
      expect(first['inclusions'], <String>['Transport', 'Meals']);
      expect(first['exclusions'], <String>['Personal expenses']);
      expect(first['boardingLocations'], hasLength(1));
      expect(first['galleryImages'], hasLength(1));
      expect(first['featured'], isTrue);
      expect(first['isActive'], isTrue);
    });

    test(
      'generate, edit, and parse round-trip preserves public website data',
      () {
        final original = _trip(id: 'nandi-hills', title: 'Nandi Hills Sunrise');
        final generated = TripsParser.generateTripsDataJs(
          <Map<String, dynamic>>[original],
        );

        expect(generated, contains('"nandi-hills":'));
        expect(generated, contains('function getTripData(tripId)'));
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
          'groupSize:',
          'isActive:',
        ]) {
          expect(generated, contains(field), reason: 'missing $field');
        }

        final parsed = TripsParser.parseTripsData(generated);
        parsed.single
          ..['title'] = 'Updated Nandi Hills Sunrise'
          ..['name'] = 'Updated Nandi Hills Sunrise'
          ..['price'] = '₹5,000'
          ..['highlights'] = <String>['New sunrise point'];

        final roundTripped = TripsParser.parseTripsData(
          TripsParser.generateTripsDataJs(parsed),
        ).single;

        expect(roundTripped['id'], 'nandi-hills');
        expect(roundTripped['title'], 'Updated Nandi Hills Sunrise');
        expect(roundTripped['price'], '₹5,000');
        expect(roundTripped['highlights'], <String>['New sunrise point']);
        expect(roundTripped['badge'], original['badge']);
        expect(roundTripped['distance'], original['distance']);
        expect(roundTripped['duration'], original['duration']);
        expect(roundTripped['bestTime'], original['bestTime']);
        expect(roundTripped['availableDates'], original['availableDates']);
        expect(roundTripped['itinerary'], hasLength(2));
      },
    );

    test('source-preserving writes retain surrounding website helpers', () {
      final generated = TripsParser.generateTripsDataJs(<Map<String, dynamic>>[
        _trip(id: 'netravati', title: 'Netravati Peak Trek'),
      ]);
      final declaration = RegExp(
        r'const\s+tripsData\s*=\s*\{',
      ).firstMatch(generated)!;
      final source =
          '// custom prefix retained\n'
          '${generated.substring(declaration.start)}'
          '\n// custom suffix retained\n';

      final parsed = TripsParser.parseTripsDocument(source);
      expect(parsed.isValid, isTrue, reason: parsed.errors.join('\n'));

      final edited = parsed.trips
          .map((trip) => Map<String, dynamic>.from(trip))
          .toList();
      edited.single['price'] = '₹4,500';
      final write = TripsParser.replaceTripsDataObject(
        source: source,
        trips: edited,
      );

      expect(write.success, isTrue, reason: write.error);
      expect(write.content, startsWith('// custom prefix retained'));
      expect(write.content, endsWith('// custom suffix retained\n'));
      expect(
        TripsParser.parseTripsData(write.content!).single['price'],
        '₹4,500',
      );
    });
  });

  group('Settings characterization', () {
    test('AppSettings JSON round-trip retains every persisted value', () {
      final settings = AppSettings(
        githubToken: 'test-token',
        repositoryOwner: 'owner',
        repositoryName: 'repo',
        branch: 'release',
        tripsDataPath: 'data/trips.js',
        whatsappNumber: '919876543210',
        upiId: 'business@icici',
        darkMode: true,
      );

      final restored = AppSettings.fromJson(settings.toJson());

      expect(restored.githubToken, settings.githubToken);
      expect(restored.repositoryOwner, settings.repositoryOwner);
      expect(restored.repositoryName, settings.repositoryName);
      expect(restored.branch, settings.branch);
      expect(restored.tripsDataPath, settings.tripsDataPath);
      expect(restored.whatsappNumber, settings.whatsappNumber);
      expect(restored.upiId, settings.upiId);
      expect(restored.darkMode, isTrue);
      expect(restored.isConfigured, isTrue);
    });

    test(
      'invalid UPI and WhatsApp values fail before any HTTP request',
      () async {
        var requestCount = 0;
        final dio = Dio(BaseOptions(baseUrl: 'https://api.github.test'))
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                requestCount += 1;
                handler.reject(
                  DioException(
                    requestOptions: options,
                    error:
                        'A deterministic validation test must not send HTTP.',
                  ),
                );
              },
            ),
          );
        final service = WebsiteSettingsService(
          settings: AppSettings(githubToken: 'test-token'),
          dio: dio,
        );

        final upi = await service.updateUpiId('not a UPI');
        final whatsApp = await service.updateWhatsAppNumber('+91 123');

        expect(upi.success, isFalse);
        expect(upi.error, contains('Invalid UPI'));
        expect(whatsApp.success, isFalse);
        expect(whatsApp.error, contains('Invalid WhatsApp'));
        expect(requestCount, 0);
      },
    );
  });
}

Map<String, dynamic> _trip({
  required String id,
  required String title,
  bool featured = false,
}) => <String, dynamic>{
  'id': id,
  'title': title,
  'name': title,
  'location': 'Western Ghats, Karnataka',
  'destination': 'Western Ghats, Karnataka',
  'badge': 'Weekend Trek',
  'featured': featured,
  'price': '₹4,000',
  'image': 'images/trips/$id.jpg',
  'distance': '15-20 km',
  'elevation': '1,420 m',
  'difficulty': 'Moderate',
  'bestTime': 'Oct - Feb',
  'duration': '2D/1N',
  'availableDates': <String>['Jan 18-19, 2026', 'Feb 15-16, 2026'],
  'about': 'A deterministic trek fixture.',
  'description': 'A deterministic trek fixture.',
  'highlights': <String>['Waterfalls', 'Camping'],
  'itinerary': <Map<String, dynamic>>[
    <String, dynamic>{
      'day': 'Day 0',
      'title': 'Night Departure',
      'activities': <String>['10 PM - Pickup'],
    },
    <String, dynamic>{
      'day': 'Day 1',
      'title': 'Trek',
      'activities': <String>['6 AM - Breakfast'],
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
  'galleryImages': <String>['images/gallery/$id/one.jpg'],
  'groupSize': '15-20',
  'isActive': true,
};
