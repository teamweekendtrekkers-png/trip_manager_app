import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/services/trip_workspace_filter.dart';

void main() {
  final now = DateTime.utc(2026, 11, 12);
  Map<String, dynamic> trip(
    String title, {
    List<String> dates = const [],
    bool active = true,
  }) => {'title': title, 'availableDates': dates, 'isActive': active};
  test(
    'photo filter catches missing and legacy covers without excluding drafts',
    () {
      for (final image in [null, '', '  ', '/images/trips/default.jpg']) {
        expect(
          matchesTripWorkspaceFilter(
            {'image': image},
            'Needs photo',
            hasDraft: false,
          ),
          isTrue,
        );
      }
      expect(
        matchesTripWorkspaceFilter(
          {'image': 'images/real.jpg'},
          'Needs photo',
          hasDraft: true,
        ),
        isFalse,
      );
      expect(matchesTripWorkspaceFilter({}, 'Draft', hasDraft: true), isTrue);
    },
  );
  test(
    'departure sorting puts bookable trips first and preserves ties and source order',
    () {
      final late = trip('Late', dates: ['Dec 20-22, 2026']);
      final early = trip('Early', dates: ['Dec 01-03, 2026']);
      final closed = trip('Closed', dates: ['Nov 01-02, 2026']);
      final hidden = trip(
        'Hidden',
        dates: ['Nov 20-22, 2026'],
        active: false,
      );
      final source = [late, closed, early, hidden];
      final sorted = sortTripWorkspace(
        source,
        TripWorkspaceSort.departure,
        referenceDate: now,
      );
      expect(sorted, [early, late, closed, hidden]);
      expect(source, [late, closed, early, hidden]);
      expect(
        matchesTripWorkspaceFilter(
          early,
          'Upcoming',
          hasDraft: false,
          referenceDate: now,
        ),
        isTrue,
      );
      expect(
        matchesTripWorkspaceFilter(
          hidden,
          'Needs dates',
          hasDraft: false,
          referenceDate: now,
        ),
        isFalse,
      );
    },
  );
  test('name sort ignores case and retains website order for equal names', () {
    final source = [trip('zebra'), trip('ALPHA'), trip('alpha')];
    expect(sortTripWorkspace(source, TripWorkspaceSort.name), [
      source[1],
      source[2],
      source[0],
    ]);
  });
}

