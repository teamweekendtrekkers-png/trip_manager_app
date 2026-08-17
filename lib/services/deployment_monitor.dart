import 'github_service.dart';

/// Every state shown while tracking the workflow for one saved commit.
enum DeploymentPhase {
  waiting('waiting'),
  queued('queued'),
  running('running'),
  success('success'),
  failure('failure'),
  cancelled('cancelled'),
  timedOut('timed_out'),
  actionRequired('action_required'),
  stale('stale'),
  skipped('skipped'),
  neutral('neutral'),
  monitorTimeout('timeout'),
  permissionDenied('permission_denied'),
  apiError('api_error');

  const DeploymentPhase(this.value);

  final String value;
}

/// Immutable result of evaluating one GitHub Actions poll.
final class DeploymentMonitorState {
  const DeploymentMonitorState({required this.phase, this.run, this.detail});

  final DeploymentPhase phase;
  final WorkflowRunResult? run;
  final String? detail;

  bool get shouldPoll =>
      phase == DeploymentPhase.waiting ||
      phase == DeploymentPhase.queued ||
      phase == DeploymentPhase.running;

  bool get isWorkflowTerminal =>
      run != null &&
      (phase == DeploymentPhase.success ||
          phase == DeploymentPhase.failure ||
          phase == DeploymentPhase.cancelled ||
          phase == DeploymentPhase.timedOut ||
          phase == DeploymentPhase.actionRequired ||
          phase == DeploymentPhase.stale ||
          phase == DeploymentPhase.skipped ||
          phase == DeploymentPhase.neutral);

  bool get isSuccess => phase == DeploymentPhase.success;
}

/// Pure mapping from GitHub's wire statuses to app monitoring states.
abstract final class DeploymentStatusMapper {
  static DeploymentMonitorState evaluate({
    required WorkflowRunsQueryResult query,
    required String commitSha,
    required DateTime monitorStartedAt,
    required DateTime now,
    Duration timeout = const Duration(minutes: 10),
  }) {
    if (!now.isBefore(monitorStartedAt.add(timeout))) {
      return const DeploymentMonitorState(
        phase: DeploymentPhase.monitorTimeout,
        detail: 'No completed workflow was found within 10 minutes.',
      );
    }

    if (!query.success) {
      if (query.permissionDenied) {
        return DeploymentMonitorState(
          phase: DeploymentPhase.permissionDenied,
          detail:
              query.error ??
              'GitHub denied access to Actions. Grant Actions read permission.',
        );
      }
      return DeploymentMonitorState(
        phase: DeploymentPhase.apiError,
        detail: query.error ?? 'Could not check the GitHub Actions workflow.',
      );
    }

    final normalizedSha = commitSha.trim().toLowerCase();
    WorkflowRunResult? run;
    for (final candidate in query.runs) {
      if (candidate.commitSha?.toLowerCase() == normalizedSha) {
        run = candidate;
        break;
      }
    }

    if (run == null) {
      return const DeploymentMonitorState(
        phase: DeploymentPhase.waiting,
        detail: 'Waiting for GitHub Actions to create a workflow run.',
      );
    }

    switch (run.status) {
      case 'queued':
        return DeploymentMonitorState(phase: DeploymentPhase.queued, run: run);
      case 'in_progress':
        return DeploymentMonitorState(phase: DeploymentPhase.running, run: run);
      case 'waiting':
      case 'requested':
      case 'pending':
        return DeploymentMonitorState(phase: DeploymentPhase.waiting, run: run);
      case 'completed':
        return _completedState(run);
      default:
        return DeploymentMonitorState(
          phase: DeploymentPhase.apiError,
          run: run,
          detail: 'GitHub returned an unknown workflow status: ${run.status}.',
        );
    }
  }

  static DeploymentMonitorState _completedState(WorkflowRunResult run) {
    final phase = switch (run.conclusion) {
      'success' => DeploymentPhase.success,
      'failure' || 'startup_failure' => DeploymentPhase.failure,
      'cancelled' => DeploymentPhase.cancelled,
      'timed_out' => DeploymentPhase.timedOut,
      'action_required' => DeploymentPhase.actionRequired,
      'stale' => DeploymentPhase.stale,
      'skipped' => DeploymentPhase.skipped,
      'neutral' => DeploymentPhase.neutral,
      _ => DeploymentPhase.apiError,
    };
    return DeploymentMonitorState(
      phase: phase,
      run: run,
      detail: phase == DeploymentPhase.apiError
          ? 'The workflow completed without a recognized conclusion.'
          : null,
    );
  }
}

/// One monitoring session may produce at most one completion notification.
final class DeploymentNotificationGate {
  bool _didNotify = false;

  bool get didNotify => _didNotify;

  bool shouldNotify(DeploymentMonitorState state) {
    if (_didNotify || !state.isWorkflowTerminal) return false;
    _didNotify = true;
    return true;
  }
}
