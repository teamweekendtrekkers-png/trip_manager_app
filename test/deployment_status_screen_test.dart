import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/providers/settings_provider.dart';
import 'package:trip_manager_app/screens/deployment_status_screen.dart';
import 'package:trip_manager_app/services/github_service.dart';
import 'package:trip_manager_app/services/notification_service.dart';

void main() {
  const sha = 'abcdef1234567890';
  final initialNow = DateTime.utc(2026, 8, 13, 10);

  WorkflowRunResult run({
    String status = 'completed',
    String? conclusion = 'success',
  }) => WorkflowRunResult(
    success: true,
    id: 42,
    name: 'Deploy',
    status: status,
    conclusion: conclusion,
    commitSha: sha,
    commitMessage: 'Publish trips',
    createdAt: '2026-08-13T10:00:00Z',
  );

  Widget subject({
    String? savedCommitSha = sha,
    required _FakeGitHubService github,
    required _FakeNotifications notifications,
    required DateTime Function() now,
    Duration pollInterval = const Duration(seconds: 5),
    Duration monitorTimeout = const Duration(minutes: 10),
  }) => ChangeNotifierProvider<SettingsProvider>.value(
    value: SettingsProvider(),
    child: MaterialApp(
      home: DeploymentStatusScreen(
        savedCommitSha: savedCommitSha,
        githubService: github,
        notificationClient: notifications,
        now: now,
        pollInterval: pollInterval,
        monitorTimeout: monitorTimeout,
      ),
    ),
  );

  testWidgets('polls the exact commit and notifies once at completion', (
    tester,
  ) async {
    var now = initialNow;
    final github = _FakeGitHubService(<WorkflowRunsQueryResult>[
      const WorkflowRunsQueryResult(success: true),
      WorkflowRunsQueryResult(
        success: true,
        runs: <WorkflowRunResult>[run(status: 'queued', conclusion: null)],
      ),
      WorkflowRunsQueryResult(success: true, runs: <WorkflowRunResult>[run()]),
    ]);
    final notifications = _FakeNotifications();

    await tester.pumpWidget(
      subject(github: github, notifications: notifications, now: () => now),
    );
    await tester.pump();

    expect(github.queriedShas, <String>[sha]);
    expect(notifications.permissionRequests, 1);
    expect(find.text('Waiting for workflow'), findsOneWidget);

    now = initialNow.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(github.queriedShas, <String>[sha, sha]);
    expect(find.text('Queued'), findsWidgets);

    now = initialNow.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(github.queriedShas, <String>[sha, sha, sha]);
    expect(find.text('Deployed'), findsWidgets);
    expect(notifications.shown, 1);
    expect(notifications.lastSuccess, isTrue);
    expect(notifications.lastCommitMessage, 'Publish trips');

    now = initialNow.add(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 50));
    expect(github.queriedShas, hasLength(3));
    expect(notifications.shown, 1);
  });

  testWidgets('stops at the monitor timeout without another API request', (
    tester,
  ) async {
    var now = initialNow;
    final github = _FakeGitHubService(<WorkflowRunsQueryResult>[
      const WorkflowRunsQueryResult(success: true),
    ]);
    final notifications = _FakeNotifications();

    await tester.pumpWidget(
      subject(
        github: github,
        notifications: notifications,
        now: () => now,
        monitorTimeout: const Duration(seconds: 10),
      ),
    );
    await tester.pump();

    now = initialNow.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(github.queriedShas, hasLength(2));

    now = initialNow.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(find.text('Monitoring timed out'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('deployment-phase-timeout')),
      findsOneWidget,
    );
    expect(github.queriedShas, hasLength(2));
    expect(notifications.shown, 0);

    await tester.pump(const Duration(minutes: 1));
    expect(github.queriedShas, hasLength(2));
  });

  testWidgets('surfaces a 403 as an Actions permission problem', (
    tester,
  ) async {
    final github = _FakeGitHubService(<WorkflowRunsQueryResult>[
      const WorkflowRunsQueryResult(
        success: false,
        permissionDenied: true,
        statusCode: 403,
        error: 'Grant Actions read permission.',
      ),
    ]);
    final notifications = _FakeNotifications();

    await tester.pumpWidget(
      subject(
        github: github,
        notifications: notifications,
        now: () => initialNow,
      ),
    );
    await tester.pump();

    expect(find.text('Actions permission required'), findsOneWidget);
    expect(find.text('Grant Actions read permission.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('deployment-phase-permission_denied')),
      findsOneWidget,
    );
    expect(notifications.shown, 0);
  });

  testWidgets('pauses polling while the app is not visible and resumes', (
    tester,
  ) async {
    var now = initialNow;
    final github = _FakeGitHubService(<WorkflowRunsQueryResult>[
      const WorkflowRunsQueryResult(success: true),
      WorkflowRunsQueryResult(
        success: true,
        runs: <WorkflowRunResult>[run(status: 'queued', conclusion: null)],
      ),
    ]);
    final notifications = _FakeNotifications();

    await tester.pumpWidget(
      subject(
        github: github,
        notifications: notifications,
        now: () => now,
        monitorTimeout: const Duration(hours: 1),
      ),
    );
    await tester.pump();
    expect(github.queriedShas, hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = initialNow.add(const Duration(minutes: 5));
    await tester.pump(const Duration(minutes: 5));
    expect(github.queriedShas, hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(github.queriedShas, hasLength(2));
    expect(find.text('Queued'), findsWidgets);
  });

  testWidgets(
    'pauses while covered by another route and resumes when visible',
    (tester) async {
      var now = initialNow;
      final github = _FakeGitHubService(<WorkflowRunsQueryResult>[
        const WorkflowRunsQueryResult(success: true),
        WorkflowRunsQueryResult(
          success: true,
          runs: <WorkflowRunResult>[run(status: 'queued', conclusion: null)],
        ),
      ]);
      final notifications = _FakeNotifications();

      await tester.pumpWidget(
        subject(
          github: github,
          notifications: notifications,
          now: () => now,
          monitorTimeout: const Duration(hours: 1),
        ),
      );
      await tester.pump();
      expect(github.queriedShas, hasLength(1));

      final screenContext = tester.element(find.byType(DeploymentStatusScreen));
      unawaited(
        Navigator.of(screenContext).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Covering route')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      now = initialNow.add(const Duration(minutes: 5));
      await tester.pump(const Duration(minutes: 5));
      expect(github.queriedShas, hasLength(1));

      Navigator.of(tester.element(find.text('Covering route'))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(github.queriedShas, hasLength(2));
      expect(find.text('Queued'), findsWidgets);
    },
  );

  testWidgets('generic Settings launch does not start commit monitoring', (
    tester,
  ) async {
    final github = _FakeGitHubService(
      const <WorkflowRunsQueryResult>[],
      recent: <WorkflowRunResult>[run()],
    );
    final notifications = _FakeNotifications();

    await tester.pumpWidget(
      subject(
        savedCommitSha: null,
        github: github,
        notifications: notifications,
        now: () => initialNow,
      ),
    );
    await tester.pump();

    expect(find.text('Deployment Status'), findsOneWidget);
    expect(find.text('Recent Builds'), findsOneWidget);
    expect(find.text('Deployed'), findsWidgets);
    expect(github.queriedShas, isEmpty);
    expect(notifications.permissionRequests, 0);
    expect(notifications.shown, 0);
  });
}

final class _FakeGitHubService extends GitHubService {
  _FakeGitHubService(
    this.responses, {
    this.recent = const <WorkflowRunResult>[],
  }) : super(settings: AppSettings());

  final List<WorkflowRunsQueryResult> responses;
  final List<WorkflowRunResult> recent;
  final List<String> queriedShas = <String>[];
  int _responseIndex = 0;

  @override
  Future<DeploymentStatusResult> getDeploymentStatus() async =>
      DeploymentStatusResult(
        success: true,
        siteUrl: 'https://example.test',
        status: 'built',
        isHttpsEnforced: true,
      );

  @override
  Future<List<WorkflowRunResult>> getRecentDeployments({
    int limit = 10,
  }) async => recent;

  @override
  Future<WorkflowRunsQueryResult> getWorkflowRunsForCommit(
    String headSha, {
    int limit = 10,
  }) async {
    queriedShas.add(headSha);
    if (responses.isEmpty) {
      return const WorkflowRunsQueryResult(success: true);
    }
    final index = _responseIndex < responses.length
        ? _responseIndex
        : responses.length - 1;
    _responseIndex += 1;
    return responses[index];
  }
}

final class _FakeNotifications implements DeploymentNotificationClient {
  int permissionRequests = 0;
  int shown = 0;
  bool? lastSuccess;
  String? lastCommitMessage;

  @override
  Future<bool> requestPermission() async {
    permissionRequests += 1;
    return true;
  }

  @override
  Future<void> showDeploymentNotification({
    required bool success,
    String? commitMessage,
  }) async {
    shown += 1;
    lastSuccess = success;
    lastCommitMessage = commitMessage;
  }
}
