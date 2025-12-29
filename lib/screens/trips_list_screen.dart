import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trips_provider.dart';
import '../providers/settings_provider.dart';
import 'trip_edit_screen.dart';
import 'settings_screen.dart';

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
            tooltip: 'Refresh',
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
                    child: CircularProgressIndicator(),
                  );
                }

                if (provider.error != null) {
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
                          'Add a new trip to get started',
                          style: TextStyle(color: Colors.grey[600]),
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
                  onPressed: () => _saveTrips(provider),
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.cloud_upload, color: Colors.white),
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
                  content: Text('Trip deleted. Save to publish changes.'),
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
    final commitMessage = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(
          text: 'Update trips via mobile app',
        );
        return AlertDialog(
          title: const Text('Save Changes'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Commit message',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (commitMessage == null) return;

    final success = await provider.saveTrips(commitMessage: commitMessage);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
              ? 'Changes saved successfully!' 
              : 'Failed to save: ${provider.error}',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
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
    final price = trip['price']?.toString() ?? '0';
    final discountedPrice = trip['discountedPrice'];
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            Icons.image,
                            size: 40,
                            color: Colors.grey[400],
                          ),
                        )
                      : Icon(
                          Icons.image,
                          size: 40,
                          color: Colors.grey[400],
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
                            trip['name'] ?? 'Untitled Trip',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                    Text(
                      trip['destination'] ?? '',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (discountedPrice != null) ...[
                          Text(
                            '₹$discountedPrice',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '₹$price',
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ] else
                          Text(
                            '₹$price',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        const Spacer(),
                        Text(
                          trip['date'] ?? '',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
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
    );
  }

  String _getImageUrl(String image) {
    if (image.startsWith('http')) {
      return image;
    }
    // Assume it's a relative path and construct the full URL
    return 'https://raw.githubusercontent.com/teamweekendtrekkers-png/teamweekendtrekkerwebsite/main/$image';
  }
}
