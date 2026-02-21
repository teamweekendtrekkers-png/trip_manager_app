import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trips_provider.dart';
import '../providers/settings_provider.dart';
import 'trip_edit_screen.dart';
import 'settings_screen.dart';
import 'data_health_screen.dart';

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
    await tripsProvider.loadTrips();
    
    debugPrint('Trips loaded: ${tripsProvider.tripCount}');
    if (tripsProvider.error != null) {
      debugPrint('Error: ${tripsProvider.error}');
    }
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        style: TextStyle(fontSize: 12, color: Colors.orange[800]),
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
            icon: Icon(_showFeaturedOnly ? Icons.star : Icons.star_border),
            onPressed: () {
              setState(() {
                _showFeaturedOnly = !_showFeaturedOnly;
              });
            },
            tooltip: 'Show featured only',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTrips,
            tooltip: 'Refresh (Pull)',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ).then((_) => _loadTrips());
            },
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
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                            Text(
                              'Remote changes detected. Choose an action:',
                              style: TextStyle(fontSize: 12, color: Colors.red[800]),
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
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
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
              final duplicates = provider.trips.where((t) => t['_duplicateWarning'] == true).toList();
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
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                            ),
                            Text(
                              'IDs: $ids — website only uses the last occurrence.',
                              style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.health_and_safety, color: Colors.orange),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const DataHealthScreen()));
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
                          onPressed: _loadTrips,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                var trips = _searchQuery.isEmpty
                    ? provider.trips
                    : provider.searchTrips(_searchQuery);

                if (_showFeaturedOnly) {
                  trips = trips.where((t) => t['featured'] == true).toList();
                }

                if (trips.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.hiking,
                          size: 64,
                          color: Colors.grey[400],
                        ),
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
                          onPressed: _loadTrips,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadTrips,
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: trips.length,
                    onReorder: (oldIndex, newIndex) {
                      provider.reorderTrips(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final trip = trips[index];
                      return _TripCard(
                        key: ValueKey(trip['id'] ?? index),
                        trip: trip,
                        index: index,
                        onTap: () => _editTrip(trip, index),
                        onDelete: () => _deleteTrip(index),
                        onToggleFeatured: () {
                          provider.toggleFeatured(index);
                        },
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
                  onPressed: provider.isLoading ? null : () => _saveTrips(provider),
                  backgroundColor: provider.hasUnsavedChanges ? Colors.orange : Colors.green,
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
                          provider.hasUnsavedChanges ? Icons.cloud_upload : Icons.cloud_done,
                          color: Colors.white,
                        ),
                ),
              );
            },
          ),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: _addNewTrip,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  void _addNewTrip() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TripEditScreen(),
      ),
    );
  }

  void _editTrip(Map<String, dynamic> trip, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripEditScreen(trip: trip, index: index),
      ),
    );
  }

  void _deleteTrip(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content: const Text('Are you sure you want to delete this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<TripsProvider>().deleteTrip(index);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Trip deleted. Push to save changes.'),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(child: Text('Changes pushed successfully!')),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
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
              title: 'Force Push',
              subtitle: 'Overwrite remote with your changes',
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
              _loadTrips(); // Discard local and reload
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
            child: const Text('Force'),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
    // Confirm force overwrite
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Force Push'),
        content: const Text(
          'This will overwrite remote changes with your local version. '
          'Any changes made by others will be lost.\n\n'
          'Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Force Push'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await provider.forceSaveTrips(
      commitMessage: 'Force update trips via mobile app (overwrite)',
    );

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Force push successful!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Force push failed: ${result.error}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleFeatured;

  const _TripCard({
    super.key,
    required this.trip,
    required this.index,
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
    final date = trip['date'] ?? (trip['availableDates'] as List?)?.firstOrNull ?? '';
    
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
                  child: trip['image'] != null && trip['image'].toString().isNotEmpty
                      ? Image.network(
                          _getImageUrl(trip['image']),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[600],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'INACTIVE',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
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
                        Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
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
                        if (date.toString().isNotEmpty)
                          Text(
                            date.toString(),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    if (trip['badge'] != null && trip['badge'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.blue[100] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            trip['badge'].toString(),
                            style: TextStyle(
                              fontSize: 11,
                              color: isActive ? Colors.blue[800] : Colors.grey[600],
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
                        Text(isFeatured ? 'Remove Featured' : 'Mark Featured'),
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

  String _getImageUrl(String image) {
    if (image.startsWith('http')) {
      return image;
    }
    return 'https://raw.githubusercontent.com/teamweekendtrekkers-png/teamweekendtrekkerwebsite/main/$image';
  }
}
