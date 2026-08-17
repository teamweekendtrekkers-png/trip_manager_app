import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:trip_manager_app/main.dart' show TripManagerApp;
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/providers/settings_provider.dart';
import 'package:trip_manager_app/providers/trips_provider.dart';
import 'package:trip_manager_app/screens/deployment_status_screen.dart';
import 'package:trip_manager_app/screens/trips_list_screen.dart';
import 'package:trip_manager_app/services/github_service.dart';
import 'package:trip_manager_app/services/notification_service.dart';
import 'package:trip_manager_app/services/trips_parser.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerAdminFlowTests();
}

/// Registers the same deterministic scenarios for Android integration runs
/// and the host-side regression wrapper in `test/`.
void registerAdminFlowTests() {
  testWidgets(
    'Android reopens disk settings and renders the real app root in dark mode',
    (tester) async {
      if (!Platform.isAndroid) return;

      final firstLaunch = SettingsProvider();
      await firstLaunch.init();
      await firstLaunch.clearSettings();
      await firstLaunch.saveSettings(
        AppSettings(
          githubToken: 'disk-restored-token',
          repositoryOwner: 'disk-owner',
          repositoryName: 'disk-repository',
          branch: 'release',
          tripsDataPath: 'data/trips-data.js',
          whatsappNumber: '918888888888',
          upiId: 'disk@bank',
          darkMode: true,
        ),
      );
      firstLaunch.dispose();
      await Hive.close();

      // Closing Hive and constructing fresh providers exercises the same
      // persisted JSON path used after the installed app process is relaunched.
      final restored = SettingsProvider();
      await restored.init();
      addTearDown(() async {
        await restored.clearSettings();
        restored.dispose();
        await Hive.close();
      });
      expect(restored.settings.githubToken, 'disk-restored-token');
      expect(restored.settings.repositoryOwner, 'disk-owner');
      expect(restored.settings.repositoryName, 'disk-repository');
      expect(restored.settings.branch, 'release');
      expect(restored.settings.tripsDataPath, 'data/trips-data.js');
      expect(restored.settings.whatsappNumber, '918888888888');
      expect(restored.settings.upiId, 'disk@bank');
      expect(restored.settings.darkMode, isTrue);

      final service = _MemoryGitHubService(
        trips: <Map<String, dynamic>>[
          _trip(id: 'disk-trip', title: 'Disk Restored Trip'),
        ],
      );
      final trips = TripsProvider(
        restored.settings,
        serviceFactory: (_) => service,
      );
      await tester.pumpWidget(_buildListApp(trips: trips, settings: restored));
      await tester.pumpAndSettle();

      expect(find.text('Disk Restored Trip'), findsOneWidget);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      final listContext = tester.element(find.byType(TripsListScreen));
      expect(Theme.of(listContext).brightness, Brightness.dark);
    },
  );

  testWidgets(
    'cold provider launch restores settings and refresh merges remote edits',
    (tester) async {
      final store = _MemorySettingsStore();
      final firstLaunch = SettingsProvider(store: store);
      await firstLaunch.init();
      await firstLaunch.saveSettings(
        AppSettings(
          githubToken: 'restored-token',
          repositoryOwner: 'restored-owner',
          repositoryName: 'restored-repository',
          branch: 'release',
          tripsDataPath: 'data/trips-data.js',
          whatsappNumber: '919999999999',
          upiId: 'restored@bank',
          darkMode: true,
        ),
      );
      firstLaunch.dispose();

      // Reconstruct both providers from persisted bytes, as a cold app launch
      // does, instead of retaining any in-memory SettingsProvider state.
      final restored = SettingsProvider(store: store);
      await restored.init();
      expect(restored.settings.githubToken, 'restored-token');
      expect(restored.settings.repositoryOwner, 'restored-owner');
      expect(restored.settings.repositoryName, 'restored-repository');
      expect(restored.settings.branch, 'release');
      expect(restored.settings.tripsDataPath, 'data/trips-data.js');
      expect(restored.settings.whatsappNumber, '919999999999');
      expect(restored.settings.upiId, 'restored@bank');
      expect(restored.settings.darkMode, isTrue);

      final service = _MemoryGitHubService(
        trips: <Map<String, dynamic>>[
          _trip(id: 'alpha', title: 'Original Alpha'),
        ],
      );
      final trips = TripsProvider(
        restored.settings,
        serviceFactory: (_) => service,
      );
      await tester.pumpWidget(_buildListApp(trips: trips, settings: restored));
      await tester.pumpAndSettle();
      expect(find.text('Original Alpha'), findsOneWidget);

      trips.updateTrip(0, <String, dynamic>{
        ...trips.trips.single,
        'title': 'Local Alpha',
        'name': 'Local Alpha',
      });
      service.replaceRemoteTrips(<Map<String, dynamic>>[
        <String, dynamic>{
          ..._trip(id: 'alpha', title: 'Original Alpha'),
          'price': '₹2,499',
        },
      ]);
      await tester.pump();

      await tester.tap(find.byTooltip('Refresh (Pull)'));
      await tester.pumpAndSettle();
      expect(find.text('Refresh and Merge?'), findsOneWidget);
      await tester.tap(find.text('Refresh & Merge'));
      await tester.pumpAndSettle();

      expect(trips.trips.single['title'], 'Local Alpha');
      expect(trips.trips.single['price'], '₹2,499');
      expect(trips.hasUnsavedChanges, isTrue);
      expect(service.atomicCommitCalls, 0);
    },
  );

  testWidgets(
    'load, edit dates, preview, toggle, reorder, delete, and publish in memory',
    (tester) async {
      final service = _MemoryGitHubService(
        trips: <Map<String, dynamic>>[
          _trip(id: 'alpha', title: 'Alpha Trek'),
          _trip(
            id: 'beta',
            title: 'Beta Trek',
            dates: <String>['Jan 1-2, 2099'],
          ),
          _trip(id: 'resting', title: 'Resting Trek', isActive: false),
        ],
      );
      final providers = await _providersFor(service);

      await tester.pumpWidget(
        _buildListApp(trips: providers.trips, settings: providers.settings),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alpha Trek'), findsOneWidget);
      expect(find.text('Beta Trek'), findsOneWidget);
      expect(find.text('INACTIVE'), findsOneWidget);

      // Search selects Beta from a filtered sublist, then opens the real editor.
      await tester.enterText(find.byType(TextField).first, 'Beta');
      await tester.pump();
      expect(find.text('Alpha Trek'), findsNothing);
      await tester.tap(find.text('Beta Trek'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Trip'), findsOneWidget);

      // Exercise the production calendar editor: replace the legacy value
      // with a newly selected range before saving the trip.
      final removeLegacyDate = find.byKey(
        const ValueKey<String>('remove-date-0'),
      );
      await tester.ensureVisible(removeLegacyDate);
      await tester.tap(removeLegacyDate);
      await tester.pump();
      final addDate = find.byKey(const Key('add-date-range'));
      await tester.ensureVisible(addDate);
      await tester.tap(addDate);
      await tester.pumpAndSettle();
      expect(find.text('Add trip dates'), findsOneWidget);
      final augustFourteenth = find.bySemanticsLabel(
        RegExp(r'August 14, 2026'),
      );
      final augustSixteenth = find.bySemanticsLabel(RegExp(r'August 16, 2026'));
      expect(augustFourteenth, findsOneWidget);
      expect(augustSixteenth, findsOneWidget);
      await tester.tap(augustFourteenth);
      await tester.pump();
      await tester.tap(augustSixteenth);
      await tester.pump();
      final calendarSave = find.widgetWithText(TextButton, 'Save');
      expect(tester.widget<TextButton>(calendarSave).onPressed, isNotNull);
      await tester.tap(calendarSave);
      await tester.pumpAndSettle();
      expect(find.text('Add trip dates'), findsNothing);
      expect(find.text('Aug 14-16, 2026'), findsOneWidget);

      // Toggle active status in the real editor, then restore it so the later
      // same-tier reorder remains part of this end-to-end scenario.
      await tester.scrollUntilVisible(
        find.text('Active Trip'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Active Trip'));
      await tester.pump();
      expect(
        find.text('Trip is greyed out and hidden from bookings'),
        findsOneWidget,
      );
      await tester.tap(find.text('Active Trip'));
      await tester.pump();
      expect(
        find.text('Trip is visible and available for booking'),
        findsOneWidget,
      );

      // Remove its date and save; an empty list is a supported edit.
      final removeDate = find.byKey(const ValueKey<String>('remove-date-0'));
      await tester.ensureVisible(removeDate);
      await tester.tap(removeDate);
      await tester.pump();
      expect(find.textContaining('New dates coming soon'), findsOneWidget);
      await tester.tap(_appBarSaveButton());
      await tester.pumpAndSettle();
      expect(providers.trips.getTripById('beta')!['availableDates'], isEmpty);

      // Clear search and exercise the actual list reorder callback within the
      // active, non-featured tier.
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();
      final reorderable = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      reorderable.onReorder(0, 2);
      await tester.pump();
      expect(providers.trips.trips.map((trip) => trip['id']).toList(), <String>[
        'beta',
        'alpha',
        'resting',
      ]);

      // Toggle featured while filtered. The action must resolve Beta's real ID.
      await tester.enterText(find.byType(TextField).first, 'Beta');
      await tester.pump();
      await _chooseTripMenuAction(tester, 'beta', 'Mark Featured');
      expect(providers.trips.getTripById('beta')!['featured'], isTrue);
      expect(providers.trips.getTripById('alpha')!['featured'], isFalse);

      await tester.tap(find.byTooltip('Show featured only'));
      await tester.pump();
      expect(find.text('Beta Trek'), findsOneWidget);
      expect(find.text('Alpha Trek'), findsNothing);

      // Delete Alpha from a different filtered view and retain Beta.
      await tester.tap(find.byTooltip('Show featured only'));
      await tester.enterText(find.byType(TextField).first, 'Alpha');
      await tester.pump();
      await _chooseTripMenuAction(tester, 'alpha', 'Delete');
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(providers.trips.getTripById('alpha'), isNull);
      expect(providers.trips.getTripById('beta'), isNotNull);

      // Preview the exact unsaved snapshot. Beta has no dates and Resting is
      // inactive, so the website-compatible result is empty.
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();
      await tester.tap(find.byTooltip('Preview Upcoming Batches'));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved data preview'), findsOneWidget);
      expect(find.text('New dates coming soon'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Publish through the real dialog. The fake records the same two-file
      // atomic commit call production makes, but performs no external request.
      await tester.tap(find.byIcon(Icons.cloud_upload));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Push'));
      // A full pumpAndSettle advances through the five-second snackbar and
      // removes the success evidence before the assertion can observe it.
      await tester.pump();
      for (var frame = 0; frame < 50; frame++) {
        if (find.text('Changes pushed successfully!').evaluate().isNotEmpty) {
          break;
        }
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(service.atomicCommitCalls, 1);
      expect(service.lastCommittedPaths, <String>{
        'js/trips-data.js',
        'js/featured-trips.js',
      });
      expect(providers.trips.hasUnsavedChanges, isFalse);
      expect(
        TripsParser.parseTripsData(
          service.tripsSource,
        ).map((trip) => trip['id']).toSet(),
        <String>{'beta', 'resting'},
      );
    },
  );

  testWidgets('true conflict uses the real double-confirm overwrite flow', (
    tester,
  ) async {
    final service = _MemoryGitHubService(
      trips: <Map<String, dynamic>>[_trip(id: 'alpha', title: 'Alpha Trek')],
    );
    final providers = await _providersFor(service);
    await tester.pumpWidget(
      _buildListApp(trips: providers.trips, settings: providers.settings),
    );
    await tester.pumpAndSettle();

    final local = Map<String, dynamic>.from(providers.trips.trips.single)
      ..['title'] = 'Local Alpha Trek'
      ..['name'] = 'Local Alpha Trek';
    providers.trips.updateTrip(0, local);
    service.replaceRemoteTrips(<Map<String, dynamic>>[
      _trip(id: 'alpha', title: 'Remote Alpha Trek'),
    ]);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.cloud_upload));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();

    expect(find.text('Conflict Detected'), findsWidgets);
    expect(find.textContaining('Merge conflicts'), findsOneWidget);
    expect(service.atomicCommitCalls, 0);

    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();
    expect(find.text('Overwrite Remote Trip Data?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Final Confirmation'), findsOneWidget);
    await tester.tap(find.text('Create Overwrite Commit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Overwrite commit created successfully!'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('view-deployment-commit-2')),
      findsOneWidget,
    );
    expect(service.atomicCommitCalls, 1);
    expect(
      TripsParser.parseTripsData(service.tripsSource).single['title'],
      'Local Alpha Trek',
    );
    expect(providers.trips.hasConflict, isFalse);
  });

  testWidgets(
    'exact-SHA deployment requests permission lazily and notifies once',
    (tester) async {
      const commitSha = 'abcdef1234567890';
      final service = _MemoryGitHubService(
        trips: const <Map<String, dynamic>>[],
        workflowRuns: <WorkflowRunResult>[
          WorkflowRunResult(
            success: true,
            id: 42,
            status: 'completed',
            conclusion: 'success',
            commitSha: commitSha,
            commitMessage: 'Publish in-memory trips',
          ),
        ],
      );
      final notifications = _RecordingNotifications();
      final settings = await _configuredSettings();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: MaterialApp(
            home: DeploymentStatusScreen(
              savedCommitSha: commitSha,
              githubService: service,
              notificationClient: notifications,
              pollInterval: const Duration(milliseconds: 10),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('deployment-phase-success')),
        findsOneWidget,
      );
      expect(find.text('Deployed'), findsWidgets);
      expect(service.workflowQueryShas, <String>[commitSha]);
      expect(notifications.permissionRequests, 1);
      expect(notifications.notifications, 1);
      expect(notifications.lastSuccess, isTrue);

      await tester.pump(const Duration(milliseconds: 50));
      expect(notifications.notifications, 1);
    },
  );
}

Map<String, dynamic> _trip({
  required String id,
  required String title,
  bool featured = false,
  bool isActive = true,
  List<String> dates = const <String>[],
}) => <String, dynamic>{
  'id': id,
  'title': title,
  'name': title,
  'location': '$title location',
  'destination': '$title location',
  'about': '$title description',
  'description': '$title description',
  'price': '₹999',
  'image': '',
  'featured': featured,
  'isActive': isActive,
  'availableDates': dates,
  'highlights': <String>['View'],
  'itinerary': <Map<String, dynamic>>[],
  'inclusions': <String>[],
  'exclusions': <String>[],
  'thingsToCarry': <String>[],
  'galleryImages': <String>[],
  'boardingLocations': <Map<String, dynamic>>[],
};

Finder _appBarSaveButton() =>
    find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.save));

Future<void> _chooseTripMenuAction(
  WidgetTester tester,
  String id,
  String action,
) async {
  final menu = find.descendant(
    of: find.byKey(ValueKey<dynamic>(id)),
    matching: find.byType(PopupMenuButton<String>),
  );
  await tester.tap(menu);
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

Future<({TripsProvider trips, SettingsProvider settings})> _providersFor(
  _MemoryGitHubService service,
) async {
  final settings = await _configuredSettings();
  final trips = TripsProvider(
    settings.settings,
    serviceFactory: (_) => service,
  );
  return (trips: trips, settings: settings);
}

Future<SettingsProvider> _configuredSettings() async {
  final settings = SettingsProvider(store: _MemorySettingsStore());
  await settings.init();
  await settings.saveSettings(AppSettings(githubToken: 'integration-token'));
  return settings;
}

Widget _buildListApp({
  required TripsProvider trips,
  required SettingsProvider settings,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<TripsProvider>.value(value: trips),
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
    ],
    child: const TripManagerApp(),
  );
}

final class _MemoryGitHubService extends GitHubService {
  _MemoryGitHubService({
    required List<Map<String, dynamic>> trips,
    this.workflowRuns = const <WorkflowRunResult>[],
  }) : tripsSource = TripsParser.generateTripsDataJs(trips),
       featuredSource = TripsParser.generateFeaturedTripsJs(trips),
       super(settings: AppSettings());

  String tripsSource;
  String featuredSource;
  String tripsSha = 'trips-sha-1';
  String featuredSha = 'featured-sha-1';
  int atomicCommitCalls = 0;
  Set<String> lastCommittedPaths = const <String>{};
  final List<WorkflowRunResult> workflowRuns;
  final List<String> workflowQueryShas = <String>[];

  void replaceRemoteTrips(List<Map<String, dynamic>> trips) {
    tripsSource = TripsParser.generateTripsDataJs(trips);
    featuredSource = TripsParser.generateFeaturedTripsJs(trips);
    tripsSha = 'trips-sha-remote';
    featuredSha = 'featured-sha-remote';
  }

  @override
  Future<GitHubFileResult> fetchTripsData() async =>
      GitHubFileResult(content: tripsSource, sha: tripsSha, success: true);

  @override
  Future<GitHubFileResult> fetchFile(String filePath) async => GitHubFileResult(
    content: featuredSource,
    sha: featuredSha,
    success: true,
  );

  @override
  Future<GitHubCommitResult> commitFilesAtomically({
    required Map<String, String> files,
    required Map<String, String?> expectedBlobShas,
    required String commitMessage,
  }) async {
    atomicCommitCalls += 1;
    lastCommittedPaths = files.keys.toSet();
    tripsSource = files['js/trips-data.js']!;
    featuredSource = files['js/featured-trips.js']!;
    tripsSha = 'trips-sha-${atomicCommitCalls + 1}';
    featuredSha = 'featured-sha-${atomicCommitCalls + 1}';
    return GitHubCommitResult(
      success: true,
      commitSha: 'commit-${atomicCommitCalls + 1}',
      fileBlobShas: <String, String>{
        'js/trips-data.js': tripsSha,
        'js/featured-trips.js': featuredSha,
      },
    );
  }

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
  }) async => workflowRuns;

  @override
  Future<WorkflowRunsQueryResult> getWorkflowRunsForCommit(
    String headSha, {
    int limit = 10,
  }) async {
    workflowQueryShas.add(headSha);
    return WorkflowRunsQueryResult(success: true, runs: workflowRuns);
  }
}

final class _RecordingNotifications implements DeploymentNotificationClient {
  int permissionRequests = 0;
  int notifications = 0;
  bool? lastSuccess;

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
    notifications += 1;
    lastSuccess = success;
  }
}

final class _MemorySettingsStore implements SettingsStore {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<void> init() async {}

  @override
  Future<String?> read(String key) async => value;

  @override
  Future<void> write(String key, String value) async => this.value = value;
}
