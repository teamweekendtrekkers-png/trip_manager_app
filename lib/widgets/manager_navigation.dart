import 'app_version_card.dart';
import 'package:flutter/material.dart';

const double managerDesktopBreakpoint = 1100;

enum ManagerDestination {
  dashboard,
  library,
  reusableLibrary,
  history,
  trips,
  homepage,
  batches,
  payments,
  bookingReview,
  analytics,
  departureManagement,
  checkIn,
  sharedContent,
  health,
  deployment,
  settings,
}

extension ManagerDestinationDetails on ManagerDestination {
  String get label => switch (this) {
    ManagerDestination.dashboard => 'Dashboard',
    ManagerDestination.library => 'Photo library',
    ManagerDestination.reusableLibrary => 'Reusable libraries',
    ManagerDestination.history => 'Version history',
    ManagerDestination.trips => 'Trips',
    ManagerDestination.homepage => 'Website content',
    ManagerDestination.batches => 'Departures',
    ManagerDestination.payments => 'Payments & coupons',
    ManagerDestination.bookingReview => 'Booking review',
    ManagerDestination.analytics => 'Customer journey',
    ManagerDestination.departureManagement => 'Manage departures',
    ManagerDestination.checkIn => 'Check-in',
    ManagerDestination.sharedContent => 'Shared trip content',
    ManagerDestination.health => 'Data health',
    ManagerDestination.deployment => 'Publishing status',
    ManagerDestination.settings => 'Settings',
  };

  String get description => switch (this) {
    ManagerDestination.dashboard => 'Daily tasks and missing dates',
    ManagerDestination.library => 'Reuse photos and manage tags',
    ManagerDestination.reusableLibrary => 'Pickup points and packing lists',
    ManagerDestination.history => 'Restore earlier versions as drafts',
    ManagerDestination.trips => 'Manage every trip',
    ManagerDestination.homepage => 'Edit website content',
    ManagerDestination.batches => 'Preview departures',
    ManagerDestination.payments => 'UPI and discount codes',
    ManagerDestination.bookingReview => 'Review customer payment submissions',
    ManagerDestination.analytics => 'See booking steps and drop-offs',
    ManagerDestination.departureManagement =>
      'Close, reopen and duplicate dates',
    ManagerDestination.checkIn => 'Create lists, share links and manage captain access',
    ManagerDestination.sharedContent => 'FAQs, policies and trip highlights',
    ManagerDestination.health => 'Check website data',
    ManagerDestination.deployment => 'Monitor publishing',
    ManagerDestination.settings => 'Repository and contact',
  };

  IconData get icon => switch (this) {
    ManagerDestination.dashboard => Icons.dashboard_outlined,
    ManagerDestination.library => Icons.photo_library_outlined,
    ManagerDestination.reusableLibrary => Icons.inventory_2_outlined,
    ManagerDestination.history => Icons.history,
    ManagerDestination.trips => Icons.route_outlined,
    ManagerDestination.homepage => Icons.web_outlined,
    ManagerDestination.batches => Icons.calendar_month_outlined,
    ManagerDestination.payments => Icons.payments_outlined,
    ManagerDestination.bookingReview => Icons.fact_check_outlined,
    ManagerDestination.analytics => Icons.insights_outlined,
    ManagerDestination.departureManagement => Icons.event_available_outlined,
    ManagerDestination.checkIn => Icons.how_to_reg_outlined,
    ManagerDestination.sharedContent => Icons.article_outlined,
    ManagerDestination.health => Icons.health_and_safety_outlined,
    ManagerDestination.deployment => Icons.rocket_launch_outlined,
    ManagerDestination.settings => Icons.settings_outlined,
  };

  IconData get selectedIcon => switch (this) {
    ManagerDestination.dashboard => Icons.dashboard,
    ManagerDestination.library => Icons.photo_library,
    ManagerDestination.reusableLibrary => Icons.inventory_2,
    ManagerDestination.history => Icons.history,
    ManagerDestination.trips => Icons.route,
    ManagerDestination.homepage => Icons.web,
    ManagerDestination.batches => Icons.calendar_month,
    ManagerDestination.payments => Icons.payments,
    ManagerDestination.bookingReview => Icons.fact_check,
    ManagerDestination.analytics => Icons.insights,
    ManagerDestination.departureManagement => Icons.event_available,
    ManagerDestination.checkIn => Icons.how_to_reg,
    ManagerDestination.sharedContent => Icons.article,
    ManagerDestination.health => Icons.health_and_safety,
    ManagerDestination.deployment => Icons.rocket_launch,
    ManagerDestination.settings => Icons.settings,
  };
}

