import 'package:flutter/material.dart';

const double managerDesktopBreakpoint = 1100;

enum ManagerDestination {
  trips,
  homepage,
  batches,
  payments,
  sharedContent,
  health,
  deployment,
  settings,
}

extension ManagerDestinationDetails on ManagerDestination {
  String get label => switch (this) {
    ManagerDestination.trips => 'Trips',
    ManagerDestination.homepage => 'Website content',
    ManagerDestination.batches => 'Departures',
    ManagerDestination.payments => 'Payments & coupons',
    ManagerDestination.sharedContent => 'Shared trip content',
    ManagerDestination.health => 'Data health',
    ManagerDestination.deployment => 'Publishing status',
    ManagerDestination.settings => 'Settings',
  };

  String get description => switch (this) {
    ManagerDestination.trips => 'Manage every trip',
    ManagerDestination.homepage => 'Edit website content',
    ManagerDestination.batches => 'Preview departures',
    ManagerDestination.payments => 'UPI and discount codes',
    ManagerDestination.sharedContent => 'FAQs, policies and trip highlights',
    ManagerDestination.health => 'Check website data',
    ManagerDestination.deployment => 'Monitor publishing',
    ManagerDestination.settings => 'Repository and contact',
  };

  IconData get icon => switch (this) {
    ManagerDestination.trips => Icons.route_outlined,
    ManagerDestination.homepage => Icons.web_outlined,
    ManagerDestination.batches => Icons.calendar_month_outlined,
    ManagerDestination.payments => Icons.payments_outlined,
    ManagerDestination.sharedContent => Icons.article_outlined,
    ManagerDestination.health => Icons.health_and_safety_outlined,
    ManagerDestination.deployment => Icons.rocket_launch_outlined,
    ManagerDestination.settings => Icons.settings_outlined,
  };

  IconData get selectedIcon => switch (this) {
    ManagerDestination.trips => Icons.route,
    ManagerDestination.homepage => Icons.web,
    ManagerDestination.batches => Icons.calendar_month,
    ManagerDestination.payments => Icons.payments,
    ManagerDestination.sharedContent => Icons.article,
    ManagerDestination.health => Icons.health_and_safety,
    ManagerDestination.deployment => Icons.rocket_launch,
    ManagerDestination.settings => Icons.settings,
  };
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
              Expanded(child: ListView(children:[for (final destination in ManagerDestination.values)
                _SideDestination(
                  destination: destination,
                  selected: destination == selected,
                  onTap: () => onSelected(destination),
                ),
              ])),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.cloud_done_outlined, color: scheme.primary),
                      const SizedBox(height: 8),
                      const Text(
                        'GitHub connected workspace',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Review changes before publishing.',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
      selectedIndex: ManagerDestination.values.indexOf(selected),
      onDestinationSelected: (index) {
        Navigator.pop(context);
        onSelected(ManagerDestination.values[index]);
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
        const Divider(indent: 20, endIndent: 20),
        for (final destination in ManagerDestination.values)
          NavigationDrawerDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: SizedBox(width:160,child:Text(destination.label,maxLines:2,overflow:TextOverflow.ellipsis)),
          ),
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
