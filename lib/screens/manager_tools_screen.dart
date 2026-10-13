import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/trips_provider.dart';
import '../services/github_service.dart';
import '../services/trips_parser.dart';
import '../services/trip_date_utils.dart';
import '../services/draft_store.dart';
import '../models/homepage_config.dart';
import '../widgets/manager_navigation.dart';

class ManagerToolsScreen extends StatefulWidget {
  const ManagerToolsScreen({
    super.key,
    required this.tool,
    this.onNavigate,
    this.choosePhoto = false,
  });
  final ManagerDestination tool;
  final ValueChanged<ManagerDestination>? onNavigate;
  final bool choosePhoto;
  @override
  State<ManagerToolsScreen> createState() => _ManagerToolsScreenState();
}

class _ManagerToolsScreenState extends State<ManagerToolsScreen> {
  late GitHubService service;
  List<String>? photos;
  List<Map<String, dynamic>>? commits;
  List<WorkflowRunResult> recentRuns = [];
  Map<String, dynamic>? homepage;
  String search = '', filter = '', error = '';
  bool busy = false;
  @override
  void initState() {
    super.initState();
    service = GitHubService(
      settings: context.read<SettingsProvider>().settings,
    );
    _load();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final file = await service.fetchFile('js/homepage-config.json');
      if (file.success) homepage = HomepageConfig.parse(file.content).toJson();
      if (widget.tool == ManagerDestination.library)
        photos = await service.listPhotoPaths();
      if (widget.tool == ManagerDestination.history)
        commits = await service.getRecentCommits(limit: 20);
      if (widget.tool == ManagerDestination.dashboard)
        recentRuns = await service.getRecentDeployments(limit: 10);
      if (!mounted) return;
      setState(
        () => error = file.success
            ? ''
            : file.error ?? 'Website selections unavailable',
      );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void go(ManagerDestination destination) {
    Navigator.pop(context);
    widget.onNavigate?.call(destination);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.tool.label),
      actions: [
        IconButton(
          onPressed: busy ? null : _load,
          tooltip: 'Refresh tools',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Consumer<TripsProvider>(
      builder: (ctx, p, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (busy) const LinearProgressIndicator(),
          if (error.isNotEmpty)
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (widget.tool == ManagerDestination.dashboard) ..._dashboard(p),
          if (widget.tool == ManagerDestination.library) ..._library(p),
          if (widget.tool == ManagerDestination.history) ..._history(p),
        ],
      ),
    ),
  );
  List<Widget> _dashboard(TripsProvider p) {
    final upcoming = TripDateUtils.buildUpcomingBatches(
          p.trips,
          limit: 1000000,
        ),
        missing = p.trips
            .where(
              (t) =>
                  t['isActive'] != false &&
                  TripDateUtils.getUpcomingDateRanges(t).isEmpty,
            )
            .toList();
    return [
      Text(
        'Your daily workspace',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      if (recentRuns.isNotEmpty)
        ListTile(
          leading: Icon(
            recentRuns.first.isFailure ? Icons.error_outline : Icons.cloud_sync,
          ),
          title: Text(
            recentRuns.first.isFailure
                ? 'Latest website deployment failed'
                : recentRuns.first.isInProgress
                ? 'Website deployment in progress'
                : 'Latest website workflow: ${recentRuns.first.conclusion ?? recentRuns.first.status}',
          ),
          subtitle: Text(
            'Last successful workflow: ${recentRuns.where((r) => r.isSuccess).firstOrNull?.updatedAt ?? 'Not available in recent history'}. Open Publishing status to verify the deployed commit.',
          ),
          onTap: () => go(ManagerDestination.deployment),
        ),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _metric(
            'Bookable departures',
            upcoming.fold<int>(0, (n, b) => n + b.trips.length),
          ),
          _metric('Trips without bookable dates', missing.length),
          _metric('Unpublished trip changes', p.changes.length),
        ],
      ),
      if (p.draftError != null)
        Text(
          p.draftError!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      if (p.lastDraftSaved != null)
        Text('Local draft saved: ${p.lastDraftSaved!.toLocal()}'),
      ListTile(
        leading: const Icon(Icons.cloud_sync),
        title: const Text('Publishing status and deployment failures'),
        subtitle: Text(
          p.lastPublishedCommit == null
              ? 'Check GitHub validation and the last successful website update'
              : 'Published to GitHub: ${p.lastPublishedCommit!.substring(0, 7)} — check deployment before calling it live',
        ),
        onTap: () => go(ManagerDestination.deployment),
      ),
      Wrap(
        spacing: 8,
        children: [
          FilledButton.icon(
            onPressed: p.isLoading ? null : () => bulkDates(context, p),
            icon: const Icon(Icons.edit_calendar),
            label: const Text('Bulk date edit'),
          ),
          OutlinedButton(
            onPressed: () => go(ManagerDestination.homepage),
            child: const Text('Homepage selections'),
          ),
          OutlinedButton(
            onPressed: () => go(ManagerDestination.library),
            child: const Text('Photo library'),
          ),
          OutlinedButton(
            onPressed: () => go(ManagerDestination.history),
            child: const Text('Version recovery'),
          ),
        ],
      ),
      Text(
        'Trips needing dates',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      for (final t in missing)
        ListTile(
          title: Text(t['title']?.toString() ?? t['id'].toString()),
          subtitle: const Text(
            'No bookable dates: expired, missing or invalid. Edit Trips → Dates & price.',
          ),
        ),
      Text(
        'Upcoming departures',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      for (final b in upcoming.take(6))
        for (final t in b.trips)
          ListTile(title: Text(t.title), subtitle: Text(b.dateLabel)),
      if (homepage != null) ...[
        const Divider(),
        const Text('Homepage selection is independent of Active and Featured.'),
        for (final t in p.trips.where((t) => t['isActive'] != false))
          ListTile(
            title: Text(t['title']?.toString() ?? ''),
            subtitle: Text(_visibility(t)),
          ),
      ],
    ];
  }

  Widget _metric(String label, int n) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('$n', style: Theme.of(context).textTheme.headlineMedium),
          Text(label),
        ],
      ),
    ),
  );
  String _visibility(Map<String, dynamic> trip) {
    if (trip['isActive'] == false) return 'Inactive: hidden from the website';
    if (homepage == null)
      return 'Upcoming Batches selection could not be loaded';
    final options = homepage!['upcomingBatches'] as Map;
    if (options['enabled'] != true) return 'Upcoming Batches section is hidden';
    if (options['tripSelection'] == 'selected' &&
        !(options['tripIds'] as List).contains(trip['id']))
      return 'Not selected for Upcoming Batches';
    final selected = HomepageConfig.parse(
      jsonEncode(homepage),
    ).selectedTrips([trip]);
    if (selected.isEmpty ||
        TripDateUtils.getUpcomingDateRanges(selected.first).isEmpty)
      return 'Selected trip, but no selected dates are currently bookable';
    return 'Selected for Upcoming Batches · ${trip['featured'] == true ? 'Featured on homepage' : 'Not featured'}';
  }

  List<Widget> _library(TripsProvider p) {
    final settings = service.settings, scope = DraftStore.scope(settings);
    final metadata =
        DraftStore.read(scope, 'photo-tags')?['data'] as Map? ?? {};
    final all = <String>{
      for (final name in photos ?? []) name,
      for (final t in p.trips) ...[
        if (t['image'] is String) t['image'] as String,
        if (t['cardImage'] is String) t['cardImage'] as String,
        ...(t['galleryImages'] as List? ?? []).cast<String>(),
      ],
      if (homepage != null)
        (homepage!['hero'] as Map)['backgroundImage'].toString(),
    }.toList()..sort();
    final shown = all
        .where(
          (path) =>
              ('$path ${metadata[path] ?? ''} ${p.trips.where((t) => _uses(t, path)).map((t) => t['title']).join(' ')}')
                  .toLowerCase()
                  .contains(search.toLowerCase()),
        )
        .toList();
    return [
      const Text(
        'Reuse originals. Tags are saved on this device; choosing a photo changes only the current draft.',
      ),
      TextField(
        decoration: const InputDecoration(
          labelText: 'Find a photo by name, destination or tag',
        ),
        onChanged: (v) => setState(() => search = v),
      ),
      if (shown.isEmpty)
        const ListTile(
          title: Text(
            'No photos match. Upload a photo from the trip or homepage editor.',
          ),
        ),
      for (final path in shown)
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  path.startsWith('https://')
                      ? path
                      : 'https://raw.githubusercontent.com/${settings.repositoryOwner}/${settings.repositoryName}/${settings.branch}/$path',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
              ListTile(
                title: Text(path.split('/').last),
                subtitle: Text(
                  'Tags: ${metadata[path] ?? 'none'}\nUsed by: ${[...p.trips.where((t) => _uses(t, path)).map((t) => t['title']), if (homepage != null && jsonEncode(homepage).contains(path)) 'Homepage'].join(', ')}',
                ),
                trailing: widget.choosePhoto
                    ? IconButton(
                        tooltip: 'Use this photo',
                        icon: const Icon(Icons.check_circle),
                        onPressed: () => Navigator.pop(context, path),
                      )
                    : null,
              ),
              TextButton(
                onPressed: () async {
                  final controller = TextEditingController(
                    text: metadata[path]?.toString() ?? '',
                  );
                  final value = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Destination tags'),
                      content: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: 'Tags, separated by commas',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, controller.text),
                          child: const Text('Save tags'),
                        ),
                      ],
                    ),
                  );
                  controller.dispose();
                  if (value != null) {
                    await DraftStore.write(scope, 'photo-tags', {
                      ...metadata,
                      path: value,
                    });
                    if (mounted) setState(() {});
                  }
                },
                child: const Text('Edit tags'),
              ),
            ],
          ),
        ),
    ];
  }

  bool _uses(Map trip, String photo) => [
    trip['image'],
    trip['cardImage'],
    ...(trip['galleryImages'] as List? ?? []),
  ].contains(photo);
  List<Widget> _history(TripsProvider p) {
    final records = DraftStore.history(p.draftScope, 'workspace');
    final saved = DraftStore.read(p.draftScope, 'workspace');
    return [
      const Text(
        'Restore a version as a local draft. Review differences and publish separately; restoring never rewinds GitHub directly.',
      ),
      if (saved != null)
        ListTile(
          title: const Text('Recover saved workspace draft'),
          subtitle: Text(saved['savedAt'].toString()),
          onTap: () => _restore(
            p,
            (saved['data']['trips'] as List)
                .map((t) => Map<String, dynamic>.from(t as Map))
                .toList(),
          ),
        ),
      Text(
        'Local saved versions',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (records.isEmpty)
        const Text(
          'No local versions yet. Versions are recorded when you publish.',
        ),
      for (final r in records)
        ListTile(
          title: Text(r['label'].toString()),
          subtitle: Text(r['time'].toString()),
          trailing: const Icon(Icons.restore),
          onTap: p.isLoading
              ? null
              : () => _restore(
                  p,
                  (r['data']['trips'] as List)
                      .map((t) => Map<String, dynamic>.from(t as Map))
                      .toList(),
                ),
        ),
      const Divider(),
      Text(
        'Published GitHub versions',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      for (final commit in commits ?? [])
        ListTile(
          title: Text(commit['commit']['message'].toString()),
          subtitle: Text(
            '${commit['sha'].toString().substring(0, 7)} · ${commit['commit']['author']['date']}',
          ),
          onTap: p.isLoading || busy
              ? null
              : () async {
                  setState(() => busy = true);
                  try {
                    final file = await service.fetchFileAtRef(
                      service.settings.tripsDataPath,
                      commit['sha'].toString(),
                    );
                    if (!file.success)
                      throw StateError(file.error ?? 'Could not read version');
                    final parsed = TripsParser.parseTripsDocument(file.content);
                    if (parsed.errors.isNotEmpty)
                      throw StateError(parsed.errors.join('\n'));
                    if (mounted) await _restore(p, parsed.trips);
                  } catch (e) {
                    if (mounted) setState(() => error = e.toString());
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
        ),
    ];
  }

  Future<void> _restore(
    TripsProvider p,
    List<Map<String, dynamic>> trips,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore as draft?'),
        content: const Text(
          'Current edits will be replaced in the workspace. You can undo this action. Nothing will be published.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore draft'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      if (DraftStore.scope(service.settings) != p.draftScope) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Repository changed. Reopen history for the current repository.',
            ),
          ),
        );
        return;
      }
      p.restoreVersion(trips);
      await p.flushDraft();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Version restored as a draft. Review before publishing.',
            ),
          ),
        );
    }
  }
}

