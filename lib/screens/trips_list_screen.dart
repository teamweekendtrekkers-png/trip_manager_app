import 'dart:convert';
import 'package:flutter/material.dart';
import 'commerce_settings_screen.dart';
import 'trip_content_settings_screen.dart';
import '../widgets/quick_trip_editor.dart';
import '../widgets/trip_editor_sections.dart';
import '../services/quick_edit_safety.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/trips_provider.dart';
import '../providers/settings_provider.dart';
import '../services/trip_date_utils.dart';
import 'trip_edit_screen.dart';
import 'settings_screen.dart';
import 'data_health_screen.dart';
import 'deployment_status_screen.dart';
import 'upcoming_batches_screen.dart';
import 'homepage_settings_screen.dart';
import '../widgets/manager_navigation.dart';

class TripsListScreen extends StatefulWidget {
  const TripsListScreen({super.key});

  @override
  State<TripsListScreen> createState() => _TripsListScreenState();
}

class _TripsListScreenState extends State<TripsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _showFeaturedOnly = false;
  bool _publishing=false;
  String? _publishedCommitSha;
  String? _publishFailure;

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
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _openDestination(ManagerDestination destination) async {
    if (destination == ManagerDestination.trips || !mounted) return;
    final trips = context.read<TripsProvider>().trips;
    final route = switch (destination) {
      ManagerDestination.homepage => MaterialPageRoute<void>(
        builder: (_) => const HomepageSettingsScreen(),
      ),
      ManagerDestination.batches => MaterialPageRoute<void>(
        builder: (_) => UpcomingBatchesScreen(trips: trips),
      ),
      ManagerDestination.payments => MaterialPageRoute<void>(builder: (_) => const CommerceSettingsScreen()),
      ManagerDestination.sharedContent => MaterialPageRoute<void>(builder: (_) => const TripContentSettingsScreen()),
      ManagerDestination.health => MaterialPageRoute<void>(
        builder: (_) => const DataHealthScreen(),
      ),
      ManagerDestination.deployment => MaterialPageRoute<void>(
        builder: (_) => const DeploymentStatusScreen(),
      ),
      ManagerDestination.settings => MaterialPageRoute<void>(
        builder: (_) => const SettingsScreen(),
      ),
      ManagerDestination.trips => null,
    };
    if (route == null) return;
    await Navigator.push(context, route);
    if (destination == ManagerDestination.settings && mounted) {
      await _confirmAndRefresh();
    }
  }

  Widget _buildPublishBar(TripsProvider provider) {
    final status=Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
      Text(_publishing?'Publishing…':provider.isLoading?'Loading…':provider.error!=null?'Needs attention':provider.hasUnsavedChanges?'Draft changes':!provider.hasCompleteRemoteSnapshot?'Load trips first':_publishedCommitSha!=null?'Saved · check deployment':'Synced with GitHub',key:const Key('workspace-publish-state'),style:const TextStyle(fontWeight:FontWeight.w600)),
      Text(_publishFailure??(provider.hasUnsavedChanges?'Draft edits are in this workspace; publish when ready.':_publishedCommitSha!=null?'Open publishing status to verify the live website.':'Workspace edits are not live until published.'),maxLines:2,overflow:TextOverflow.ellipsis,style:Theme.of(context).textTheme.bodySmall),
    ]);
    final action=FilledButton.icon(key:const Key('workspace-publish'),onPressed:provider.isLoading||_publishing||!provider.hasTrips?null:()=>_saveTrips(provider),icon:const Icon(Icons.cloud_upload),label:const Text('Review & publish'));
    return Padding(padding:const EdgeInsets.fromLTRB(16,8,16,8),child:LayoutBuilder(builder:(context,constraints)=>constraints.maxWidth<600?Column(crossAxisAlignment:CrossAxisAlignment.stretch,mainAxisSize:MainAxisSize.min,children:[status,const SizedBox(height:8),action]):Row(children:[Expanded(child:status),const SizedBox(width:12),action])));
  }

  void _showMoreTools(){
    showModalBottomSheet<void>(context:context,isScrollControlled:true,builder:(ctx)=>SafeArea(child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Padding(padding:EdgeInsets.all(16),child:Text('More tools',style:TextStyle(fontSize:20,fontWeight:FontWeight.w600))),
      for(final destination in [ManagerDestination.payments,ManagerDestination.sharedContent,ManagerDestination.deployment,ManagerDestination.health,ManagerDestination.settings]) ListTile(leading:Icon(destination.icon),title:Text(destination.label),subtitle:Text(destination.description),onTap:(){Navigator.pop(ctx);_openDestination(destination);}),
    ]))));
  }
  String _targetKey(){final settings=context.read<SettingsProvider>().settings;return [settings.repositoryOwner,settings.repositoryName,settings.branch,settings.tripsDataPath].join('|');}
  Future<void> _quickEditTrip(String id) async {
    final provider=context.read<TripsProvider>();final original=provider.getTripById(id);if(original==null||provider.isLoading)return;
    final initial=Map<String,dynamic>.from(jsonDecode(jsonEncode(original)) as Map);final target=_targetKey();
    final edited=await showDialog<Map<String,dynamic>>(context:context,builder:(_)=>QuickTripEditor(trip:initial));if(edited==null||!mounted)return;
    final current=provider.getTripById(id),index=provider.getTripIndexById(id);
    if(target!=_targetKey()||provider.isLoading||current==null||index==null){_showTripUnavailable();return;}
    try {provider.updateTrip(index,mergeQuickTripEdit(current,initial,edited));ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Draft saved to workspace. Review & publish when ready.')));}catch(e){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e is StateError?e.message:e.toString())));}
  }

  void _toggleFeaturedFilter() {
    setState(() => _showFeaturedOnly = !_showFeaturedOnly);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        MediaQuery.sizeOf(context).width >= managerDesktopBreakpoint;
    final provider = context.watch<TripsProvider>();
    return Scaffold(
      drawer: isDesktop
          ? null
          : ManagerNavigationDrawer(onSelected: _openDestination),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isDesktop) ...[
              Icon(Icons.terrain, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
            ],
            const Flexible(child: Text('Trips workspace')),
          ],
        ),
        actions: [
          if (provider.hasUnsavedChanges)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Tooltip(
                message: 'Changes have not been published',
                child: Container(
                  key: const Key('unsaved-status'),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_outlined, size: 15),
                      if (isDesktop) ...[
                        const SizedBox(width: 5),
                        const Text(
                          'Unpublished',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _openDestination(ManagerDestination.batches),
            tooltip: 'Preview Upcoming Batches',
          ),
          IconButton(
            icon: Icon(_showFeaturedOnly ? Icons.star : Icons.star_border),
            onPressed: _toggleFeaturedFilter,
            tooltip: 'Show featured only',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: provider.isLoading ? null : _confirmAndRefresh,
            tooltip: 'Refresh (Pull)',
          ),
          if (!isDesktop)
            PopupMenuButton<ManagerDestination>(
              tooltip: 'More tools',
              icon: const Icon(Icons.more_vert),
              onSelected: _openDestination,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: ManagerDestination.homepage,
                  child: ListTile(
                    leading: Icon(Icons.web_outlined),
                    title: Text('Homepage editor'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: ManagerDestination.health,
                  child: ListTile(
                    leading: Icon(Icons.health_and_safety_outlined),
                    title: Text('Data health'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: ManagerDestination.deployment,
                  child: ListTile(
                    leading: Icon(Icons.rocket_launch_outlined),
                    title: Text('Deployment'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: ManagerDestination.settings,
                  child: ListTile(
                    leading: Icon(Icons.settings_outlined),
                    title: Text('Settings'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          const SizedBox(width: 6),
        ],
      ),
      bottomNavigationBar: SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
        _buildPublishBar(provider),
        if(!isDesktop)NavigationBar(key:const Key('manager-bottom-navigation'),selectedIndex:0,onDestinationSelected:(index){if(index==1)_openDestination(ManagerDestination.batches);if(index==2)_openDestination(ManagerDestination.homepage);if(index==3)_showMoreTools();},destinations:const [NavigationDestination(icon:Icon(Icons.route_outlined),label:'Trips'),NavigationDestination(icon:Icon(Icons.calendar_month_outlined),label:'Departures'),NavigationDestination(icon:Icon(Icons.web_outlined),label:'Website'),NavigationDestination(icon:Icon(Icons.more_horiz),label:'More')]),
      ])),
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
              _searchFocusNode.requestFocus(),
          const SingleActivator(LogicalKeyboardKey.keyN, control: true):
              _addNewTrip,
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
            if (!provider.isLoading && provider.hasTrips) _saveTrips(provider);
          },
        },
        child: Focus(
          autofocus: isDesktop,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isDesktop) ...[
                ManagerSideNavigation(onSelected: _openDestination),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Column(
                      children: [
                        _WorkspaceSummary(
                          provider: provider,
                          compact: !isDesktop,
                        ),
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
                                    const Icon(
                                      Icons.warning,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                      onPressed: () =>
                                          _handlePullAndMerge(provider),
                                      child: const Text('Merge'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          _handleForceOverwrite(provider),
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
                              final ids = duplicates
                                  .map((t) => t['id'])
                                  .toSet()
                                  .join(', ');
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                color: Colors.orange[100],
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            builder: (_) =>
                                                const DataHealthScreen(),
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
                            focusNode: _searchFocusNode,
                            decoration: InputDecoration(
                              hintText:
                                  'Search by trip, destination, or departure city',
                              labelText: 'Find a trip',
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
                              helperText: isDesktop
                                  ? 'Ctrl+F to search · drag cards to reorder within a tier'
                                  : null,
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

                              if (provider.error != null &&
                                  !provider.hasConflict) {
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
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 8),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 32,
                                        ),
                                        child: Text(
                                          provider.error!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
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
                                trips = trips
                                    .where((t) => t['featured'] == true)
                                    .toList();
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
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Tap + to add a new trip',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
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
                              final isFiltered =
                                  _searchQuery.isNotEmpty || _showFeaturedOnly;

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
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
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
                                        onToggleFeatured: () =>
                                            _toggleFeatured(tripId),
                                        onQuickEdit: () => _quickEditTrip(tripId),
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
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
      MaterialPageRoute(builder: (_) => const TripEditScreen(initialSection:TripEditorSection.basics)),
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
        builder: (_) => TripEditScreen(trip: trip, index: index,initialSection:TripEditorSection.basics),
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
    if(provider.isLoading||_publishing)return;
    // Review the workspace before publishing.
    final controller=TextEditingController(text:'Update trips via Trip Manager');
    final action = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Review & publish'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trips in this publication: '+provider.tripCount.toString()),
              if(provider.intentionalDeletedIds.isNotEmpty)Text('Trips to remove: '+provider.intentionalDeletedIds.length.toString()),
              const SizedBox(height:12),
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
                        'Publish the workspace to GitHub, then wait for website deployment. Existing conflict checks stay enabled.',
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
                  labelText: 'Change note',
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
              label: const Text('Publish to website'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (action == null || !mounted || _publishing) return;
    setState((){_publishing=true;_publishFailure=null;});

    // Perform the save
    final result = await provider.saveTrips(commitMessage: action);

    if (!mounted) return;
    setState((){_publishing=false;_publishFailure=result.success?null:result.error;});

    if (result.success) {
      _showPublicationSuccess(
        message: 'Saved to GitHub. Check deployment to confirm the website is live.',
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
    setState(()=>_publishedCommitSha=exactSha);
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

class _WorkspaceSummary extends StatelessWidget {
  const _WorkspaceSummary({required this.provider, required this.compact});

  final TripsProvider provider;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final trips = provider.trips;
    final active = trips.where((trip) => trip['isActive'] != false).length;
    final featured = trips
        .where((trip) => trip['isActive'] != false && trip['featured'] == true)
        .length;
    final scheduled = trips
        .where(
          (trip) =>
              trip['isActive'] != false &&
              TripDateUtils.getUpcomingDateRanges(trip).isNotEmpty,
        )
        .length;
    final scheme = Theme.of(context).colorScheme;
    final stats = <({IconData icon, String label, String value})>[
      (icon: Icons.route_outlined, label: 'Trips', value: '${trips.length}'),
      (icon: Icons.visibility_outlined, label: 'Active', value: '$active'),
      (icon: Icons.star_outline, label: 'Featured', value: '$featured'),
      (
        icon: Icons.event_available_outlined,
        label: 'With dates',
        value: '$scheduled',
      ),
    ];

    if (compact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        color: scheme.surface,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final stat in stats) ...[
                _CompactStat(stat: stat),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      );
    }

    return Padding(
      key: const Key('desktop-workspace-summary'),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manage your travel catalogue',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Review trips, update departure dates, and publish when everything is ready.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (var index = 0; index < stats.length; index++) ...[
                Expanded(child: _DesktopStat(stat: stats[index])),
                if (index != stats.length - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  const _CompactStat({required this.stat});

  final ({IconData icon, String label, String value}) stat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stat.icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            '${stat.value} ${stat.label}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DesktopStat extends StatelessWidget {
  const _DesktopStat({required this.stat});

  final ({IconData icon, String label, String value}) stat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(stat.icon, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  stat.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
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
  final VoidCallback onQuickEdit;

  const _TripCard({
    required this.trip,
    required this.onTap,
    required this.onDelete,
    required this.onToggleFeatured,
    required this.onQuickEdit,
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
                    if(value=='quick'){onQuickEdit();}
                    else if (value == 'delete') {
                      onDelete();
                    } else if (value == 'featured') {
                      onToggleFeatured();
                    }
                  },
                  tooltip:'Trip actions',
                  itemBuilder: (context) => [
                    const PopupMenuItem(value:'quick',child:ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.edit_calendar_outlined),title:Text('Quick edit dates & price'))),
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
