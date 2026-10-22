import 'package:flutter_test/flutter_test.dart';
import '../lib/widgets/manager_navigation.dart';

void main() {
  test('grouped navigation exposes every destination exactly once', () {
    expect(managerNavigationOrder, hasLength(ManagerDestination.values.length));
    expect(managerNavigationOrder.toSet(), ManagerDestination.values.toSet());
  });

  test('drawer indices follow the same group order as the sidebar', () {
    final visibleDestinations = [
      for (final group in managerNavigationGroups.values) ...group,
    ];
    for (final destination in ManagerDestination.values) {
      final selectedIndex = managerNavigationOrder.indexOf(destination);
      expect(selectedIndex, greaterThanOrEqualTo(0));
      expect(visibleDestinations[selectedIndex], destination);
    }
    expect(managerNavigationOrder.first, ManagerDestination.dashboard);
    expect(managerNavigationOrder[1], ManagerDestination.trips);
    expect(managerNavigationOrder[2], ManagerDestination.bookingReview);
  });
}