Future<void> bulkDates(BuildContext context, TripsProvider provider) async {
  final chosen = <String>{};
  DateTimeRange? range;
  bool remove = false;
  final approved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Bulk departure editing'),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text(
                  'Changes are saved to the workspace only. Existing unrelated dates are preserved.',
                ),
                SwitchListTile(
                  title: const Text('Remove date range instead of adding'),
                  value: remove,
                  onChanged: (v) => set(() => remove = v),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final value = await showDateRangePicker(
                      context: ctx,
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2199, 12, 31),
                    );
                    if (value != null) set(() => range = value);
                  },
                  child: Text(
                    range == null
                        ? 'Choose a departure range'
                        : TripDateUtils.formatCanonical(
                            TripDateUtils.fromDates(range!.start, range!.end),
                          ),
                  ),
                ),
                for (final t in provider.trips)
                  CheckboxListTile(
                    title: Text(t['title']?.toString() ?? t['id'].toString()),
                    value: chosen.contains(t['id']),
                    onChanged: (v) => set(() {
                      if (v == true)
                        chosen.add(t['id'].toString());
                      else
                        chosen.remove(t['id']);
                    }),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: range == null || chosen.isEmpty
                ? null
                : () => Navigator.pop(ctx, true),
            child: Text(
              '${remove ? 'Remove from' : 'Add to'} ${chosen.length} trips',
            ),
          ),
        ],
      ),
    ),
  );
  if (approved != true || range == null || !context.mounted) return;
  final selected = TripDateUtils.fromDates(range!.start, range!.end),
      label = TripDateUtils.formatCanonical(selected);
  provider.applyBulkDates(chosen, label, remove: remove);
  await provider.flushDraft();
}
