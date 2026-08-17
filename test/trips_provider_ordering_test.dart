import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/providers/trips_provider.dart';

Map<String, dynamic> trip(
  String id, {
  bool featured = false,
  bool active = true,
}) => {'id': id, 'title': id, 'featured': featured, 'isActive': active};

void main() {
  group('TripsProvider display ordering', () {
    test('is stable within featured-active, active, and inactive tiers', () {
      final provider = TripsProvider(AppSettings());
      for (final value in [
        trip('active-1'),
        trip('inactive-1', active: false),
        trip('featured-1', featured: true),
        trip('active-2'),
        trip('featured-2', featured: true),
        trip('inactive-2', active: false, featured: true),
      ]) {
        provider.addTrip(value);
      }

      expect(provider.orderedTrips.map((value) => value['id']), [
        'featured-1',
        'featured-2',
        'active-1',
        'active-2',
        'inactive-1',
        'inactive-2',
      ]);
      expect(provider.trips.map((value) => value['id']), [
        'active-1',
        'inactive-1',
        'featured-1',
        'active-2',
        'featured-2',
        'inactive-2',
      ]);
    });

    test(
      'featured toggle moves the card immediately without sorting storage',
      () {
        final provider = TripsProvider(AppSettings())
          ..addTrip(trip('a'))
          ..addTrip(trip('b'));

        provider.toggleFeatured(provider.getTripIndexById('b')!);

        expect(provider.orderedTrips.map((value) => value['id']), ['b', 'a']);
        expect(provider.trips.map((value) => value['id']), ['a', 'b']);
      },
    );

    test('allows within-tier reorder and rejects cross-tier reorder', () {
      final provider = TripsProvider(AppSettings())
        ..addTrip(trip('featured', featured: true))
        ..addTrip(trip('a'))
        ..addTrip(trip('b'))
        ..addTrip(trip('inactive', active: false));

      expect(provider.reorderTrips(2, 1), isTrue);
      expect(provider.orderedTrips.map((value) => value['id']), [
        'featured',
        'b',
        'a',
        'inactive',
      ]);

      expect(provider.reorderTrips(1, 0), isFalse);
      expect(provider.orderedTrips.map((value) => value['id']), [
        'featured',
        'b',
        'a',
        'inactive',
      ]);
    });

    test('search retains derived priority order', () {
      final provider = TripsProvider(AppSettings())
        ..addTrip(trip('matching-active'))
        ..addTrip(trip('matching-featured', featured: true));

      expect(provider.searchTrips('matching').map((value) => value['id']), [
        'matching-featured',
        'matching-active',
      ]);
    });

    test('active edit moves the card immediately without sorting storage', () {
      final provider = TripsProvider(AppSettings())
        ..addTrip(trip('a'))
        ..addTrip(trip('b', active: false));

      provider.updateTrip(provider.getTripIndexById('b')!, {
        ...provider.getTripById('b')!,
        'isActive': true,
        'featured': true,
      });

      expect(provider.orderedTrips.map((value) => value['id']), ['b', 'a']);
      expect(provider.trips.map((value) => value['id']), ['a', 'b']);
    });

    test('records intentional deletion', () {
      final provider = TripsProvider(AppSettings())..addTrip(trip('delete-me'));

      provider.deleteTrip(0);

      expect(provider.intentionalDeletedIds, {'delete-me'});
      expect(provider.trips, isEmpty);
    });
  });
}
