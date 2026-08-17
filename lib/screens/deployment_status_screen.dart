import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/settings_provider.dart';
import '../services/deployment_monitor.dart';
import '../services/github_service.dart';
import '../services/notification_service.dart';

class DeploymentStatusScreen extends StatefulWidget {
  const DeploymentStatusScreen({
    super.key,
    this.savedCommitSha,
    this.githubService,
    this.notificationClient,
    this.now,
    this.pollInterval = const Duration(seconds: 5),
    this.monitorTimeout = const Duration(minutes: 10),
  });

  /// When supplied, monitor only workflows created for this exact commit.
  /// A null value retains the generic status/history view used by Settings.
  final String? savedCommitSha;

  /// Test seams; production callers use the Settings-backed defaults.
  final GitHubService? githubService;
  final DeploymentNotificationClient? notificationClient;
  final DateTime Function()? now;
  final Duration pollInterval;
  final Duration monitorTimeout;

  @override
  State<DeploymentStatusScreen> createState() => _DeploymentStatusScreenState();
}

class _DeploymentStatusScreenState extends State<DeploymentStatusScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  DeploymentStatusResult? _siteStatus;
  List<WorkflowRunResult> _builds = [];
  bool _isLoading = true;
  String? _error;
  Timer? _pollTimer;
  late AnimationController _pulseController;
  DateTime? _lastRefreshed;
  DateTime? _monitorStartedAt;
  DeploymentMonitorState? _monitorState;
  final DeploymentNotificationGate _notificationGate =
      DeploymentNotificationGate();
  bool _notificationPermissionRequested = false;
  Future<void>? _notificationPermissionFuture;
  bool _pollInFlight = false;
  bool _isAppVisible = true;
  Animation<double>? _routeSecondaryAnimation;

  String? get _trackedSha {
    final value = widget.savedCommitSha?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  bool get _isTrackingCommit => _trackedSha != null;
  DateTime get _now => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (_isTrackingCommit) {
      _monitorState = const DeploymentMonitorState(
        phase: DeploymentPhase.waiting,
        detail: 'Waiting for GitHub Actions to create a workflow run.',
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_fetchStatus());
      if (_isTrackingCommit) _beginCommitMonitoring();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routeSecondaryAnimation?.removeListener(_handleRouteVisibilityChanged);
    _pollTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.secondaryAnimation;
    if (identical(animation, _routeSecondaryAnimation)) return;
    _routeSecondaryAnimation?.removeListener(_handleRouteVisibilityChanged);
    _routeSecondaryAnimation = animation;
    _routeSecondaryAnimation?.addListener(_handleRouteVisibilityChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppVisible = state == AppLifecycleState.resumed;
    if (!_isAppVisible) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    if (_monitorState?.shouldPoll == true) {
      unawaited(_pollTrackedCommit());
    }
  }

  void _handleRouteVisibilityChanged() {
    if (!_isScreenVisible) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    if (_monitorState?.shouldPoll == true && _pollTimer == null) {
      unawaited(_pollTrackedCommit());
    }
  }

  GitHubService _createService() {
    if (widget.githubService != null) return widget.githubService!;
    final settings = context.read<SettingsProvider>().settings;
    return GitHubService(settings: settings);
  }

  DeploymentNotificationClient get _notificationClient =>
      widget.notificationClient ?? NotificationService();

  Future<void> _fetchStatus() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = _createService();
      final results = await Future.wait([
        service.getDeploymentStatus(),
        service.getRecentDeployments(),
      ]);

      if (!mounted) return;

      final siteStatus = results[0] as DeploymentStatusResult;
      final builds = results[1] as List<WorkflowRunResult>;

      setState(() {
        _siteStatus = siteStatus;
        _builds = builds;
        _isLoading = false;
        _lastRefreshed = _now;
      });
      _syncPulseAnimation();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _beginCommitMonitoring() {
    if (!_isTrackingCommit) return;
    _monitorStartedAt = _now;
    if (!_notificationPermissionRequested) {
      _notificationPermissionRequested = true;
      _notificationPermissionFuture = _requestNotificationPermission();
    }
    unawaited(_pollTrackedCommit());
  }

  Future<void> _requestNotificationPermission() async {
    try {
      await _notificationClient.requestPermission();
    } catch (_) {
      // Notification permission must never prevent status monitoring.
    }
  }

  bool get _isScreenVisible {
    if (!mounted || !_isAppVisible) return false;
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  Future<void> _pollTrackedCommit() async {
    final sha = _trackedSha;
    final startedAt = _monitorStartedAt;
    if (sha == null || startedAt == null || !_isScreenVisible) return;
    if (_pollInFlight) return;

    _pollTimer?.cancel();
    _pollTimer = null;
    _pollInFlight = true;

    try {
      WorkflowRunsQueryResult query;
      if (!_now.isBefore(startedAt.add(widget.monitorTimeout))) {
        query = const WorkflowRunsQueryResult(success: true);
      } else {
        try {
          query = await _createService().getWorkflowRunsForCommit(sha);
        } catch (error) {
          query = WorkflowRunsQueryResult(
            success: false,
            error: 'Could not check the GitHub Actions workflow: $error',
          );
        }
      }

      if (!mounted) return;
      final state = DeploymentStatusMapper.evaluate(
        query: query,
        commitSha: sha,
        monitorStartedAt: startedAt,
        now: _now,
        timeout: widget.monitorTimeout,
      );
      setState(() {
        _monitorState = state;
        _lastRefreshed = _now;
      });
      _syncPulseAnimation();

      if (_notificationGate.shouldNotify(state)) {
        unawaited(_notifyForCompletion(state));
      }

      if (state.shouldPoll) _scheduleNextPoll();
    } finally {
      _pollInFlight = false;
    }
  }

  void _scheduleNextPoll() {
    _pollTimer?.cancel();
    if (!_isScreenVisible || _monitorState?.shouldPoll != true) return;
    _pollTimer = Timer(widget.pollInterval, () {
      _pollTimer = null;
      unawaited(_pollTrackedCommit());
    });
  }

  Future<void> _notifyForCompletion(DeploymentMonitorState state) async {
    try {
      await _notificationPermissionFuture;
      await _notificationClient.showDeploymentNotification(
        success: state.isSuccess,
        commitMessage: state.run?.commitMessage,
      );
    } catch (_) {
      // A local-notification failure does not change deployment state.
    }
  }

  void _syncPulseAnimation() {
    final isActive = _isTrackingCommit
        ? _monitorState?.shouldPoll == true
        : _builds.any((build) => build.isInProgress);
    if (isActive) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  void _restartCommitMonitoring() {
    _pollTimer?.cancel();
    setState(() {
      _monitorStartedAt = _now;
      _monitorState = const DeploymentMonitorState(
        phase: DeploymentPhase.waiting,
        detail: 'Waiting for GitHub Actions to create a workflow run.',
      );
    });
    unawaited(_pollTrackedCommit());
  }

  /// The latest build (first in the list)
  WorkflowRunResult? get _latestBuild => _isTrackingCommit
      ? _monitorState?.run
      : (_builds.isNotEmpty ? _builds.first : null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deployment Status'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchStatus,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading && _builds.isEmpty && !_isTrackingCommit
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Checking deployment status...'),
                ],
              ),
            )
          : _error != null && _builds.isEmpty && !_isTrackingCommit
          ? _buildErrorView()
          : RefreshIndicator(
              onRefresh: _fetchStatus,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatusHero(),
                  const SizedBox(height: 16),
                  if (_builds.isNotEmpty) _buildBuildsHistory(),
                  const SizedBox(height: 16),
                  if (_siteStatus != null) _buildSiteInfo(),
                  const SizedBox(height: 16),
                  _buildQuickActions(),
                  if (_lastRefreshed != null) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'Last checked: ${_formatTime(_lastRefreshed!)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ),
                  ],
                  if (_isTrackingCommit &&
                      _monitorState?.shouldPoll == true) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Auto-refreshing every ${widget.pollInterval.inSeconds} seconds...',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue[400],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Failed to fetch status',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchStatus,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHero() {
    final build = _latestBuild;
    final presentation = _isTrackingCommit
        ? _trackedStatusPresentation(_monitorState!)
        : _genericStatusPresentation(build);
    final statusColor = presentation.color;
    final isInProgress = presentation.active;
    final displayedSha = build?.commitSha ?? _trackedSha;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              statusColor.withValues(alpha: 0.1),
              statusColor.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Animated status icon
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: isInProgress
                      ? 1.0 + (_pulseController.value * 0.15)
                      : 1.0,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor.withValues(
                        alpha: isInProgress
                            ? 0.15 + (_pulseController.value * 0.1)
                            : 0.15,
                      ),
                    ),
                    child: isInProgress
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation(statusColor),
                            ),
                          )
                        : Icon(presentation.icon, size: 44, color: statusColor),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              presentation.text,
              key: _isTrackingCommit && _monitorState != null
                  ? ValueKey('deployment-phase-${_monitorState!.phase.value}')
                  : null,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              presentation.subtext,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            if (displayedSha != null) ...[
              const SizedBox(height: 8),
              Text(
                'Commit: ${_shortSha(displayedSha)}${build?.createdAt != null ? "  •  ${_formatDateTime(build!.createdAt!)}" : ""}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontFamily: 'monospace',
                ),
              ),
            ],
            if (_isTrackingCommit &&
                (_monitorState?.phase == DeploymentPhase.monitorTimeout ||
                    _monitorState?.phase == DeploymentPhase.permissionDenied ||
                    _monitorState?.phase == DeploymentPhase.apiError)) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _restartCommitMonitoring,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry monitoring'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  ({Color color, IconData icon, String text, String subtext, bool active})
  _trackedStatusPresentation(DeploymentMonitorState state) {
    final fallback = state.detail ?? 'Status: ${state.phase.value}';
    return switch (state.phase) {
      DeploymentPhase.waiting => (
        color: Colors.blueGrey,
        icon: Icons.hourglass_empty,
        text: 'Waiting for workflow',
        subtext: fallback,
        active: true,
      ),
      DeploymentPhase.queued => (
        color: Colors.blue,
        icon: Icons.hourglass_top,
        text: 'Queued',
        subtext: 'Deployment is queued and will start soon.',
        active: true,
      ),
      DeploymentPhase.running => (
        color: Colors.blue,
        icon: Icons.sync,
        text: 'Deploying',
        subtext: 'The tracked commit is being deployed.',
        active: true,
      ),
      DeploymentPhase.success => (
        color: Colors.green,
        icon: Icons.check_circle,
        text: 'Deployed',
        subtext: 'The workflow for the tracked commit succeeded.',
        active: false,
      ),
      DeploymentPhase.failure => (
        color: Colors.red,
        icon: Icons.cancel,
        text: 'Failed',
        subtext: 'Deployment failed — check the workflow logs.',
        active: false,
      ),
      DeploymentPhase.cancelled => (
        color: Colors.orange,
        icon: Icons.block,
        text: 'Cancelled',
        subtext: 'The deployment workflow was cancelled.',
        active: false,
      ),
      DeploymentPhase.timedOut => (
        color: Colors.red,
        icon: Icons.timer_off,
        text: 'Workflow timed out',
        subtext: 'GitHub stopped the workflow after it exceeded its limit.',
        active: false,
      ),
      DeploymentPhase.actionRequired => (
        color: Colors.orange,
        icon: Icons.report_problem_outlined,
        text: 'Action required',
        subtext: 'GitHub requires approval or another manual action.',
        active: false,
      ),
      DeploymentPhase.stale => (
        color: Colors.orange,
        icon: Icons.history_toggle_off,
        text: 'Stale',
        subtext: 'GitHub marked this workflow run as stale.',
        active: false,
      ),
      DeploymentPhase.skipped => (
        color: Colors.grey,
        icon: Icons.skip_next,
        text: 'Skipped',
        subtext: 'The deployment workflow was skipped.',
        active: false,
      ),
      DeploymentPhase.neutral => (
        color: Colors.grey,
        icon: Icons.info_outline,
        text: 'Completed',
        subtext: 'The workflow completed with a neutral conclusion.',
        active: false,
      ),
      DeploymentPhase.monitorTimeout => (
        color: Colors.orange,
        icon: Icons.timer_off_outlined,
        text: 'Monitoring timed out',
        subtext: fallback,
        active: false,
      ),
      DeploymentPhase.permissionDenied => (
        color: Colors.red,
        icon: Icons.lock_outline,
        text: 'Actions permission required',
        subtext: fallback,
        active: false,
      ),
      DeploymentPhase.apiError => (
        color: Colors.red,
        icon: Icons.cloud_off,
        text: 'GitHub API error',
        subtext: fallback,
        active: false,
      ),
    };
  }

  ({Color color, IconData icon, String text, String subtext, bool active})
  _genericStatusPresentation(WorkflowRunResult? build) {
    if (build == null) {
      return (
        color: Colors.grey,
        icon: Icons.help_outline,
        text: 'Unknown',
        subtext: 'No deployment data found',
        active: false,
      );
    }
    if (build.isInProgress) {
      final queued = build.status == 'queued';
      return (
        color: Colors.blue,
        icon: queued ? Icons.hourglass_top : Icons.sync,
        text: queued ? 'Queued' : 'Deploying',
        subtext: queued
            ? 'Deployment is queued and will start soon.'
            : 'Website is being deployed.',
        active: true,
      );
    }
    if (build.isSuccess) {
      return (
        color: Colors.green,
        icon: Icons.check_circle,
        text: 'Deployed',
        subtext: 'Website is live with the latest changes',
        active: false,
      );
    }
    if (build.isFailure) {
      return (
        color: Colors.red,
        icon: Icons.cancel,
        text: 'Failed',
        subtext: 'Deployment failed — check workflow logs',
        active: false,
      );
    }
    if (build.isCancelled) {
      return (
        color: Colors.orange,
        icon: Icons.block,
        text: 'Cancelled',
        subtext: 'Deployment was cancelled',
        active: false,
      );
    }
    return (
      color: Colors.orange,
      icon: Icons.info,
      text: build.conclusion ?? build.status ?? 'Unknown',
      subtext: 'Status: ${build.conclusion ?? build.status}',
      active: false,
    );
  }

  Widget _buildBuildsHistory() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Recent Builds',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_builds.length} builds',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            const Divider(),
            ...List.generate(
              _builds.length,
              (index) => _buildBuildRow(_builds[index], index == 0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuildRow(WorkflowRunResult build, bool isLatest) {
    final isInProgress = build.isInProgress;
    final isSuccess = build.isSuccess;
    final isFailure = build.isFailure;
    final isCancelled = build.isCancelled;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    if (isInProgress) {
      statusColor = Colors.blue;
      statusIcon = build.status == 'queued' ? Icons.hourglass_top : Icons.sync;
      statusLabel = build.status == 'queued' ? 'Queued' : 'Deploying';
    } else if (isSuccess) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusLabel = 'Deployed';
    } else if (isFailure) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusLabel = 'Failed';
    } else if (isCancelled) {
      statusColor = Colors.orange;
      statusIcon = Icons.block;
      statusLabel = 'Cancelled';
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.help;
      statusLabel = build.status ?? 'Unknown';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLatest
            ? statusColor.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLatest
              ? statusColor.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          // Status icon
          isInProgress
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(statusColor),
                  ),
                )
              : Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: 12),
          // Build info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    if (isLatest) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'LATEST',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (build.commitMessage != null &&
                    build.commitMessage!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      build.commitMessage!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (build.commitSha != null) ...[
                      Icon(Icons.commit, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        _shortSha(build.commitSha!),
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: Colors.blue[700],
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (build.durationSecs != null &&
                        build.durationSecs! > 0) ...[
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${build.durationSecs}s',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (build.actorLogin != null) ...[
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        build.actorLogin!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Timestamp
          if (build.createdAt != null)
            Text(
              _formatDateTime(build.createdAt!),
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: valueColor,
                fontFamily: valueColor != null ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteInfo() {
    final site = _siteStatus!;

    if (!site.success) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  site.error ?? 'GitHub Pages info not available',
                  style: TextStyle(color: Colors.orange[800]),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.language, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Site Info',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            if (site.siteUrl != null)
              _buildDetailRow(
                icon: Icons.link,
                label: 'URL',
                value: site.siteUrl!,
                valueColor: Colors.blue,
              ),
            if (site.cname != null)
              _buildDetailRow(
                icon: Icons.dns,
                label: 'Custom Domain',
                value: site.cname!,
              ),
            _buildDetailRow(
              icon: Icons.lock,
              label: 'HTTPS',
              value: site.isHttpsEnforced ? 'Enforced' : 'Not enforced',
              valueColor: site.isHttpsEnforced ? Colors.green : Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final settings = context.read<SettingsProvider>().settings;
    final siteUrl = _siteStatus?.cname != null
        ? 'https://${_siteStatus!.cname}'
        : _siteStatus?.siteUrl;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flash_on, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Quick Actions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.open_in_browser, color: Colors.blue),
              title: const Text('Open Live Website'),
              subtitle: Text(
                siteUrl ?? 'N/A',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: siteUrl != null ? () => _launchUrl(siteUrl) : null,
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.code, color: Colors.grey),
              title: const Text('View Repository'),
              subtitle: Text(
                'github.com/${settings.repositoryOwner}/${settings.repositoryName}',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () => _launchUrl(
                'https://github.com/${settings.repositoryOwner}/${settings.repositoryName}',
              ),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.deepPurple),
              title: const Text('View Actions / Builds'),
              subtitle: const Text(
                'GitHub Pages deployment history',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () => _launchUrl(
                'https://github.com/${settings.repositoryOwner}/${settings.repositoryName}/actions',
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  String _shortSha(String sha) {
    return sha.length > 7 ? sha.substring(0, 7) : sha;
  }

  String _formatDateTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';

      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open $url')));
      }
    }
  }
}
