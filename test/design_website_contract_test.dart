import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/models/homepage_config.dart';
import 'package:trip_manager_app/services/trips_parser.dart';

void main() {
  final website = Directory('../TravelBooking');
  test(
    'authoritative website records retain dates and optional card metadata',
    () {
      final source = File(
        '${website.path}/js/trips-data.js',
      ).readAsStringSync();
      final parsed = TripsParser.parseTripsDocument(source);
      expect(parsed.isValid, isTrue, reason: parsed.errors.join('\n'));
      expect(parsed.trips, isNotEmpty);
      final written = TripsParser.replaceTripsDataObject(
        source: source,
        trips: parsed.trips,
      );
      expect(written.success, isTrue);
      final reloaded = TripsParser.parseTripsDocument(written.content!);
      expect(reloaded.isValid, isTrue, reason: reloaded.errors.join('\n'));
      expect(reloaded.trips, hasLength(parsed.trips.length));
      expect(reloaded.document!.prefix, parsed.document!.prefix);
      expect(reloaded.document!.suffix, parsed.document!.suffix);
      for (var index = 0; index < parsed.trips.length; index++) {
        final before = parsed.trips[index];
        final after = reloaded.trips[index];
        expect(after['id'], before['id']);
        for (final field in [
          'availableDates',
          'price',
          'image',
          'isActive',
          'featured',
          'cardImage',
          'cardSummary',
          'departureCity',
          'experience',
        ]) {
          expect(after[field], before[field], reason: '${before['id']}.$field');
          if (!before.containsKey(field)) {
            expect(after.containsKey(field), isFalse);
          }
        }
      }
    },
    skip: !website.existsSync(),
  );

  test(
    'published homepage choices survive manager loading and encoding',
    () {
      final source = File(
        '${website.path}/js/homepage-config.json',
      ).readAsStringSync();
      final original = jsonDecode(source) as Map<String, dynamic>;
      final config = HomepageConfig.parse(source);
      expect(HomepageConfig.parse(config.encode()).toJson(), config.toJson());
      final data = config.toJson();
      expect(
        data['upcomingBatches']['tripIds'],
        original['upcomingBatches']['tripIds'],
      );
      expect(
        data['discovery'],
        original['discovery'] ?? HomepageConfig.defaults['discovery'],
      );
      expect(data['hero'], original['hero']);
    },
    skip: !website.existsSync(),
  );
}
