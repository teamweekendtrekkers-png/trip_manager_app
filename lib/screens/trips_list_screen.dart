import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trips_provider.dart';
import '../providers/settings_provider.dart';
import '../services/trip_date_utils.dart';
import 'trip_edit_screen.dart';
import 'settings_screen.dart';
import 'data_health_screen.dart';
import 'deployment_status_screen.dart';
import 'upcoming_batches_screen.dart';

class TripsListScreen extends StatefulWidget {
  const TripsListScreen({super.key});

  @override
  State<TripsListScreen> createState() => _TripsListScreenState();
}

class _TripsListScreenState extends State<TripsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showFeaturedOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTrips();
    });
  }

  Future<void> _loadTrips() async {
    final settingsProvider = context.read<SettingsProvider>();
    if (!settingsProvider.isConfigured) {
      _showSetupDialog();
      return;
    }

    final tripsProvider = context.read<TripsProvider>();
    tripsProvider.updateSettings(settingsProvider.settings);
    final refreshed = await tripsProvider.refreshTrips();

    debugPrint('Trips loaded: ${tripsProvider.tripCount}');
    if (tripsProvider.error != null) {
      debugPrint('Error: ${tripsProvider.error}');
    }
    if (!refreshed && tripsProvider.hasConflict && mounted) {
      _showConflictDialog(
        tripsProvider,
        tripsProvider.error ?? 'Remote changes conflict with local edits.',
      );
    }
  }

  Future<void> _confirmAndRefresh() async {
    final provider = context.read<TripsProvider>();
    if (provider.isLoading) return;
    if (provider.hasUnsavedChanges && !provider.hasCompleteRemoteSnapshot) {
      await _confirmDiscardAndReload(
        provider,
        explanation:
            'The repository target changed, so these local edits cannot be '
            'safely merged into it. Reloading will replace them with the '
            'currently selected repository.',
      );
      return;
    }
    if (provider.hasUnsavedChanges) {
      final shouldMerge = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Refresh and Merge?'),
          content: const Text(
            'You have unsaved changes. Refresh will merge remote updates into '
            'your current work and list any true conflicts; it will not discard '
            'your edits.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Refresh & Merge'),
            ),
          ],
        ),
      );
      if (shouldMerge != true || !mounted) return;
    }
    await _loadTrips();
  }

  Future<void> _confirmDiscardAndReload(
    TripsProvider provider, {
    String explanation =
        'Reloading will permanently replace every unsaved local trip change '
        'with the current remote version.',
  }) async {
    if (provider.isLoading || !mounted) return;
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Local Changes?'),
        content: Text(explanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Local Changes'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (firstConfirm != true || !mounted) return;

    final finalConfirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Final Discard Confirmation'),
        content: const Text(
          'This cannot be undone in the app. Discard all local changes and '
          'reload from GitHub now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Go Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Discard & Reload'),
          ),
        ],
      ),
    );
    if (finalConfirm != true || !mounted) return;

    final reloaded = await provider.reloadDiscardingLocalChanges();
    if (!mounted || reloaded) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(provider.error ?? 'Reload failed.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSetupDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Setup Required'),
        content: const Text(
          'Please configure your GitHub token to access the repository.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            child: const Text('Go to Settings'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Manager'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Unsaved changes indicator
          Consumer<TripsProvider>(
            builder: (context, provider, _) {
              if (provider.hasUnsavedChanges) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 14, color: Colors.orange[800]),
                      const SizedBox(width: 4),
                      Text(
                        'Unsaved',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[800],
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.health_and_safety),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DataHealthScreen()),
              );
            },
            tooltip: 'Data Health Check',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () {
              final trips = context.read<TripsProvider>().trips;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UpcomingBatchesScreen(trips: trips),
                ),
              );
            },
            tooltip: 'Preview Upcoming Batches',
          ),
          IconButton(
            icon: Icon(_showFeaturedOnly ? Icons.star : Icons.star_border),
            onPressed: () {
              setState(() {
                _showFeaturedOnly = !_showFeaturedOnly;
              });
            },
            tooltip: 'Show featured only',
          ),
          Consumer<TripsProvider>(
            builder: (context, provider, _) => IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: provider.isLoading ? null : _confirmAndRefresh,
              tooltip: 'Refresh (Pull)',
            ),
          ),
          Consumer<TripsProvider>(
            builder: (context, provider, _) => IconButton(
              icon: const Icon(Icons.settings),
              onPressed: provider.isLoading
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ).then((_) => _confirmAndRefresh());
                    },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Conflict banner
          Consumer<TripsProvider>(
            builder: (context, provider, _) {
              if (provider.hasConflict) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.red[100],
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Conflict Detected',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            Text(
                              'Remote changes detected. Choose an action:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _handlePullAndMerge(provider),
                        child: const Text('Merge'),
                      ),
                      TextButton(
                        onPressed: () => _handleForceOverwrite(provider),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Overwrite'),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Duplicate trip ID warning banner
          Consumer<TripsProvider>(
            builder: (context, provider, _) {
              final duplicates = provider.trips
                  .where((t) => t['_duplicateWarning'] == true)
                  .toList();
              if (duplicates.isNotEmpty) {
                final ids = duplicates.map((t) => t['id']).toSet().join(', ');
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.orange[100],
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Duplicate Trip IDs Found',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            Text(
                              'IDs: $ids — website only uses the last occurrence.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.health_and_safety,
                          color: Colors.orange,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DataHealthScreen(),
                            ),
                          );
                        },
                        tooltip: 'View Data Health',
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search trips...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // Trips list
          Expanded(
            child: Consumer<TripsProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading trips from GitHub...'),
                      ],
                    ),
                  );
                }

                if (provider.error != null && !provider.hasConflict) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading trips',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            provider.error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _confirmAndRefresh,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                var trips = _searchQuery.isEmpty
                    ? provider.orderedTrips
                    : provider.searchTrips(_searchQuery);

                if (_showFeaturedOnly) {
                  trips = trips.where((t) => t['featured'] == true).toList();
                }

                if (trips.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.hiking, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No trips match your search'
                              : 'No trips found',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add a new trip',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _confirmAndRefresh,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                  );
                }

                // When a search or filter is active, trips is a filtered sublist.
                // The itemBuilder index is the position in that sublist — NOT the
                // position in provider.trips. We must resolve the real index via
                // the trip's ID so that edit/delete/toggleFeatured operate on the
                // correct trip in the full list instead of trashing trip #0.
                final isFiltered = _searchQuery.isNotEmpty || _showFeaturedOnly;

                return RefreshIndicator(
                  onRefresh: _confirmAndRefresh,
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: trips.length,
                    buildDefaultDragHandles: !isFiltered,
                    onReorder: isFiltered
                        ? (
                            _,
                            _,
                          ) {} // Reordering while filtered would corrupt order
                        : (oldIndex, newIndex) {
                            final moved = provider.reorderTrips(
                              oldIndex,
                              newIndex,
                            );
                            if (!moved) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Trips can only be reordered within the same visibility tier.',
                                  ),
                                ),
                              );
                            }
                          },
                    itemBuilder: (context, index) {
                      final trip = trips[index];
                      final tripId = trip['id']?.toString() ?? '';
                      return KeyedSubtree(
                        key: ValueKey<dynamic>(
                          tripId.trim().isEmpty
                              ? 'invalid-trip-$index'
                              : tripId,
                        ),
                        child: _TripCard(
                          trip: trip,
                          onTap: () => _editTrip(tripId),
                          onDelete: () => _deleteTrip(tripId),
                          onToggleFeatured: () => _toggleFeatured(tripId),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Consumer<TripsProvider>(
            builder: (context, provider, _) {
              if (!provider.hasTrips) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FloatingActionButton.small(
                  heroTag: 'save',
                  onPressed: provider.isLoading
                      ? null
                      : () => _saveTrips(provider),
                  backgroundColor: provider.hasUnsavedChanges
                      ? Colors.orange
                      : Colors.green,
                  child: provider.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          provider.hasUnsavedChanges
                              ? Icons.cloud_upload
                              : Icons.cloud_done,
                          color: Colors.white,
                        ),
                ),
              );
            },
          ),
          Consumer<TripsProvider>(
            builder: (context, provider, _) => FloatingActionButton(
              heroTag: 'add',
              onPressed: provider.isLoading ? null : _addNewTrip,
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  void _addNewTrip() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TripEditScreen()),
    );
  }

  void _editTrip(String tripId) {
    final provider = context.read<TripsProvider>();
    final index = provider.getTripIndexById(tripId);
    final trip = provider.getTripById(tripId);
    if (tripId.isEmpty || index == null || trip == null) {
      _showTripUnavailable();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripEditScreen(trip: trip, index: index),
      ),
    );
  }

  void _toggleFeatured(String tripId) {
    final provider = context.read<TripsProvider>();
    final index = provider.getTripIndexById(tripId);
    if (tripId.isEmpty || index == null) {
      _showTripUnavailable();
      return;
    }
    provider.toggleFeatured(index);
  }

  Future<void> _deleteTrip(String tripId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content: const Text('Are you sure you want to delete this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<TripsProvider>();
    final index = provider.getTripIndexById(tripId);
    if (tripId.isEmpty || index == null) {
      _showTripUnavailable();
      return;
    }
    provider.deleteTrip(index);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Trip deleted. Push to save changes.')),
    );
  }

  void _showTripUnavailable() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'That trip changed or no longer exists. Refresh before retrying.',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _saveTrips(TripsProvider provider) async {
    // Show save dialog with options
    final action = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(
          text: 'Update trips via mobile app',
        );
        return AlertDialog(
          title: const Text('Push Changes to GitHub'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info box explaining the process
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will check for conflicts before pushing.',
                        style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Commit message',
                  border: OutlineInputBorder(),
                  hintText: 'Describe your changes...',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, controller.text),
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Push'),
            ),
          ],
        );
      },
    );

    if (action == null) return;

    // Perform the save
    final result = await provider.saveTrips(commitMessage: action);

    if (!mounted) return;

    if (result.success) {
      _showPublicationSuccess(
        message: 'Changes pushed successfully!',
        commitSha: result.commitSha,
      );
    } else if (result.hasConflict) {
      // Show conflict resolution dialog
      _showConflictDialog(provider, result.error ?? 'Conflict detected');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Failed: ${result.error}')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showConflictDialog(TripsProvider provider, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('Conflict Detected'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            const Text(
              'Choose how to resolve:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildOption(
              icon: Icons.merge,
              title: 'Pull & Merge',
              subtitle: 'Keep your changes and add new remote trips',
              color: Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildOption(
              icon: Icons.cloud_download,
              title: 'Discard Local',
              subtitle: 'Replace with remote version (lose your changes)',
              color: Colors.orange,
            ),
            const SizedBox(height: 8),
            _buildOption(
              icon: Icons.cloud_upload,
              title: 'Overwrite',
              subtitle: 'Create a normal commit using your local trip data',
              color: Colors.red,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handlePullAndMerge(provider);
            },
            child: const Text('Merge'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDiscardAndReload(provider);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleForceOverwrite(provider);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Overwrite'),
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePullAndMerge(TripsProvider provider) async {
    final result = await provider.pullAndMerge();

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Merged! ${result.newTripsAdded} new trips added. Push to save.',
          ),
          backgroundColor: Colors.blue,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Merge failed: ${result.error}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleForceOverwrite(TripsProvider provider) async {
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Overwrite Remote Trip Data?'),
        content: const Text(
          'This fallback discards conflicting remote edits inside the managed '
          'trip object and featured array. Other website code and Git history '
          'remain intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (firstConfirm != true || !mounted) return;

    final finalConfirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Final Confirmation'),
        content: const Text(
          'Remote changes in the two managed data sections may be lost. '
          'Create the overwrite commit now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Go Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Create Overwrite Commit'),
          ),
        ],
      ),
    );

    if (finalConfirm != true) return;

    final result = await provider.forceSaveTrips(
      commitMessage: 'Overwrite managed trip data via mobile app',
    );

    if (!mounted) return;

    if (result.success) {
      _showPublicationSuccess(
        message: 'Overwrite commit created successfully!',
        commitSha: result.commitSha,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Overwrite failed: ${result.error}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPublicationSuccess({
    required String message,
    required String? commitSha,
  }) {
    final exactSha = commitSha?.trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
        action: exactSha == null || exactSha.isEmpty
            ? null
            : SnackBarAction(
                key: ValueKey<String>('view-deployment-$exactSha'),
                label: 'View Deployment',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DeploymentStatusScreen(savedCommitSha: exactSha),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleFeatured;

  const _TripCard({
    required this.trip,
    required this.onTap,
    required this.onDelete,
    required this.onToggleFeatured,
  });

  @override
  Widget build(BuildContext context) {
    final isFeatured = trip['featured'] == true;
    final isActive = trip['isActive'] != false; // Default to true if not set
    final name = trip['title'] ?? trip['name'] ?? 'Untitled Trip';
    final location = trip['location'] ?? trip['destination'] ?? '';
    final price = trip['price']?.toString() ?? '₹0';
    final upcomingDates = TripDateUtils.getUpcomingDateRanges(trip);
    final date = upcomingDates.isEmpty
        ? 'New dates coming soon'
        : upcomingDates.first.shortLabel;

    return Opacity(
      opacity: isActive ? 1.0 : 0.5,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: isActive ? null : Colors.grey[100],
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Trip image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child:
                        trip['image'] != null &&
                            trip['image'].toString().isNotEmpty
                        ? Image.network(
                            _getImageUrl(context, trip['image']),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.terrain,
                              size: 40,
                              color: Colors.green[400],
                            ),
                          )
                        : Icon(
                            Icons.terrain,
                            size: 40,
                            color: Colors.green[400],
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Trip info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isActive ? null : Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isActive)
                            Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[600],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'INACTIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (isFeatured)
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 20,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            price,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isActive ? Colors.green : Colors.grey,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            date,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (trip['badge'] != null &&
                          trip['badge'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.blue[100]
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              trip['badge'].toString(),
                              style: TextStyle(
                                fontSize: 11,
                                color: isActive
                                    ? Colors.blue[800]
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Actions
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      onDelete();
                    } else if (value == 'featured') {
                      onToggleFeatured();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'featured',
                      child: Row(
                        children: [
                          Icon(
                            isFeatured ? Icons.star_border : Icons.star,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isFeatured ? 'Remove Featured' : 'Mark Featured',
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getImageUrl(BuildContext context, String image) {
    if (image.startsWith('http')) {
      return image;
    }
    final settings = context.read<SettingsProvider>().settings;
    return 'https://raw.githubusercontent.com/${settings.repositoryOwner}/${settings.repositoryName}/${settings.branch}/$image';
  }
}
