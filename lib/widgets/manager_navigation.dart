import 'app_version_card.dart';
import 'package:flutter/material.dart';

const double managerDesktopBreakpoint = 1100;

enum ManagerDestination {
  dashboard,
  library,
  history,
  trips,
  homepage,
  batches,
  payments,
  bookingReview,
  analytics,
  departureManagement,
  sharedContent,
  health,
  deployment,
  settings,
}

extension ManagerDestinationDetails on ManagerDestination {
  String get label => switch (this) {
    ManagerDestination.dashboard => 'Dashboard',
    ManagerDestination.library => 'Photo library',
    ManagerDestination.history => 'Version history',
    ManagerDestination.trips => 'Trips',
    ManagerDestination.homepage => 'Website content',
    ManagerDestination.batches => 'Departures',
    ManagerDestination.payments => 'Payments & coupons',
    ManagerDestination.bookingReview => 'Booking review',
    ManagerDestination.analytics => 'Customer journey',
    ManagerDestination.departureManagement => 'Manage departures',
    ManagerDestination.sharedContent => 'Shared trip content',
    ManagerDestination.health => 'Data health',
    ManagerDestination.deployment => 'Publishing status',
    ManagerDestination.settings => 'Settings',
  };

  String get description => switch (this) {
    ManagerDestination.dashboard => 'Daily tasks and missing dates',
    ManagerDestination.library => 'Reuse photos and manage tags',
    ManagerDestination.history => 'Restore earlier versions as drafts',
    ManagerDestination.trips => 'Manage every trip',
    ManagerDestination.homepage => 'Edit website content',
    ManagerDestination.batches => 'Preview departures',
    ManagerDestination.payments => 'UPI and discount codes',
    ManagerDestination.bookingReview => 'Review customer payment submissions',
    ManagerDestination.analytics => 'See booking steps and drop-offs',
    ManagerDestination.departureManagement => 'Close, reopen and duplicate dates',
    ManagerDestination.sharedContent => 'FAQs, policies and trip highlights',
    ManagerDestination.health => 'Check website data',
    ManagerDestination.deployment => 'Monitor publishing',
    ManagerDestination.settings => 'Repository and contact',
  };

  IconData get icon => switch (this) {
    ManagerDestination.dashboard => Icons.dashboard_outlined,
    ManagerDestination.library => Icons.photo_library_outlined,
    ManagerDestination.history => Icons.history,
    ManagerDestination.trips => Icons.route_outlined,
    ManagerDestination.homepage => Icons.web_outlined,
    ManagerDestination.batches => Icons.calendar_month_outlined,
    ManagerDestination.payments => Icons.payments_outlined,
    ManagerDestination.bookingReview => Icons.fact_check_outlined,
    ManagerDestination.analytics => Icons.insights_outlined,
    ManagerDestination.departureManagement => Icons.event_available_outlined,
    ManagerDestination.sharedContent => Icons.article_outlined,
    ManagerDestination.health => Icons.health_and_safety_outlined,
    ManagerDestination.deployment => Icons.rocket_launch_outlined,
    ManagerDestination.settings => Icons.settings_outlined,
  };

  IconData get selectedIcon => switch (this) {
    ManagerDestination.dashboard => Icons.dashboard,
    ManagerDestination.library => Icons.photo_library,
    ManagerDestination.history => Icons.history,
    ManagerDestination.trips => Icons.route,
    ManagerDestination.homepage => Icons.web,
    ManagerDestination.batches => Icons.calendar_month,
    ManagerDestination.payments => Icons.payments,
    ManagerDestination.bookingReview => Icons.fact_check,
    ManagerDestination.analytics => Icons.insights,
    ManagerDestination.departureManagement => Icons.event_available,
    ManagerDestination.sharedContent => Icons.article,
    ManagerDestination.health => Icons.health_and_safety,
    ManagerDestination.deployment => Icons.rocket_launch,
    ManagerDestination.settings => Icons.settings,
  };
}

/// One shared order keeps phone and desktop navigation consistent.
const managerNavigationGroups = <String, List<ManagerDestination>>{
  'Daily work': [
    ManagerDestination.dashboard,
    ManagerDestination.trips,
    ManagerDestination.bookingReview,
    ManagerDestination.departureManagement,
    ManagerDestination.batches,
  ],
  'Website content': [
    ManagerDestination.homepage,
    ManagerDestination.library,
    ManagerDestination.sharedContent,
    ManagerDestination.payments,
  ],
  'Insights & management': [
    ManagerDestination.analytics,
    ManagerDestination.health,
    ManagerDestination.deployment,
    ManagerDestination.history,
    ManagerDestination.settings,
  ],
};

final managerNavigationOrder = List<ManagerDestination>.unmodifiable(
  managerNavigationGroups.values.expand((destinations) => destinations),
);

class _NavigationGroupHeading extends StatelessWidget {
  const _NavigationGroupHeading(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class ManagerSideNavigation extends StatelessWidget {
  const ManagerSideNavigation({
    super.key,
    required this.onSelected,
    this.selected = ManagerDestination.trips,
  });

  final ManagerDestination selected;
  final ValueChanged<ManagerDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('manager-desktop-navigation'),
      color: scheme.surface,
      child: SafeArea(
        child: SizedBox(
          width: 250,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(Icons.terrain, color: scheme.primary),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trip Manager',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Team Weekend Trekkers',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    for (final group in managerNavigationGroups.entries) ...[
                      _NavigationGroupHeading(group.key),
                      for (final destination in group.value)
                        _SideDestination(
                          destination: destination,
                          selected: destination == selected,
                          onTap: () => onSelected(destination),
                        ),
                    ],
                  ],
                ),
              ),
              const AppVersionCard(compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

class ManagerNavigationDrawer extends StatelessWidget {
  const ManagerNavigationDrawer({
    super.key,
    required this.onSelected,
    this.selected = ManagerDestination.trips,
  });

  final ManagerDestination selected;
  final ValueChanged<ManagerDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NavigationDrawer(
      key: const Key('manager-mobile-navigation'),
      selectedIndex: managerNavigationOrder.indexOf(selected),
      onDestinationSelected: (index) {
        Navigator.pop(context);
        onSelected(managerNavigationOrder[index]);
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 20, 18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.primary,
                child: const Icon(Icons.terrain),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trip Manager',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      'Website administration',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const AppVersionCard(compact: true),
        const Divider(indent: 20, endIndent: 20),
        for (final group in managerNavigationGroups.entries) ...[
          _NavigationGroupHeading(group.key),
          for (final destination in group.value)
          NavigationDrawerDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: SizedBox(
              width: 160,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    destination.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SideDestination extends StatelessWidget {
  const _SideDestination({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final ManagerDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: ListTile(
        selected: selected,
        selectedTileColor: scheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(selected ? destination.selectedIcon : destination.icon),
        title: Text(
          destination.label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          destination.description,
          style: const TextStyle(fontSize: 11),
        ),
        onTap: onTap,
      ),
    );
  }
}

