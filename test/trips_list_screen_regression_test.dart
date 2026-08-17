import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/providers/settings_provider.dart';
import 'package:trip_manager_app/providers/trips_provider.dart';
import 'package:trip_manager_app/screens/trips_list_screen.dart';
import 'package:trip_manager_app/services/github_service.dart';
import 'package:trip_manager_app/services/trips_parser.dart';

void main() {
  Map<String, dynamic> trip({
    required String id,
    required String title,
    bool featured = false,
    bool isActive = true,
  }) => <String, dynamic>{
    'id': id,
    'title': title,
    'location': '$title location',
    'price': '₹999',
    'image': '',
    'featured': featured,
    'isActive': isActive,
    'availableDates': <String>['Jan 1-2, 2099'],
    'highlights': <String>['View'],
    'itinerary': <Map<String, dynamic>>[],
    'inclusions': <String>[],
    'exclusions': <String>[],
  };

  Future<({TripsProvider trips, SettingsProvider settings})> providersFor(
    _FakeGitHubService service,
  ) async {
    final settings = SettingsProvider(store: _MemorySettingsStore());
    await settings.init();
    await settings.saveSettings(AppSettings(githubToken: 'test-token'));
    final trips = TripsProvider(
      settings.settings,
      serviceFactory: (_) => service,
    );
    return (trips: trips, settings: settings);
  }

  Widget buildSubject({
    required TripsProvider trips,
    required SettingsProvider settings,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TripsProvider>.value(value: trips),
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ],
      child: const MaterialApp(home: TripsListScreen()),
    );
  }

  testWidgets('shows loading, populated, and inactive semantic states', (
    tester,
  ) async {
    final pending = Completer<GitHubFileResult>();
    final service = _FakeGitHubService(tripsFuture: pending.future);
    final providers = await providersFor(service);

    await tester.pumpWidget(
      buildSubject(trips: providers.trips, settings: providers.settings),
    );
    await tester.pump();

    expect(find.text('Loading trips from GitHub...'), findsOneWidget);

    pending.complete(
      _tripsResult(<Map<String, dynamic>>[
        trip(id: 'alpha', title: 'Alpha Trek'),
        trip(id: 'resting', title: 'Resting Trek', isActive: false),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alpha Trek'), findsOneWidget);
    expect(find.text('Resting Trek'), findsOneWidget);
    expect(find.text('INACTIVE'), findsOneWidget);
    final inactiveOpacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('INACTIVE'), matching: find.byType(Opacity)),
    );
    expect(inactiveOpacity.opacity, 0.5);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('shows empty and search-empty states', (tester) async {
    final service = _FakeGitHubService(
      tripsFuture: Future<GitHubFileResult>.value(
        _tripsResult(const <Map<String, dynamic>>[]),
      ),
    );
    final providers = await providersFor(service);

    await tester.pumpWidget(
      buildSubject(trips: providers.trips, settings: providers.settings),
    );
    await tester.pumpAndSettle();

    expect(find.text('No trips found'), findsOneWidget);

    providers.trips.addTrip(trip(id: 'alpha', title: 'Alpha Trek'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'missing');
    await tester.pump();

    expect(find.text('No trips match your search'), findsOneWidget);
  });

  testWidgets('shows a load error without retrying the network', (
    tester,
  ) async {
    final service = _FakeGitHubService(
      tripsFuture: Future<GitHubFileResult>.value(
        GitHubFileResult(
          content: '',
          sha: '',
          success: false,
          error: 'Fake repository unavailable',
        ),
      ),
    );
    final providers = await providersFor(service);

    await tester.pumpWidget(
      buildSubject(trips: providers.trips, settings: providers.settings),
    );
    await tester.pumpAndSettle();

    expect(find.text('Error loading trips'), findsOneWidget);
    expect(find.text('Fake repository unavailable'), findsOneWidget);
    expect(service.fetchTripsCalls, 1);
  });

  testWidgets(
    'featured filtering, toggle, and searched delete act by trip ID',
    (tester) async {
      final service = _FakeGitHubService(
        tripsFuture: Future<GitHubFileResult>.value(
          _tripsResult(<Map<String, dynamic>>[
            trip(id: 'alpha', title: 'Alpha Trek'),
            trip(id: 'beta', title: 'Beta Trek', featured: true),
          ]),
        ),
        featuredIds: const <String>['beta'],
      );
      final providers = await providersFor(service);

      await tester.pumpWidget(
        buildSubject(trips: providers.trips, settings: providers.settings),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Show featured only'));
      await tester.pump();
      expect(find.text('Beta Trek'), findsOneWidget);
      expect(find.text('Alpha Trek'), findsNothing);

      await _chooseTripMenuAction(tester, 'beta', 'Remove Featured');
      expect(providers.trips.getTripById('beta')!['featured'], isFalse);
      expect(providers.trips.getTripById('alpha')!['featured'], isFalse);
      expect(find.text('No trips found'), findsOneWidget);

      await tester.tap(find.byTooltip('Show featured only'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'Beta');
      await tester.pump();
      expect(find.text('Beta Trek'), findsOneWidget);
      expect(find.text('Alpha Trek'), findsNothing);

      await _chooseTripMenuAction(tester, 'beta', 'Delete');
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(providers.trips.getTripById('beta'), isNull);
      expect(providers.trips.getTripById('alpha'), isNotNull);
      expect(providers.trips.intentionalDeletedIds, contains('beta'));
    },
  );

  testWidgets('filtered actions preserve an exact whitespace-containing ID', (
    tester,
  ) async {
    const exactId = ' alpha ';
    final service = _FakeGitHubService(
      tripsFuture: Future<GitHubFileResult>.value(
        _tripsResult(<Map<String, dynamic>>[
          trip(id: exactId, title: 'Whitespace ID Trek'),
        ]),
      ),
    );
    final providers = await providersFor(service);

    await tester.pumpWidget(
      buildSubject(trips: providers.trips, settings: providers.settings),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Whitespace');
    await tester.pump();

    await _chooseTripMenuAction(tester, exactId, 'Mark Featured');
    expect(providers.trips.getTripById(exactId)!['featured'], isTrue);
    expect(
      find.text(
        'That trip changed or no longer exists. Refresh before retrying.',
      ),
      findsNothing,
    );

    await _chooseTripMenuAction(tester, exactId, 'Delete');
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(providers.trips.getTripById(exactId), isNull);
    expect(providers.trips.intentionalDeletedIds, contains(exactId));
  });

  testWidgets('delete confirmation re-resolves the trip ID', (tester) async {
    final service = _FakeGitHubService(
      tripsFuture: Future<GitHubFileResult>.value(
        _tripsResult(<Map<String, dynamic>>[
          trip(id: 'alpha', title: 'Alpha Trek'),
          trip(id: 'beta', title: 'Beta Trek'),
        ]),
      ),
    );
    final providers = await providersFor(service);

    await tester.pumpWidget(
      buildSubject(trips: providers.trips, settings: providers.settings),
    );
    await tester.pumpAndSettle();
    await _chooseTripMenuAction(tester, 'alpha', 'Delete');
    expect(find.text('Delete Trip'), findsOneWidget);

    // Simulate state changing while the confirmation dialog is open. A stale
    // captured index would now point at Beta and delete the wrong trip.
    providers.trips.deleteTrip(providers.trips.getTripIndexById('alpha')!);
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(providers.trips.getTripById('alpha'), isNull);
    expect(providers.trips.getTripById('beta'), isNotNull);
    expect(
      find.text(
        'That trip changed or no longer exists. Refresh before retrying.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'reorders within one tier and opens the unsaved batches preview',
    (tester) async {
      final service = _FakeGitHubService(
        tripsFuture: Future<GitHubFileResult>.value(
          _tripsResult(<Map<String, dynamic>>[
            trip(id: 'alpha', title: 'Alpha Trek'),
            trip(id: 'beta', title: 'Beta Trek'),
            trip(id: 'inactive', title: 'Inactive Trek', isActive: false),
          ]),
        ),
      );
      final providers = await providersFor(service);

      await tester.pumpWidget(
        buildSubject(trips: providers.trips, settings: providers.settings),
      );
      await tester.pumpAndSettle();

      final reorderable = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      reorderable.onReorder(0, 2);
      await tester.pump();
      expect(providers.trips.trips.map((item) => item['id']).toList(), <String>[
        'beta',
        'alpha',
        'inactive',
      ]);

      await tester.tap(find.byTooltip('Preview Upcoming Batches'));
      await tester.pumpAndSettle();

      expect(find.text('Upcoming Batches'), findsOneWidget);
      expect(find.text('Unsaved data preview'), findsOneWidget);
      expect(find.text('Beta Trek'), findsOneWidget);
      expect(find.text('Alpha Trek'), findsOneWidget);
      expect(find.text('Inactive Trek'), findsNothing);
    },
  );

  testWidgets('conflict discard requires two confirmations and truly reloads', (
    tester,
  ) async {
    final service = _MutableScreenGitHubService(<Map<String, dynamic>>[
      trip(id: 'alpha', title: 'Original Trek'),
    ]);
    final settings = SettingsProvider(store: _MemorySettingsStore());
    await settings.init();
    await settings.saveSettings(AppSettings(githubToken: 'test-token'));
    final provider = TripsProvider(
      settings.settings,
      serviceFactory: (_) => service,
    );

    await tester.pumpWidget(buildSubject(trips: provider, settings: settings));
    await tester.pumpAndSettle();
    provider.updateTrip(0, <String, dynamic>{
      ...provider.trips.single,
      'title': 'Local Trek',
      'name': 'Local Trek',
    });
    service.replaceTrips(<Map<String, dynamic>>[
      trip(id: 'alpha', title: 'Remote Trek'),
    ]);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.cloud_upload));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();
    expect(find.text('Conflict Detected'), findsWidgets);
    expect(provider.trips.single['title'], 'Local Trek');

    await tester.tap(find.widgetWithText(TextButton, 'Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Discard Local Changes?'), findsOneWidget);
    expect(provider.trips.single['title'], 'Local Trek');

    await tester.tap(find.widgetWithText(TextButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Final Discard Confirmation'), findsOneWidget);
    expect(provider.trips.single['title'], 'Local Trek');

    await tester.tap(find.widgetWithText(FilledButton, 'Discard & Reload'));
    await tester.pumpAndSettle();
    expect(provider.trips.single['title'], 'Remote Trek');
    expect(provider.hasUnsavedChanges, isFalse);
    expect(service.atomicCommitCalls, 0);
  });
}

Future<void> _chooseTripMenuAction(
  WidgetTester tester,
  String tripId,
  String action,
) async {
  final card = find.byKey(ValueKey<dynamic>(tripId));
  final menu = find.descendant(
    of: card,
    matching: find.byType(PopupMenuButton<String>),
  );
  await tester.tap(menu);
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

GitHubFileResult _tripsResult(List<Map<String, dynamic>> trips) {
  return GitHubFileResult(
    content: TripsParser.generateTripsDataJs(trips),
    sha: 'trips-sha',
    success: true,
  );
}

final class _FakeGitHubService extends GitHubService {
  _FakeGitHubService({
    required this.tripsFuture,
    this.featuredIds = const <String>[],
  }) : super(settings: AppSettings());

  final Future<GitHubFileResult> tripsFuture;
  final List<String> featuredIds;
  int fetchTripsCalls = 0;

  @override
  Future<GitHubFileResult> fetchTripsData() {
    fetchTripsCalls += 1;
    return tripsFuture;
  }

  @override
  Future<GitHubFileResult> fetchFile(String filePath) async {
    return GitHubFileResult(
      content:
          'const featuredTripIds = [${featuredIds.map((id) => '"$id"').join(', ')}];',
      sha: 'featured-sha',
      success: true,
    );
  }
}

final class _MutableScreenGitHubService extends GitHubService {
  _MutableScreenGitHubService(this._trips) : super(settings: AppSettings());

  List<Map<String, dynamic>> _trips;
  int revision = 1;
  int atomicCommitCalls = 0;

  void replaceTrips(List<Map<String, dynamic>> trips) {
    _trips = trips;
    revision++;
  }

  @override
  Future<GitHubFileResult> fetchTripsData() async => GitHubFileResult(
    content: TripsParser.generateTripsDataJs(_trips),
    sha: 'trips-$revision',
    success: true,
  );

  @override
  Future<GitHubFileResult> fetchFile(String filePath) async => GitHubFileResult(
    content: TripsParser.generateFeaturedTripsJs(_trips),
    sha: 'featured-$revision',
    success: true,
  );

  @override
  Future<GitHubCommitResult> commitFilesAtomically({
    required Map<String, String> files,
    required Map<String, String?> expectedBlobShas,
    required String commitMessage,
  }) async {
    atomicCommitCalls++;
    return GitHubCommitResult(
      success: false,
      error: 'Atomic commit should not run before resolving this conflict.',
    );
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