/// One shared order keeps phone and desktop navigation consistent.
const managerNavigationGroups = <String, List<ManagerDestination>>{
  'Trips & departures': [
    ManagerDestination.dashboard,
    ManagerDestination.trips,
    ManagerDestination.departureManagement,
    ManagerDestination.checkIn,
    ManagerDestination.batches,
  ],
  'Bookings & payments': [
    ManagerDestination.bookingReview,
    ManagerDestination.payments,
    ManagerDestination.analytics,
  ],
  'Website editing': [ManagerDestination.homepage],
  'Media & reusable content': [
    ManagerDestination.library,
    ManagerDestination.reusableLibrary,
    ManagerDestination.sharedContent,
  ],
  'Publishing & app settings': [
    ManagerDestination.deployment,
    ManagerDestination.history,
    ManagerDestination.health,
    ManagerDestination.settings,
  ],
};

const managerNavigationDescriptions = <String, String>{
  'Trips & departures': 'Trip details, prices and departure dates',
  'Bookings & payments': 'Payment review, UPI, coupons and customer journey',
  'Website editing': 'Homepage, trip order, calendar, colours and reviews',
  'Media & reusable content': 'Photos, pickup points, packing and policies',
  'Publishing & app settings': 'Deployment, version history and preferences',
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

typedef ManagerGuideSelection =
    void Function(ManagerDestination destination, {String? section});

class ManagerSideNavigation extends StatelessWidget {
  const ManagerSideNavigation({
    super.key,
    required this.onSelected,
    this.onGuideSelected,
    this.selected = ManagerDestination.trips,
  });

  final ManagerDestination selected;
  final ValueChanged<ManagerDestination> onSelected;
  final ManagerGuideSelection? onGuideSelected;

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
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ManagerToolFinder(onSelected: onSelected),
                    ManagerGuideButton(
                      onSelected:
                          onGuideSelected ??
                          (destination, {section}) => onSelected(destination),
                    ),
                  ],
                ),
              ),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: ManagerToolFinder(
            onSelected: (destination) {
              Navigator.pop(context);
              onSelected(destination);
            },
          ),
        ),
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

List<ManagerDestination> findManagerTools(String query) {
  final terms = query
      .toLowerCase()
      .trim()
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty);
  const aliases = <ManagerDestination, String>{
    ManagerDestination.dashboard: 'home daily tasks overview',
    ManagerDestination.trips: 'edit create add price dates itinerary trip',
    ManagerDestination.library: 'images pictures cover upload tags edit photos',
    ManagerDestination.reusableLibrary:
        'pickup boarding packing carry things templates hide restore edit library',
    ManagerDestination.homepage:
        'design appearance animation colours colors logo hero reviews website edit',
    ManagerDestination.batches: 'calendar upcoming dates preview',
    ManagerDestination.departureManagement:
        'availability sold out close reopen duplicate dates calendar',
    ManagerDestination.checkIn: 'pickup captain passenger manifest weekly shared link check-in',
    ManagerDestination.payments: 'upi qr discount coupon promo payment money',
    ManagerDestination.bookingReview:
        'customers travellers travelers booking confirm verify payment pending',
    ManagerDestination.sharedContent:
        'cancellation refund policy faq guidelines highlights',
    ManagerDestination.deployment: 'publish deploy build live progress status',
    ManagerDestination.history: 'undo restore previous version changes',
    ManagerDestination.health: 'errors missing issues check validation',
    ManagerDestination.settings:
        'connect github account token repository contact setup',
    ManagerDestination.analytics: 'reports insights conversion visits drop off',
  };
  return managerNavigationOrder.where((destination) {
    final text =
        (destination.label +
                ' ' +
                destination.description +
                ' ' +
                (aliases[destination] ?? ''))
            .toLowerCase();
    return terms.every(text.contains);
  }).toList();
}

class ManagerToolFinder extends StatelessWidget {
  const ManagerToolFinder({super.key, required this.onSelected});
  final ValueChanged<ManagerDestination> onSelected;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const Key('find-manager-tool'),
    icon: const Icon(Icons.search),
    label: const Text('Find a tool'),
    onPressed: () async {
      final destination = await showDialog<ManagerDestination>(
        context: context,
        builder: (_) => const _ToolFinderDialog(),
      );
      if (context.mounted && destination != null) onSelected(destination);
    },
  );
}

class _ToolFinderDialog extends StatefulWidget {
  const _ToolFinderDialog();
  @override
  State<_ToolFinderDialog> createState() => _ToolFinderDialogState();
}

