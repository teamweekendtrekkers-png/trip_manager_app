import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/providers/settings_provider.dart';
import 'package:trip_manager_app/providers/trips_provider.dart';
import 'package:trip_manager_app/screens/data_health_screen.dart';
import 'package:trip_manager_app/screens/deployment_status_screen.dart';
import 'package:trip_manager_app/screens/settings_screen.dart';
import 'package:trip_manager_app/screens/trip_edit_screen.dart';
import 'package:trip_manager_app/screens/trips_list_screen.dart';
import 'package:trip_manager_app/screens/upcoming_batches_screen.dart';
import 'package:trip_manager_app/services/github_service.dart';
import 'package:trip_manager_app/services/notification_service.dart';
import 'package:trip_manager_app/services/trips_parser.dart';

const _goldenKey = Key('golden-boundary');
final _fixedNow = DateTime.utc(2026, 8, 13, 6, 30);

void main() {
  Future<void> configureSurface(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  Future<void> expectGolden(WidgetTester tester, String name) => expectLater(
    find.byKey(_goldenKey),
    matchesGoldenFile('goldens/$name.png'),
  );

  group('mandatory screen goldens', () {
    testWidgets('Trip List — loading, light', (tester) async {
      await configureSurface(tester);
      final pending = Completer<GitHubFileResult>();
      final service = _GoldenGitHubService(tripsFuture: pending.future);
      final providers = await _configuredProviders(service);

      await tester.pumpWidget(
        _withAppProviders(
          trips: providers.trips,
          settings: providers.settings,
          child: _goldenApp(const TripsListScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Loading trips from GitHub...'), findsOneWidget);
      await expectGolden(tester, 'trip_list_loading_light');
    });

    testWidgets('Trip List — populated with inactive trip, light', (
      tester,
    ) async {
      await configureSurface(tester);
      final service = _GoldenGitHubService(
        tripsResult: _tripsResult(<Map<String, dynamic>>[
          _trip(id: 'sunrise', title: 'Sunrise Ridge Trek', featured: true),
          _trip(id: 'resting', title: 'Resting Valley Escape', isActive: false),
        ]),
        featuredIds: const <String>['sunrise'],
      );
      final providers = await _configuredProviders(service);

      await tester.pumpWidget(
        _withAppProviders(
          trips: providers.trips,
          settings: providers.settings,
          child: _goldenApp(const TripsListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sunrise Ridge Trek'), findsOneWidget);
      expect(find.text('INACTIVE'), findsOneWidget);
      await expectGolden(tester, 'trip_list_populated_inactive_light');
    });

    testWidgets('Trip List — true merge conflict dialog, light', (
      tester,
    ) async {
      await configureSurface(tester);
      final base = _trip(id: 'ridge', title: 'Original Ridge Trek');
      final service = _GoldenGitHubService(
        tripsResult: _tripsResult(<Map<String, dynamic>>[base]),
      );
      final providers = await _configuredProviders(service);
      await providers.trips.loadTrips();
      providers.trips.updateTrip(0, <String, dynamic>{
        ...providers.trips.trips.single,
        'title': 'Local Ridge Trek',
        'name': 'Local Ridge Trek',
      });
      service.tripsResult = _tripsResult(<Map<String, dynamic>>[
        <String, dynamic>{
          ...base,
          'title': 'Remote Ridge Trek',
          'name': 'Remote Ridge Trek',
        },
      ]);

      await tester.pumpWidget(
        _withAppProviders(
          trips: providers.trips,
          settings: providers.settings,
          child: _goldenApp(const TripsListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Conflict Detected'), findsWidgets);
      expect(find.text('Pull & Merge'), findsOneWidget);
      expect(find.text('Discard Local'), findsOneWidget);
      expect(find.text('Overwrite'), findsWidgets);
      await expectGolden(tester, 'trip_list_conflict_light');
    });

    testWidgets('Trip Editor — populated invalid date section, light', (
      tester,
    ) async {
      await configureSurface(tester);
      final trip = _trip(
        id: 'misty-hills',
        title: 'Misty Hills Trek',
        availableDates: <String>['Aug 14-16, 2099', 'weekend after monsoon'],
      );
      final trips = TripsProvider(AppSettings())..addTrip(trip);
      trips.markChangesSaved();
      final settings = SettingsProvider(store: _MemorySettingsStore());
      await settings.init();

      await tester.pumpWidget(
        _withAppProviders(
          trips: trips,
          settings: settings,
          child: _goldenApp(TripEditScreen(trip: trip, index: 0)),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('available-dates-editor')),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      expect(find.text('Available Dates'), findsOneWidget);
      expect(
        find.text('Invalid — edit or remove before saving'),
        findsOneWidget,
      );
      await expectGolden(tester, 'trip_editor_dates_invalid_light');
    });

    testWidgets('Upcoming Batches — populated, light', (tester) async {
      await configureSurface(tester);

      await tester.pumpWidget(
        _goldenApp(
          UpcomingBatchesScreen(
            referenceDate: _fixedNow,
            trips: <Map<String, dynamic>>[
              _trip(
                id: 'coorg',
                title: 'Coorg Cloud Trail',
                availableDates: <String>['Aug 14-16, 2026', 'Aug 21-23, 2026'],
              ),
              _trip(
                id: 'kodai',
                title: 'Kodaikanal Escape',
                availableDates: <String>['Aug 14-16, 2026'],
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('AUG 14–16, 2026'), findsOneWidget);
      expect(find.text('Friday Departures'), findsNWidgets(2));
      await expectGolden(tester, 'upcoming_batches_populated_light');
    });

    testWidgets('Upcoming Batches — empty, dark', (tester) async {
      await configureSurface(tester);

      await tester.pumpWidget(
        _goldenApp(
          UpcomingBatchesScreen(
            trips: const <Map<String, dynamic>>[],
            referenceDate: _fixedNow,
          ),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump();

      expect(find.text('New dates coming soon'), findsOneWidget);
      await expectGolden(tester, 'upcoming_batches_empty_dark');
    });

    testWidgets('Settings — local configuration, dark', (tester) async {
      await configureSurface(tester);
      final settings = SettingsProvider(store: _MemorySettingsStore());
      await settings.init();
      await settings.saveSettings(AppSettings(darkMode: true));

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: _goldenApp(
            const SettingsScreen(),
            brightness: Brightness.dark,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('GitHub Configuration'), findsOneWidget);
      expect(find.text('Verify Token'), findsOneWidget);
      await expectGolden(tester, 'settings_configuration_dark');
    });

    testWidgets('Data Health — populated issue report, light', (tester) async {
      await configureSurface(tester);
      final trips = TripsProvider(AppSettings())
        ..addTrip(<String, dynamic>{
          ..._trip(
            id: 'needs-attention',
            title: 'Needs Attention Trek',
            isActive: false,
            availableDates: <String>[
              'Aug 14-16, 2026',
              'AUGUST 14–16, 2026',
              'not a real date',
            ],
          ),
          'image': 'unexpected/photo.jpg',
          'highlights': <String>[],
        });

      await tester.pumpWidget(
        ChangeNotifierProvider<TripsProvider>.value(
          value: trips,
          child: _goldenApp(const DataHealthScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Duplicate Date Range'), findsOneWidget);
      expect(find.text('Invalid Trip Date'), findsOneWidget);
      await expectGolden(tester, 'data_health_issues_light');
    });

    testWidgets('Deployment Status — Actions permission error, dark', (
      tester,
    ) async {
      await configureSurface(tester);
      final service = _GoldenGitHubService(
        workflowResult: const WorkflowRunsQueryResult(
          success: false,
          permissionDenied: true,
          statusCode: 403,
          error: 'Grant Actions read permission to this GitHub token.',
        ),
      );
      final notifications = _GoldenNotifications();
      final settings = SettingsProvider(store: _MemorySettingsStore());
      await settings.init();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: _goldenApp(
            DeploymentStatusScreen(
              savedCommitSha: 'abcdef1234567890',
              githubService: service,
              notificationClient: notifications,
              now: () => _fixedNow,
            ),
            brightness: Brightness.dark,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Actions permission required'), findsOneWidget);
      expect(notifications.permissionRequests, 1);
      await expectGolden(tester, 'deployment_permission_error_dark');
    });
  });
}

Widget _goldenApp(Widget screen, {Brightness brightness = Brightness.light}) {
  final theme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: brightness,
    ),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: RepaintBoundary(key: _goldenKey, child: screen),
  );
}

Widget _withAppProviders({
  required TripsProvider trips,
  required SettingsProvider settings,
  required Widget child,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<TripsProvider>.value(value: trips),
    ChangeNotifierProvider<SettingsProvider>.value(value: settings),
  ],
  child: child,
);

Future<({TripsProvider trips, SettingsProvider settings})> _configuredProviders(
  _GoldenGitHubService service,
) async {
  final settings = SettingsProvider(store: _MemorySettingsStore());
  await settings.init();
  await settings.saveSettings(AppSettings(githubToken: 'fake-token'));
  return (
    trips: TripsProvider(settings.settings, serviceFactory: (_) => service),
    settings: settings,
  );
}

Map<String, dynamic> _trip({
  required String id,
  required String title,
  bool featured = false,
  bool isActive = true,
  List<String> availableDates = const <String>['Jan 1-2, 2099'],
}) => <String, dynamic>{
  'id': id,
  'title': title,
  'name': title,
  'location': 'Western Ghats, Karnataka',
  'destination': 'Western Ghats, Karnataka',
  'about': 'A carefully planned local weekend trek.',
  'description': 'A carefully planned local weekend trek.',
  'date': availableDates.isEmpty ? '' : availableDates.first,
  'price': '₹2,999',
  'image': '',
  'badge': featured ? 'Featured' : '',
  'featured': featured,
  'isActive': isActive,
  'availableDates': availableDates,
  'highlights': <String>['Sunrise viewpoints', 'Forest trail'],
  'itinerary': <Map<String, dynamic>>[],
  'inclusions': <String>['Transport'],
  'exclusions': <String>['Personal expenses'],
  'thingsToCarry': <String>[],
  'galleryImages': <String>[],
  'boardingLocations': <Map<String, dynamic>>[],
};

GitHubFileResult _tripsResult(List<Map<String, dynamic>> trips) =>
    GitHubFileResult(
      content: TripsParser.generateTripsDataJs(trips),
      sha: 'trips-sha',
      success: true,
    );

final class _GoldenGitHubService extends GitHubService {
  _GoldenGitHubService({
    GitHubFileResult? tripsResult,
    this.tripsFuture,
    this.featuredIds = const <String>[],
    this.workflowResult = const WorkflowRunsQueryResult(success: true),
  }) : tripsResult =
           tripsResult ?? GitHubFileResult(content: '', sha: '', success: true),
       super(settings: AppSettings());

  GitHubFileResult tripsResult;
  final Future<GitHubFileResult>? tripsFuture;
  final List<String> featuredIds;
  final WorkflowRunsQueryResult workflowResult;

  @override
  Future<GitHubFileResult> fetchTripsData() =>
      tripsFuture ?? Future<GitHubFileResult>.value(tripsResult);

  @override
  Future<GitHubFileResult> fetchFile(String filePath) async => GitHubFileResult(
    content:
        'const featuredTripIds = [${featuredIds.map((id) => '"$id"').join(', ')}];',
    sha: 'featured-sha',
    success: true,
  );

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
  }) async => const <WorkflowRunResult>[];

  @override
  Future<WorkflowRunsQueryResult> getWorkflowRunsForCommit(
    String headSha, {
    int limit = 10,
  }) async => workflowResult;
}

final class _GoldenNotifications implements DeploymentNotificationClient {
  int permissionRequests = 0;

  @override
  Future<bool> requestPermission() async {
    permissionRequests += 1;
    return true;
  }

  @override
  Future<void> showDeploymentNotification({
    required bool success,
    String? commitMessage,
  }) async {}
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
