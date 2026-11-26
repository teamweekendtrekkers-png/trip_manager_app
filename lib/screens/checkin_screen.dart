import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/settings_provider.dart';
import '../providers/trips_provider.dart';
import '../services/carry_library.dart';
import '../services/draft_store.dart';
import '../services/pickup_library.dart';
import '../services/pickup_service.dart';
import '../services/reusable_library_store.dart';
import '../widgets/carry_library_dialog.dart';
import '../widgets/pickup_library_dialog.dart';
import 'pickup_manifest_screen.dart';

Future<void> openPickupOrganizer(
  BuildContext context,
  Map<String, String> parameters, {
  String? librarySelection,
}) async {
  final url = Uri.https(
    'www.teamweekendtrekkers.com',
    '/pickup/captain.html',
    parameters,
  ).replace(fragment: librarySelection);
  try {
    if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // Show the same message if the operating system cannot open a browser.
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the check-in organizer.')),
    );
  }
}

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  late Future<List<PickupDeparture>> _lists = _loadLists();

  Future<List<PickupDeparture>> _loadLists() async =>
      (await PickupService.organizer.departures())
          .where((trip) => trip.open)
          .toList();

  void _review([String? slug]) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => PickupManifestScreen(initialDeparture: slug),
    ),
  );

  Future<void> _reuseLibraries(BuildContext context) async {
    final trips = context.read<TripsProvider>().trips;
    final scope = DraftStore.scope(context.read<SettingsProvider>().settings);
    final stops = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (_) => PickupLibraryDialog(
        entries: buildPickupLibrary(trips),
        current: const [],
        store: ReusableLibraryStore(kind: 'pickup', scope: scope),
      ),
    );
    if (!context.mounted) return;
    final packing = await showDialog<List<String>>(
      context: context,
      builder: (_) => CarryLibraryDialog(
        entries: buildCarryLibrary(trips),
        current: const [],
        store: ReusableLibraryStore(kind: 'carry', scope: scope),
      ),
    );
    if (!context.mounted || (stops == null && packing == null)) return;
    final data = jsonEncode({'stops': stops ?? [], 'packing': packing ?? []});
    if (data.length > 12000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select fewer library items and try again.'),
        ),
      );
      return;
    }
    await openPickupOrganizer(context, {
      'create': '1',
    }, librarySelection: Uri(queryParameters: {'library': data}).query);
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<TripsProvider>().isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Check-in')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FilledButton.icon(
                onPressed: () => openPickupOrganizer(context, {'create': '1'}),
                icon: const Icon(Icons.add),
                label: const Text('Create check-in list'),
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add_outlined),
                title: const Text('Create from reusable libraries'),
                subtitle: const Text(
                  'Choose pickup points and things to carry',
                ),
                onTap: loading ? null : () => _reuseLibraries(context),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Review current and previous lists'),
                subtitle: const Text(
                  'See each departure’s stops and traveller totals',
                ),
                onTap: _review,
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Share a check-in link'),
                subtitle: const Text(
                  'Copy one link for everyone on a departure',
                ),
                onTap: _review,
              ),
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: const Text('Generate captain access'),
                subtitle: const Text(
                  'Create a username and password for one list',
                ),
                onTap: () => openPickupOrganizer(context, {'view': 'access'}),
              ),
              const Divider(),
              ListTile(
                title: const Text('Published pickup lists'),
                trailing: IconButton(
                  onPressed: () => setState(() => _lists = _loadLists()),
                  tooltip: 'Refresh published lists',
                  icon: const Icon(Icons.refresh),
                ),
              ),
              FutureBuilder(
                future: _lists,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return const Text(
                      'The lists are unavailable. Try Refresh or open the organizer.',
                    );
                  }
                  final rows = snapshot.data ?? [];
                  if (rows.isEmpty) {
                    return const Text(
                      'No pickup lists have been published yet.',
                    );
                  }
                  return Column(
                    children: [
                      for (final row in rows)
                        ListTile(
                          title: Text(row.title),
                          subtitle: Text(row.date),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _review(row.slug),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
