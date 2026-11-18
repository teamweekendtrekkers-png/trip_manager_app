import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/trips_provider.dart';
import '../services/carry_library.dart';
import '../services/pickup_library.dart';
import '../services/draft_store.dart';
import '../services/reusable_library_store.dart';
import '../widgets/library_manager_dialog.dart';
import '../widgets/manager_page_layout.dart';

/// A direct home for templates, separate from editing or publishing a trip.
class ReusableLibrariesScreen extends StatefulWidget {
  const ReusableLibrariesScreen({super.key, this.storeFactory});
  final ReusableLibraryStore Function(String kind)? storeFactory;
  @override
  State<ReusableLibrariesScreen> createState() =>
      _ReusableLibrariesScreenState();
}

class _ReusableLibrariesScreenState extends State<ReusableLibrariesScreen> {
  ReusableLibraryStore store(String kind) =>
      widget.storeFactory?.call(kind) ??
      ReusableLibraryStore(
        kind: kind,
        scope: DraftStore.scope(context.read<SettingsProvider>().settings),
      );

  Future<void> manage(
    ReusableLibraryStore library,
    List<LibraryRecord> base,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => LibraryManagerDialog(store: library, base: base),
    );
    if (saved == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripsProvider>();
    final pickups = buildPickupLibrary(provider.trips);
    final packing = buildCarryLibrary(provider.trips);
    return Scaffold(
      appBar: AppBar(title: const Text('Reusable libraries')),
      body: ManagerPageBody(
        maxWidth: 960,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Keep useful items ready for your next trip',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add, edit, hide or restore pickup points and packing items here. Existing trips stay unchanged. Changes are saved on this device for the selected repository.',
            ),
            const SizedBox(height: 16),
            if (provider.isLoading) const LinearProgressIndicator(),
            if (provider.error != null)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Trip data could not refresh. These libraries use the trips currently loaded. Refresh Trips to include the latest items.',
                  ),
                ),
              ),
            ManagerCardGrid(
              minWidth: 300,
              maxColumns: 2,
              children: [
                libraryCard(
                  'pickup',
                  'Pickup points',
                  'Locations, landmarks, pickup times and Maps links.',
                  Icons.location_on_outlined,
                  pickupRecords(pickups),
                  provider.isLoading,
                ),
                libraryCard(
                  'carry',
                  'Things to carry',
                  'Packing essentials and useful checklist items.',
                  Icons.backpack_outlined,
                  carryRecords(packing),
                  provider.isLoading,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'To use an item: open a trip, find Pickup Points or Things to Carry, then choose Reuse. Hiding an item only removes it from future suggestions.',
            ),
          ],
        ),
      ),
    );
  }

  Widget libraryCard(
    String kind,
    String title,
    String description,
    IconData icon,
    List<LibraryRecord> base,
    bool loading,
  ) {
    final library = store(kind), changes = library.load();
    final records = changes.records(base);
    final hidden = records
        .where((r) => changes.hidden.contains(libraryDataId(kind, r.data)))
        .map((r) => libraryDataId(kind, r.data))
        .toSet()
        .length;
    final available = records
        .where((r) => !changes.hidden.contains(libraryDataId(kind, r.data)))
        .map((r) => libraryDataId(kind, r.data))
        .toSet()
        .length;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: scheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(description),
            const SizedBox(height: 12),
            Text(
              '$available available · $hidden hidden',
              key: Key('library-count-$kind'),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: Key('open-library-$kind'),
                onPressed: loading ? null : () => manage(library, base),
                icon: const Icon(Icons.edit_outlined),
                label: Text('Manage $title'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
