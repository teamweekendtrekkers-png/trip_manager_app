import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/services/deployment_monitor.dart';
import 'package:trip_manager_app/services/github_service.dart';

void main() {
  const commitSha = 'abcdef1234567890';
  final startedAt = DateTime.utc(2026, 8, 13, 10);

  WorkflowRunResult run({
    String status = 'completed',
    String? conclusion = 'success',
    String sha = commitSha,
    int id = 42,
  }) => WorkflowRunResult(
    success: true,
    id: id,
    status: status,
    conclusion: conclusion,
    commitSha: sha,
    commitMessage: 'Publish trips',
  );

  DeploymentMonitorState evaluate(
    WorkflowRunsQueryResult query, {
    DateTime? now,
  }) => DeploymentStatusMapper.evaluate(
    query: query,
    commitSha: commitSha,
    monitorStartedAt: startedAt,
    now: now ?? startedAt.add(const Duration(minutes: 1)),
  );

  group('DeploymentStatusMapper', () {
    test('waits until an exact-SHA workflow appears', () {
      expect(
        evaluate(const WorkflowRunsQueryResult(success: true)).phase,
        DeploymentPhase.waiting,
      );
      expect(
        evaluate(
          WorkflowRunsQueryResult(
            success: true,
            runs: <WorkflowRunResult>[run(sha: 'different-sha')],
          ),
        ).phase,
        DeploymentPhase.waiting,
      );
    });

    test('maps queued, waiting, and in-progress workflow statuses', () {
      for (final entry in <(String, DeploymentPhase)>[
        ('requested', DeploymentPhase.waiting),
        ('waiting', DeploymentPhase.waiting),
        ('pending', DeploymentPhase.waiting),
        ('queued', DeploymentPhase.queued),
        ('in_progress', DeploymentPhase.running),
      ]) {
        final state = evaluate(
          WorkflowRunsQueryResult(
            success: true,
            runs: <WorkflowRunResult>[run(status: entry.$1, conclusion: null)],
          ),
        );

        expect(state.phase, entry.$2, reason: entry.$1);
        expect(state.shouldPoll, isTrue, reason: entry.$1);
        expect(state.isWorkflowTerminal, isFalse, reason: entry.$1);
      }
    });

    test('maps every terminal GitHub conclusion', () {
      for (final entry in <(String, DeploymentPhase)>[
        ('success', DeploymentPhase.success),
        ('failure', DeploymentPhase.failure),
        ('startup_failure', DeploymentPhase.failure),
        ('cancelled', DeploymentPhase.cancelled),
        ('timed_out', DeploymentPhase.timedOut),
        ('action_required', DeploymentPhase.actionRequired),
        ('stale', DeploymentPhase.stale),
        ('skipped', DeploymentPhase.skipped),
        ('neutral', DeploymentPhase.neutral),
      ]) {
        final state = evaluate(
          WorkflowRunsQueryResult(
            success: true,
            runs: <WorkflowRunResult>[run(conclusion: entry.$1)],
          ),
        );

        expect(state.phase, entry.$2, reason: entry.$1);
        expect(state.shouldPoll, isFalse, reason: entry.$1);
        expect(state.isWorkflowTerminal, isTrue, reason: entry.$1);
      }
    });

    test('distinguishes permission and general API errors', () {
      final permission = evaluate(
        const WorkflowRunsQueryResult(
          success: false,
          permissionDenied: true,
          statusCode: 403,
          error: 'forbidden',
        ),
      );
      final apiError = evaluate(
        const WorkflowRunsQueryResult(
          success: false,
          statusCode: 500,
          error: 'server error',
        ),
      );

      expect(permission.phase, DeploymentPhase.permissionDenied);
      expect(permission.detail, 'forbidden');
      expect(apiError.phase, DeploymentPhase.apiError);
      expect(apiError.detail, 'server error');
    });

    test('ends monitoring at the ten-minute boundary', () {
      final state = evaluate(
        WorkflowRunsQueryResult(
          success: true,
          runs: <WorkflowRunResult>[
            run(status: 'in_progress', conclusion: null),
          ],
        ),
        now: startedAt.add(const Duration(minutes: 10)),
      );

      expect(state.phase, DeploymentPhase.monitorTimeout);
      expect(state.shouldPoll, isFalse);
      expect(state.isWorkflowTerminal, isFalse);
    });

    test('reports unknown wire states as API errors', () {
      final unknownStatus = evaluate(
        WorkflowRunsQueryResult(
          success: true,
          runs: <WorkflowRunResult>[
            run(status: 'surprising', conclusion: null),
          ],
        ),
      );
      final unknownConclusion = evaluate(
        WorkflowRunsQueryResult(
          success: true,
          runs: <WorkflowRunResult>[run(conclusion: 'surprising')],
        ),
      );

      expect(unknownStatus.phase, DeploymentPhase.apiError);
      expect(unknownConclusion.phase, DeploymentPhase.apiError);
    });
  });

  test(
    'DeploymentNotificationGate allows exactly one terminal notification',
    () {
      final gate = DeploymentNotificationGate();
      final running = evaluate(
        WorkflowRunsQueryResult(
          success: true,
          runs: <WorkflowRunResult>[
            run(status: 'in_progress', conclusion: null),
          ],
        ),
      );
      final completed = evaluate(
        WorkflowRunsQueryResult(
          success: true,
          runs: <WorkflowRunResult>[run()],
        ),
      );

      expect(gate.shouldNotify(running), isFalse);
      expect(gate.shouldNotify(completed), isTrue);
      expect(gate.shouldNotify(completed), isFalse);
      expect(
        gate.shouldNotify(
          DeploymentMonitorState(
            phase: DeploymentPhase.failure,
            run: run(id: 99, conclusion: 'failure'),
          ),
        ),
        isFalse,
      );
      expect(gate.didNotify, isTrue);
    },
  );

  group('GitHubService.getWorkflowRunsForCommit', () {
    test('queries Actions by head_sha and maps the returned run', () async {
      late RequestOptions captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.github.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'workflow_runs': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 42,
                      'name': 'Deploy',
                      'status': 'completed',
                      'conclusion': 'success',
                      'head_sha': commitSha,
                      'display_title': 'Publish trips',
                      'head_branch': 'main',
                      'event': 'push',
                      'created_at': '2026-08-13T10:00:00Z',
                      'updated_at': '2026-08-13T10:02:05Z',
                      'html_url': 'https://github.test/run/42',
                      'run_number': 7,
                      'actor': <String, dynamic>{
                        'login': 'weekend-trekker',
                        'avatar_url': 'https://github.test/avatar.png',
                      },
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
      final service = GitHubService(
        settings: AppSettings(repositoryOwner: 'owner', repositoryName: 'repo'),
        dio: dio,
      );

      final result = await service.getWorkflowRunsForCommit(
        '  $commitSha  ',
        limit: 4,
      );

      expect(result.success, isTrue);
      expect(captured.path, '/repos/owner/repo/actions/runs');
      expect(captured.queryParameters, <String, dynamic>{
        'head_sha': commitSha,
        'per_page': 4,
      });
      expect(result.runs, hasLength(1));
      expect(result.runs.single.id, 42);
      expect(result.runs.single.commitSha, commitSha);
      expect(result.runs.single.durationSecs, 125);
      expect(result.runs.single.actorLogin, 'weekend-trekker');
    });

    test('retains a 403 as an Actions permission error', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.github.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 403,
                  data: const <String, dynamic>{
                    'message': 'Resource not accessible by token',
                  },
                ),
              ),
            );
          },
        ),
      );
      final service = GitHubService(settings: AppSettings(), dio: dio);

      final result = await service.getWorkflowRunsForCommit(commitSha);

      expect(result.success, isFalse);
      expect(result.permissionDenied, isTrue);
      expect(result.statusCode, 403);
      expect(result.error, contains('Actions read permission'));
    });

    test(
      'retains API errors and rejects an empty SHA without a request',
      () async {
        var requests = 0;
        final dio = Dio(BaseOptions(baseUrl: 'https://api.github.test'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests += 1;
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 500,
                    data: const <String, dynamic>{'message': 'Server exploded'},
                  ),
                ),
              );
            },
          ),
        );
        final service = GitHubService(settings: AppSettings(), dio: dio);

        final empty = await service.getWorkflowRunsForCommit('   ');
        final failed = await service.getWorkflowRunsForCommit(commitSha);

        expect(empty.success, isFalse);
        expect(empty.error, contains('commit SHA'));
        expect(requests, 1);
        expect(failed.success, isFalse);
        expect(failed.permissionDenied, isFalse);
        expect(failed.statusCode, 500);
        expect(failed.error, 'Server exploded');
      },
    );
  });
}