class _ToolFinderDialogState extends State<_ToolFinderDialog> {
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = findManagerTools(search.text);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 520,
        height: (150 + results.length * 76).clamp(250, 500).toDouble(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'What would you like to do?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close tool finder',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                key: const Key('manager-tool-search'),
                controller: search,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Search tools',
                  hintText: 'Try photos, coupons or publishing',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear tool search',
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(search.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  final matches = findManagerTools(search.text);
                  if (matches.isNotEmpty) Navigator.pop(context, matches.first);
                },
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No matching tools. Try a task like dates, photos or payments.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final destination = results[index];
                        return ListTile(
                          leading: Icon(destination.icon),
                          title: Text(destination.label),
                          subtitle: Text(destination.description),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(context, destination),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ManagerGuideButton extends StatelessWidget {
  const ManagerGuideButton({super.key, required this.onSelected});

  final ManagerGuideSelection onSelected;

  static const _tasks =
      <String, List<(String, String, ManagerDestination, String?)>>{
        'Trips & departures': [
          (
            'Create a trip',
            'Trips → Add trip',
            ManagerDestination.trips,
            'create',
          ),
          (
            'Edit dates or prices',
            'Trips → Choose a trip → Dates & price',
            ManagerDestination.trips,
            'dates',
          ),
          (
            'Edit photos or video',
            'Trips → Edit trip → Photos & video',
            ManagerDestination.trips,
            'photos',
          ),
          (
            'Edit pickup points',
            'Trips → Edit trip → Pickup points',
            ManagerDestination.trips,
            'pickup',
          ),
          (
            'Edit packing or inclusions',
            'Trips → Edit trip → Packing & inclusions',
            ManagerDestination.trips,
            'guidance',
          ),
          (
            'Create or review a pickup list',
            'Check-in → Choose a task or pickup list',
            ManagerDestination.checkIn,
            null,
          ),
          (
            'Close or reopen a departure',
            'Manage departures → Choose a trip and date',
            ManagerDestination.departureManagement,
            null,
          ),
        ],
        'Website editing': [
          (
            'Edit Instagram highlights',
            'Website content → Hero → Story highlights',
            ManagerDestination.homepage,
            'Story highlights',
          ),
          (
            'Reorder website or calendar trips',
            'Website content → Destinations → Trip order',
            ManagerDestination.homepage,
            'Trip order',
          ),
          (
            'Show or hide trip-type filters',
            'Website content → Destinations → Trip discovery',
            ManagerDestination.homepage,
            'Trip discovery',
          ),
          (
            'Edit calendar holidays',
            'Website content → Upcoming Batches → Calendar holidays',
            ManagerDestination.homepage,
            'Calendar',
          ),
          (
            'Change departure date colours',
            'Website content → Appearance → Date colours',
            ManagerDestination.homepage,
            'Date colours',
          ),
          (
            'Edit reviews',
            'Website content → Reviews',
            ManagerDestination.homepage,
            'Reviews',
          ),
          (
            'Edit footer',
            'Website content → Footer',
            ManagerDestination.homepage,
            'Footer',
          ),
          (
            'Edit pages',
            'Website content → Pages',
            ManagerDestination.homepage,
            'Pages',
          ),
          (
            'Change trip card colours',
            'Website content → Appearance → Card colours',
            ManagerDestination.homepage,
            'Card colours',
          ),
          (
            'Change mobile tab colours',
            'Website content → Appearance → Mobile tab colours',
            ManagerDestination.homepage,
            'Mobile tab colours',
          ),
        ],
        'Bookings & reusable content': [
          (
            'Review payments',
            'Bookings → Choose a submission',
            ManagerDestination.bookingReview,
            null,
          ),
          (
            'Set up UPI or coupons',
            'Payments & coupons',
            ManagerDestination.payments,
            null,
          ),
          (
            'See booking drop-offs',
            'Customer journey → Sign in to analytics',
            ManagerDestination.analytics,
            null,
          ),
          (
            'Reuse pickup points or packing lists',
            'Reusable libraries → Choose a library',
            ManagerDestination.reusableLibrary,
            null,
          ),
          (
            'Edit shared FAQs and policies',
            'Shared trip content',
            ManagerDestination.sharedContent,
            null,
          ),
        ],
        'Publishing & settings': [
          (
            'Check whether a change is live',
            'Publishing status → Recent builds',
            ManagerDestination.deployment,
            null,
          ),
          (
            'Restore an earlier version',
            'Version history → Restore as draft',
            ManagerDestination.history,
            null,
          ),
          (
            'Edit repository or contact settings',
            'Settings',
            ManagerDestination.settings,
            null,
          ),
        ],
      };

  Future<void> _openGuide(BuildContext context) async {
    final destination =
        await showDialog<({ManagerDestination workspace, String? section})>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Manager guide'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final group in _tasks.entries)
                      ExpansionTile(
                        title: Text(group.key),
                        children: [
                          for (final (title, path, target, section)
                              in group.value)
                            ListTile(
                              title: Text(title),
                              subtitle: Text(path),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.pop(dialogContext, (
                                workspace: target,
                                section: section,
                              )),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          ),
        );
    if (destination != null && context.mounted) {
      onSelected(destination.workspace, section: destination.section);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () => _openGuide(context),
    icon: const Icon(Icons.help_outline),
    label: const Text('Guide'),
  );
}
