import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/models/homepage_config.dart';
import 'package:trip_manager_app/services/trips_parser.dart';

void main() {
  final website = Directory(
    Platform.environment['WEBSITE_REPO_PATH'] ?? '../TravelBooking',
  );
  // Local app-only checkouts may omit the website. CI and explicit paths
  // must fail on missing fixtures instead of silently losing this coverage.
  final websiteRequired = Platform.environment['CI'] == 'true' ||
      Platform.environment.containsKey('WEBSITE_REPO_PATH');
  final skipWithoutWebsite = !websiteRequired && !website.existsSync();
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
      // Full equality includes new optional fields, absence, empty lists,
      // and editor aliases without maintaining another partial field list.
      expect(reloaded.trips, parsed.trips);
    },
    skip: skipWithoutWebsite,
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
    skip: skipWithoutWebsite,
  );
}
