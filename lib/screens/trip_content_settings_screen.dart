import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../providers/trips_provider.dart';
import '../services/github_service.dart';
import '../services/trip_content_service.dart';
import '../services/draft_store.dart';
import '../services/workspace_changes.dart';
import '../widgets/local_draft.dart';
import '../widgets/change_review.dart';
import '../widgets/trip_content_editor.dart';
import 'deployment_status_screen.dart';

class TripContentSettingsScreen extends StatefulWidget {
  const TripContentSettingsScreen({super.key});
  @override
  State<TripContentSettingsScreen> createState() =>
      _TripContentSettingsScreenState();
}

class _TripContentSettingsScreenState extends State<TripContentSettingsScreen>
    with LocalDraft<TripContentSettingsScreen> {
  late TripContentService service;
  late AppSettings target;
  Map<String, dynamic>? config, baseline;
  bool busy = false, allowExit = false;
  String? error, commit;
  @override
  String get localScope => DraftStore.scope(target);
  @override
  String get localSlot => 'shared-content';
  @override
  Map<String, dynamic>? get currentDocument => config;
  @override
  bool get draftBusy => busy;
  @override
  void applyDocument(Map<String, dynamic> value) {
    config = copyDocument(value);
  }

  @override
  void initState() {
    super.initState();
    target = context.read<SettingsProvider>().settings.copyWith();
    service = TripContentService(GitHubService(settings: target));
    load();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final value = await service.load();
      if (mounted)
        setState(() {
          config = value;
          baseline = copyDocument(value);
          startLocalDraft(value);
          error = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> publish() async {
    if (DraftStore.scope(context.read<SettingsProvider>().settings) !=
        localScope) {
      setState(
        () =>
            error = 'Repository changed. Reopen this editor before publishing.',
      );
      return;
    }
    final changes = WorkspaceChanges.diff(baseline, config),
        changedSections = changes
            .map((c) => c.path.split('.').skip(1).firstOrNull)
            .whereType<String>()
            .toSet();
    final affected = context
        .read<TripsProvider>()
        .trips
        .where(
          (t) => changedSections.any(
            (key) => ![
              'custom',
              'hidden',
            ].contains((t['contentSections'] as Map?)?[key]?['mode']),
          ),
        )
        .toList();
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Review shared content'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${affected.length} trips use shared defaults for the changed sections.',
                ),
                for (final t in affected) Text('• ${t['title'] ?? t['id']}'),
                const Text('Custom and hidden sections are not replaced.'),
                ChangeReview(changes: changes),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final previous = copyDocument(baseline!);
    setState(() => busy = true);
    final result = await service.save(config!);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (result.success) {
        baseline = copyDocument(config!);
        error = null;
        commit = result.commitSha;
      } else {
        error = result.error;
      }
    });
    if (result.success) {
      await publishedLocalDraft(previous, config!);
      await DraftStore.recordPublication(localScope, commit);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowExit || !hasLocalEdits && !busy,
    onPopInvokedWithResult: (didPop, result) async {
      if (!didPop && !busy && await leaveLocalDraft() && mounted) {
        setState(() => allowExit = true);
        Navigator.pop(context);
      }
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('Shared Trip Content')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (config == null)
                FilledButton(
                  onPressed: busy ? null : load,
                  child: const Text('Load shared content'),
                ),
              if (config != null) ...[
                localDraftBar(),
                AbsorbPointer(
                  absorbing: busy,
                  child: TripContentEditor(
                    key: ValueKey(config.hashCode),
                    value: Map<String, dynamic>.from(
                      config!['sections'] as Map,
                    ),
                    defaults: Map<String, dynamic>.from(
                      config!['sections'] as Map,
                    ),
                    shared: true,
                    onChanged: (v) => setState(() => config!['sections'] = v),
                  ),
                ),
                FilledButton(
                  onPressed: busy ? null : publish,
                  child: const Text('Review & publish shared content'),
                ),
              ],
              if (commit != null)
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DeploymentStatusScreen(savedCommitSha: commit),
                    ),
                  ),
                  child: const Text('Published to GitHub → check deployment'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
