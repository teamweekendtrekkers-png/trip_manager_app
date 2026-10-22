import '../services/trip_attention.dart';
import '../services/booking_review_filter.dart';
import 'booking_review_screen.dart';
import '../widgets/manager_setup_checklist.dart';
import '../widgets/trip_editor_sections.dart';
import 'trip_edit_screen.dart';
import 'package:url_launcher/url_launcher.dart';
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
    this.embedded = false,
    this.githubService,
  });
  final ManagerDestination tool;
  final ValueChanged<ManagerDestination>? onNavigate;
  final bool choosePhoto;
  final bool embedded;
  final GitHubService? githubService;
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
    service =
        widget.githubService ??
        GitHubService(settings: context.read<SettingsProvider>().settings);
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
    if (!widget.embedded) Navigator.pop(context);
    widget.onNavigate?.call(destination);
  }

  @override
  Widget build(BuildContext context) => widget.embedded
      ? _content()
      : Scaffold(
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
          body: _content(),
        );

  Widget _content() => Consumer<TripsProvider>(
    builder: (ctx, p, _) => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (busy) const LinearProgressIndicator(),
        if (error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.wifi_off_outlined),
                title: const Text('Some website details could not load'),
                subtitle: const Text(
                  'Your trip drafts are still available. Try again when connected.',
                ),
                trailing: IconButton(
                  tooltip: 'Retry website details',
                  onPressed: busy ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ),
            ),
          ),
        if (widget.tool == ManagerDestination.dashboard) ..._dashboard(p),
        if (widget.tool == ManagerDestination.library) ..._library(p),
        if (widget.tool == ManagerDestination.history) ..._history(p),
      ],
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
    final attention = p.trips
        .where((trip) => tripAttention(trip).isNotEmpty)
        .toList();
    return [
      Text(
        'Your daily workspace',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(
        'Start with bookings, update a trip, or resolve an item that needs attention.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),
      ManagerSetupChecklist(
        configured: context.read<SettingsProvider>().isConfigured,
        hasTrips: p.hasTrips,
        hasPublished: p.lastPublishedCommit != null,
        onConnection: () => go(ManagerDestination.settings),
        onTrips: () => go(ManagerDestination.trips),
        onPayments: () => go(ManagerDestination.payments),
        onPublish: () => go(ManagerDestination.deployment),
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = width >= 900
              ? 4
              : width >= 300
              ? 2
              : 1;
          final tileWidth = (width - (columns - 1) * 12) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _task(
                tileWidth,
                Icons.add_circle_outline,
                'Add trip',
                'Create a trip step by step',
                p.isLoading
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const TripEditScreen(
                            initialSection: TripEditorSection.basics,
                          ),
                        ),
                      ),
              ),
              _task(
                tileWidth,
                Icons.route_outlined,
                'Edit trips',
                'Dates, prices, photos and content',
                () => go(ManagerDestination.trips),
              ),
              _task(
                tileWidth,
                Icons.fact_check_outlined,
                'Pending payments',
                'Review customer submissions',
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BookingReviewScreen(
                      initialFilter: BookingReviewFilter.pending,
                    ),
                  ),
                ),
                key: const Key('dashboard-booking-review'),
              ),
              _task(
                tileWidth,
                Icons.calendar_month_outlined,
                'Departures',
                'See upcoming trip dates',
                () => go(ManagerDestination.batches),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          TextButton.icon(
            key: const Key('dashboard-payments'),
            onPressed: () => go(ManagerDestination.payments),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('UPI & coupons'),
          ),
          TextButton.icon(
            onPressed: () => go(ManagerDestination.deployment),
            icon: const Icon(Icons.cloud_sync_outlined),
            label: const Text('Publishing status'),
          ),
          TextButton.icon(
            onPressed: () async {
              try {
                final opened = await launchUrl(
                  Uri.parse('https://www.teamweekendtrekkers.com'),
                  mode: LaunchMode.externalApplication,
                );
                if (!opened) throw StateError('Unavailable');
              } catch (_) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not open the website. Please try again.',
                      ),
                    ),
                  );
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open live website'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Text('At a glance', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
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
          _metric(
            'Inactive trips',
            p.trips.where((t) => t['isActive'] == false).length,
          ),
          _metric(
            'Bookable trips',
            p.trips
                .where((t) => TripDateUtils.getUpcomingDateRanges(t).isNotEmpty)
                .length,
          ),
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
        'Needs attention (${attention.length})',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (attention.isEmpty)
        const ListTile(
          leading: Icon(Icons.check_circle_outline),
          title: Text('Active trips have dates, prices and cover photos.'),
        ),
      for (final t in attention)
        ListTile(
          leading: const Icon(Icons.rule_outlined),
          title: Text(t['title']?.toString() ?? t['id'].toString()),
          subtitle: Text(tripAttention(t).join(' · ')),
          trailing: const Icon(Icons.chevron_right),
          onTap: p.isLoading
              ? null
              : () {
                  final id = t['id']?.toString() ?? '';
                  final current = p.getTripById(id),
                      index = p.getTripIndexById(id);
                  if (current == null || index == null) return;
                  final issues = tripAttention(current);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => TripEditScreen(
                        trip: current,
                        index: index,
                        initialSection:
                            issues.contains('Add upcoming dates') ||
                                issues.contains('Check price')
                            ? TripEditorSection.dates
                            : TripEditorSection.photos,
                      ),
                    ),
                  );
                },
        ),
      Text(
        'Upcoming departures',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      for (final b in upcoming.take(6))
        for (final t in b.trips)
          ListTile(
            title: Text(t.title),
            subtitle: Text(b.dateLabel),
            trailing: const Icon(Icons.chevron_right),
            onTap: p.isLoading || t.id == null
                ? null
                : () {
                    final index = p.getTripIndexById(t.id!);
                    if (index == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TripEditScreen(
                          trip: p.getTripById(t.id!)!,
                          index: index,
                          initialSection: TripEditorSection.dates,
                        ),
                      ),
                    );
                  },
          ),
      if (upcoming.isEmpty)
        ListTile(
          leading: const Icon(Icons.event_available_outlined),
          title: const Text('No upcoming departures'),
          subtitle: const Text('Add dates to an active trip to show it here.'),
          onTap: () => go(ManagerDestination.trips),
        ),
      if (homepage != null)
        ExpansionTile(
          title: const Text('Website visibility details'),
          subtitle: const Text('Check which trips appear in Upcoming Batches'),
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Homepage selection is independent of Active and Featured.',
              ),
            ),
            for (final t in p.trips.where((t) => t['isActive'] != false))
              ListTile(
                title: Text(t['title']?.toString() ?? ''),
                subtitle: Text(_visibility(t)),
              ),
          ],
        ),
    ];
  }

  Widget _task(
    double width,
    IconData icon,
    String title,
    String description,
    VoidCallback? onTap, {
    Key? key,
  }) => SizedBox(
    width: width,
    child: Card(
      key: key,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: onTap == null
                    ? Theme.of(context).disabledColor
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(description, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _metric(String label, int n) => SizedBox(
    width: MediaQuery.sizeOf(context).width < 480 ? 150 : 190,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('$n', style: Theme.of(context).textTheme.headlineMedium),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
  String _visibility(Map<String, dynamic> trip) {
    if (trip['isActive'] == false)
      return 'Inactive: included when trips without available dates are shown';
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
  final ranges = <String>[];
  final scope = provider.draftScope;
  bool remove = false;
  String? feedback;
  final approved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Bulk departure editing'),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Add several ranges, then apply them to the selected trips. Changes stay in your draft; unrelated dates are preserved.',
                ),
                SwitchListTile(
                  title: const Text('Remove date ranges instead of adding'),
                  value: remove,
                  onChanged: (value) => set(() => remove = value),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range),
                  onPressed: () async {
                    final value = await showDateRangePicker(
                      context: ctx,
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2199, 12, 31),
                    );
                    if (value == null || !ctx.mounted) return;
                    final label = TripDateUtils.formatCanonical(
                      TripDateUtils.fromDates(value.start, value.end),
                    );
                    set(() {
                      if (ranges.any(
                        (item) =>
                            TripDateUtils.parse(item)?.key ==
                            TripDateUtils.parse(label)?.key,
                      )) {
                        feedback = 'That range is already selected.';
                      } else {
                        ranges.add(label);
                        feedback = null;
                      }
                    });
                  },
                  label: const Text('Add departure range'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Paste multiple ranges'),
                  onPressed: () async {
                    var pasted = '';
                    final text = await showDialog<String>(
                      context: ctx,
                      builder: (pasteContext) => AlertDialog(
                        title: const Text('Paste date ranges'),
                        content: TextField(
                          onChanged: (value) => pasted = value,
                          minLines: 4,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: 'One range per line',
                            hintText: 'Oct 23-25, 2026\nOct 30-Nov 1, 2026',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(pasteContext),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.pop(pasteContext, pasted),
                            child: const Text('Add ranges'),
                          ),
                        ],
                      ),
                    );
                    if (text == null || !ctx.mounted) return;
                    final lines = text
                        .split('\n')
                        .map((line) => line.trim())
                        .where((line) => line.isNotEmpty)
                        .toList();
                    final invalid = lines
                        .where((line) => TripDateUtils.parse(line) == null)
                        .toList();
                    set(() {
                      if (invalid.isNotEmpty) {
                        feedback =
                            'No ranges added. Check: ${invalid.join('; ')}';
                        return;
                      }
                      var duplicates = 0;
                      for (final line in lines) {
                        final range = TripDateUtils.parse(line)!;
                        if (ranges.any(
                          (item) => TripDateUtils.parse(item)?.key == range.key,
                        )) {
                          duplicates++;
                        } else {
                          ranges.add(TripDateUtils.formatCanonical(range));
                        }
                      }
                      feedback = duplicates > 0
                          ? '$duplicates duplicate range(s) skipped.'
                          : null;
                    });
                  },
                ),
                if (feedback != null)
                  Text(feedback!, key: const Key('bulk-range-feedback')),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final label in ranges)
                      InputChip(
                        key: ValueKey('bulk-range-$label'),
                        label: Text(label),
                        onDeleted: () => set(() => ranges.remove(label)),
                      ),
                  ],
                ),
                Text('${ranges.length} date range(s) selected'),
                for (final trip in provider.trips)
                  CheckboxListTile(
                    title: Text(
                      trip['title']?.toString() ?? trip['id'].toString(),
                    ),
                    value: chosen.contains(trip['id']),
                    onChanged: (value) => set(() {
                      if (value == true)
                        chosen.add(trip['id'].toString());
                      else
                        chosen.remove(trip['id']);
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
            onPressed: ranges.isEmpty || chosen.isEmpty
                ? null
                : () => Navigator.pop(ctx, true),
            child: Text(
              '${remove ? 'Remove' : 'Add'} ${ranges.length} range(s) ${remove ? 'from' : 'to'} ${chosen.length} trip(s)',
            ),
          ),
        ],
      ),
    ),
  );
  if (approved != true || ranges.isEmpty || !context.mounted) return;
  if (provider.draftScope != scope || provider.isLoading) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'The workspace changed. Reopen bulk editing before applying dates.',
        ),
      ),
    );
    return;
  }
  provider.applyBulkDateRanges(chosen, ranges, remove: remove);
  await provider.flushDraft();
}
