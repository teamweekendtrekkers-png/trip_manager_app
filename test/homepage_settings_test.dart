import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/models/homepage_config.dart';
import 'package:trip_manager_app/providers/settings_provider.dart';
import 'package:trip_manager_app/screens/homepage_settings_screen.dart';
import 'package:trip_manager_app/services/github_service.dart';
import 'package:trip_manager_app/services/homepage_settings_service.dart';
import 'package:trip_manager_app/services/trip_date_utils.dart';

final reference = DateTime.utc(2026, 8, 13, 12);
List<Map<String, dynamic>> trips() => [
  {
    'id': 'a',
    'title': 'Alpha',
    'price': '₹999',
    'location': 'Hill',
    'duration': '2 days',
    'difficulty': 'Easy',
    'availableDates': [
      'Aug 14-16, 2026',
      'Aug 21-23, 2026',
      'Aug 28-30, 2026',
      'Sep 4-6, 2026',
    ],
  },
  {
    'id': 'b',
    'title': 'Beta',
    'price': '₹1,999',
    'availableDates': ['Aug 14-16, 2026'],
  },
  {
    'id': 'inactive',
    'title': 'Inactive',
    'isActive': false,
    'availableDates': ['Aug 14-16, 2026'],
  },
];
HomepageConfig config([void Function(Map<String, dynamic>)? edit]) {
  final data = HomepageConfig.initial().toJson();
  edit?.call(data);
  return HomepageConfig.parse(jsonEncode(data));
}

GitHubFileResult file(HomepageConfig value, [String sha = 'base']) =>
    GitHubFileResult(content: value.encode(), sha: sha, success: true);

class MemoryGitHub extends GitHubService {
  MemoryGitHub(this.snapshots)
    : super(settings: AppSettings(githubToken: 'test'));
  final List<GitHubFileResult> snapshots;
  final calls = <Map<String, String>>[];
  final expected = <Map<String, String?>>[];
  final results = <GitHubCommitResult>[];
  @override
  Future<GitHubFileResult> fetchFile(String filePath) async {
    if (filePath != HomepageSettingsService.path) {
      throw StateError('Unexpected homepage read: $filePath');
    }
    return snapshots.removeAt(0);
  }

  @override
  Future<GitHubCommitResult> commitFilesAtomically({
    required Map<String, String> files,
    required Map<String, String?> expectedBlobShas,
    required String commitMessage,
  }) async {
    calls.add(files);
    expected.add(expectedBlobShas);
    return results.isEmpty
        ? GitHubCommitResult(
            success: true,
            commitSha: 'homepage-commit',
            fileBlobShas: {HomepageSettingsService.path: 'saved'},
          )
        : results.removeAt(0);
  }
}

void main() {
  test(
    'defaults reproduce automatic three-group behavior without mutating data',
    () {
      final original = trips(), before = jsonEncode(trips());
      final expected = TripDateUtils.buildUpcomingBatches(
        original,
        referenceDate: reference,
      );
      final actual = config().buildBatches(original, referenceDate: reference);
      expect(
        actual.map((batch) => batch.key),
        expected.map((batch) => batch.key),
      );
      expect(
        actual
            .map((batch) => batch.trips.map((trip) => trip.id).toList())
            .toList(),
        expected
            .map((batch) => batch.trips.map((trip) => trip.id).toList())
            .toList(),
      );
      expect(jsonEncode(original), before);
      final copy = config().toJson();
      (copy['hero'] as Map)['title'] = 'Changed';
      expect(
        config().toJson()['hero']['title'],
        'Explore. Travel. Experience.',
      );
    },
  );
  test(
    'trip and departure selection use exact IDs and normalized date ranges',
    () {
      final selected = config((data) {
        data['upcomingBatches']['tripSelection'] = 'selected';
        data['upcomingBatches']['tripIds'] = ['a', 'inactive', 'removed'];
        data['upcomingBatches']['departureSelection'] = 'selected';
        data['upcomingBatches']['departures'] = [
          {'tripId': 'a', 'date': 'Aug 21–23.2026'},
          {'tripId': 'b', 'date': 'Aug 14-16, 2026'},
        ];
      });
      final batches = selected.buildBatches(trips(), referenceDate: reference);
      expect(batches.single.key, '2026-08-21/2026-08-23');
      expect(batches.single.trips.single.id, 'a');
    },
  );
  test(
    'empty selection means none, not automatic; visibility and count work',
    () {
      expect(
        config(
          (data) => data['upcomingBatches']['tripSelection'] = 'selected',
        ).buildBatches(trips(), referenceDate: reference),
        isEmpty,
      );
      expect(
        config(
          (data) => data['upcomingBatches']['departureSelection'] = 'selected',
        ).buildBatches(trips(), referenceDate: reference),
        isEmpty,
      );
      expect(
        config(
          (data) => data['upcomingBatches']['enabled'] = false,
        ).buildBatches(trips(), referenceDate: reference),
        isEmpty,
      );
      expect(
        config(
          (data) => data['upcomingBatches']['maxBatches'] = 12,
        ).buildBatches(trips(), referenceDate: reference),
        hasLength(4),
      );
    },
  );
  test(
    'ongoing selections expire at India midnight and removed dates stay absent',
    () {
      final selected = config((data) {
        data['upcomingBatches']['departureSelection'] = 'selected';
        data['upcomingBatches']['departures'] = [
          {'tripId': 'a', 'date': 'Aug 14-16, 2026'},
        ];
      });
      expect(
        selected.buildBatches(
          trips(),
          referenceDate: DateTime.utc(2026, 8, 16, 18, 29, 59),
        ),
        hasLength(1),
      );
      expect(
        selected.buildBatches(
          trips(),
          referenceDate: DateTime.utc(2026, 8, 16, 18, 30),
        ),
        isEmpty,
      );
      expect(
        selected.buildBatches([
          {'id': 'a', 'availableDates': <String>[]},
        ], referenceDate: reference),
        isEmpty,
      );
    },
  );
  test(
    'rejects unsupported schema, malformed selections and wrong field types',
    () {
      for (final edit in <void Function(Map<String, dynamic>)>[
        (data) => data['version'] = 2,
        (data) => data['unknown'] = true,
        (data) => data['hero']['custom'] = 1,
        (data) => data['hero'] = [],
        (data) => data['hero']['title'] = '',
        (data) => data['hero']['title'] = 3,
        (data) => data['upcomingBatches']['maxBatches'] = 0,
        (data) => data['upcomingBatches']['maxBatches'] = 13,
        (data) => data['upcomingBatches']['enabled'] = 'true',
        (data) => data['upcomingBatches']['tripIds'] = [1],
        (data) => data['upcomingBatches']['departureSelection'] = 'invalid',
        (data) => data['upcomingBatches']['departures'] = [
          {'tripId': 'a', 'date': 'bad'},
        ],
        (data) => data['upcomingBatches']['fields']['price'] = 1,
      ]) {
        expect(() => config(edit), throwsFormatException);
      }
    },
  );
  test('image validation rejects script URLs, traversal and CSS injection', () {
    for (final path in [
      'images/bg.jpg',
      'images/trips/homepage_123.webp',
      'https://example.com/photo.jpg?width=200',
    ]) {
      expect(HomepageConfig.safeImage(path), isTrue, reason: path);
    }
    for (final path in [
      'javascript:alert(1)',
      'data:image/svg+xml,a',
      '//example.com/x',
      'http://example.com/x',
      'images/../secret',
      'images/a.jpg")',
      'https://user:pass@example.com/x',
      'images/a\nb.jpg',
    ]) {
      expect(HomepageConfig.safeImage(path), isFalse, reason: path);
    }
  });
  test(
    'deduplicates equivalent selected ranges without changing trip dates',
    () {
      final selected = config(
        (data) => data['upcomingBatches']['departures'] = [
          {'tripId': 'a', 'date': 'Aug 14–16.2026'},
          {'tripId': 'a', 'date': 'Aug 14-16, 2026'},
        ],
      );
      expect(selected.toJson()['upcomingBatches']['departures'], [
        {'tripId': 'a', 'date': 'Aug 14-16, 2026'},
      ]);
    },
  );
  test('three-way merge preserves non-overlapping nested edits', () {
    final local = config((data) {
      data['hero']['title'] = 'Local';
      data['upcomingBatches']['fields']['price'] = false;
    });
    final remote = config((data) {
      data['hero']['backgroundImage'] = 'images/remote.jpg';
      data['upcomingBatches']['fields']['location'] = true;
    });
    final merged = HomepageSettingsService.merge(
      config(),
      local,
      remote,
    ).toJson();
    expect(merged['hero']['title'], 'Local');
    expect(merged['hero']['backgroundImage'], 'images/remote.jpg');
    expect(merged['upcomingBatches']['fields']['price'], isFalse);
    expect(merged['upcomingBatches']['fields']['location'], isTrue);
  });
  test('same-field conflicts are listed and never silently overwritten', () {
    final ours = config((data) => data['hero']['title'] = 'Ours');
    final theirs = config((data) => data['hero']['title'] = 'Theirs');
    expect(
      () => HomepageSettingsService.merge(config(), ours, theirs),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'field',
          contains('hero.title'),
        ),
      ),
    );
    expect(
      HomepageSettingsService.merge(
        config(),
        ours,
        ours,
      ).toJson()['hero']['title'],
      'Ours',
    );
  });
  test(
    'publication touches only homepage JSON and uses latest expected blob SHA',
    () async {
      final github = MemoryGitHub([
        file(config()),
        file(
          config((data) => data['hero']['description'] = 'Remote'),
          'latest',
        ),
      ]);
      final service = HomepageSettingsService(github);
      await service.load();
      final result = await service.save(
        config((data) => data['hero']['title'] = 'Local'),
      );
      expect(result.success, isTrue);
      expect(result.commitSha, 'homepage-commit');
      expect(github.calls.single.keys, [HomepageSettingsService.path]);
      expect(github.expected.single, {HomepageSettingsService.path: 'latest'});
      final saved = HomepageConfig.parse(
        github.calls.single.values.single,
      ).toJson();
      expect(saved['hero']['title'], 'Local');
      expect(saved['hero']['description'], 'Remote');
    },
  );
  test(
    'true remote conflict creates no commit and keeps loaded baseline',
    () async {
      final github = MemoryGitHub([
        file(config()),
        file(config((data) => data['hero']['title'] = 'Remote')),
      ]);
      final service = HomepageSettingsService(github);
      await service.load();
      final result = await service.save(
        config((data) => data['hero']['title'] = 'Local'),
      );
      expect(result.hasConflict, isTrue);
      expect(github.calls, isEmpty);
      expect(service.currentSha, 'base');
    },
  );
  test(
    'branch race retries with fresh source and preserves concurrent fields',
    () async {
      final github = MemoryGitHub([
        file(config()),
        file(config()),
        file(
          config((data) => data['upcomingBatches']['maxBatches'] = 6),
          'raced',
        ),
      ]);
      github.results.add(GitHubCommitResult(success: false, hasConflict: true));
      final service = HomepageSettingsService(github);
      await service.load();
      final result = await service.save(
        config((data) => data['hero']['title'] = 'Local'),
      );
      expect(result.success, isTrue);
      expect(github.calls, hasLength(2));
      expect(github.expected.last.values.single, 'raced');
      expect(
        HomepageConfig.parse(
          github.calls.last.values.single,
        ).toJson()['upcomingBatches']['maxBatches'],
        6,
      );
    },
  );
  test(
    'repeated branch races stop without overwriting, and API failure retains baseline',
    () async {
      final github = MemoryGitHub(List.generate(4, (_) => file(config())));
      github.results.addAll(
        List.generate(
          3,
          (_) => GitHubCommitResult(success: false, hasConflict: true),
        ),
      );
      final service = HomepageSettingsService(github);
      await service.load();
      expect(
        (await service.save(
          config((data) => data['hero']['title'] = 'Local'),
        )).hasConflict,
        isTrue,
      );
      expect(github.calls, hasLength(3));
      expect(service.currentSha, 'base');
    },
  );
  test(
    'only explicit 404 permits config creation; permission/API errors block',
    () async {
      final missing = GitHubFileResult(
        content: '',
        sha: '',
        success: false,
        statusCode: 404,
      );
      final github = MemoryGitHub([missing, missing]);
      final service = HomepageSettingsService(github);
      await service.load();
      expect((await service.save(config())).success, isTrue);
      expect(github.expected.single, {HomepageSettingsService.path: null});
      for (final status in [401, 403, 500, null]) {
        final denied = MemoryGitHub([
          GitHubFileResult(
            content: '',
            sha: '',
            success: false,
            statusCode: status,
            error: 'Denied',
          ),
        ]);
        await expectLater(
          HomepageSettingsService(denied).load(),
          throwsStateError,
        );
        expect(denied.calls, isEmpty);
      }
    },
  );
  test(
    'unsupported remote fields block publication; unchanged data is a no-op',
    () async {
      final github = MemoryGitHub([
        file(config()),
        GitHubFileResult(
          content: '{"version":1,"newField":true}',
          sha: 'remote',
          success: true,
        ),
      ]);
      final service = HomepageSettingsService(github);
      await service.load();
      expect(
        (await service.save(
          config((data) => data['hero']['title'] = 'Edit'),
        )).success,
        isFalse,
      );
      expect(github.calls, isEmpty);
      final same = MemoryGitHub([file(config()), file(config())]);
      final sameService = HomepageSettingsService(same);
      await sameService.load();
      expect((await sameService.save(config())).success, isTrue);
      expect(same.calls, isEmpty);
    },
  );

  Future<MemoryGitHub> openEditor(
    WidgetTester tester, {
    HomepageConfig? initial,
    HomepageConfig? remote,
    bool dark = false,
    Future<String?> Function()? uploader,
    GitHubFileResult? initialFile,
  }) async {
    if (!Platform.isAndroid) {
      tester.view.physicalSize = const Size(411, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    final settings = SettingsProvider(store: MemoryStore());
    await settings.init();
    await settings.saveSettings(AppSettings(githubToken: 'test'));
    final github = MemoryGitHub([
      initialFile ?? file(initial ?? config()),
      file(remote ?? initial ?? config()),
    ]);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: HomepageSettingsScreen(
            service: HomepageSettingsService(github),
            trips: trips(),
            referenceDate: reference,
            imageUploader: uploader,
            imagePreviewBuilder: (_) => const SizedBox(
              height: 160,
              child: Text('Background preview fixture'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (initialFile == null) {
      expect(
        find.text('Hero / Background'),
        findsOneWidget,
        reason: tester.allWidgets
            .whereType<Text>()
            .map((widget) => widget.data)
            .join('\n'),
      );
    }
    return github;
  }

  Future<void> showKey(WidgetTester tester, String key) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final finder = find.byKey(ValueKey(key));
    if (finder.evaluate().isEmpty) {
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        finder,
        400,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 80,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await showKey(tester, key);
    final finder = find.byKey(ValueKey(key));
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> publish(WidgetTester tester) async {
    await tapKey(tester, 'homepage-publish');
    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'phone editor changes background/copy and publishes only homepage settings',
    (tester) async {
      final github = await openEditor(tester);
      await tester.enterText(
        find.byKey(const ValueKey('homepage-hero-backgroundImage')),
        'images/new.jpg',
      );
      await tester.enterText(
        find.byKey(const ValueKey('homepage-hero-title')),
        'New adventures',
      );
      await publish(tester);
      final saved = HomepageConfig.parse(
        github.calls.single.values.single,
      ).toJson();
      expect(saved['hero']['backgroundImage'], 'images/new.jpg');
      expect(saved['hero']['title'], 'New adventures');
      expect(github.calls.single.keys, [HomepageSettingsService.path]);
      expect(find.text('Homepage settings published.'), findsOneWidget);
    },
  );
  testWidgets(
    'phone controls select exact departures and preview chosen card fields',
    (tester) async {
      final github = await openEditor(tester);
      await tapKey(tester, 'homepage-choose-trips');
      await tapKey(tester, 'homepage-trip-a');
      await tapKey(tester, 'homepage-choose-departures');
      await tapKey(tester, 'homepage-departure-a|2026-08-21/2026-08-23');
      await tapKey(tester, 'homepage-field-price');
      await tapKey(tester, 'homepage-field-location');
      final preview = find.byKey(const Key('homepage-preview'));
      await showKey(tester, 'homepage-preview');
      expect(
        find.descendant(of: preview, matching: find.text('Alpha')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: preview, matching: find.text('Beta')),
        findsNothing,
      );
      expect(
        find.descendant(of: preview, matching: find.text('₹999')),
        findsNothing,
      );
      expect(
        find.descendant(of: preview, matching: find.text('Hill')),
        findsOneWidget,
      );
      await publish(tester);
      expect(
        HomepageConfig.parse(
          github.calls.single.values.single,
        ).buildBatches(trips(), referenceDate: reference).single.key,
        '2026-08-21/2026-08-23',
      );
    },
  );
  testWidgets(
    'upload updates draft only; cancel publication performs no commit',
    (tester) async {
      final github = await openEditor(
        tester,
        uploader: () async => 'images/trips/homepage_123.jpg',
      );
      await tapKey(tester, 'homepage-upload');
      await showKey(tester, 'homepage-hero-backgroundImage');
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('homepage-hero-backgroundImage')),
            )
            .controller!
            .text,
        'images/trips/homepage_123.jpg',
      );
      expect(github.calls, isEmpty);
      await tapKey(tester, 'homepage-publish');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(github.calls, isEmpty);
    },
  );
  testWidgets('conflicting edits retain draft with no commit', (tester) async {
    final github = await openEditor(
      tester,
      remote: config((data) => data['hero']['title'] = 'Remote'),
    );
    await tester.enterText(
      find.byKey(const ValueKey('homepage-hero-title')),
      'Local',
    );
    await publish(tester);
    await showKey(tester, 'homepage-error');
    expect(find.textContaining('Homepage conflicts:'), findsOneWidget);
    expect(github.calls, isEmpty);
    await showKey(tester, 'homepage-hero-title');
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('homepage-hero-title')))
          .controller!
          .text,
      'Local',
    );
  });
  testWidgets('invalid image URL is blocked before any publish confirmation', (
    tester,
  ) async {
    final github = await openEditor(tester);
    await tester.enterText(
      find.byKey(const ValueKey('homepage-hero-backgroundImage')),
      'javascript:alert(1)',
    );
    await tapKey(tester, 'homepage-publish');
    await showKey(tester, 'homepage-error');
    expect(find.textContaining('valid HTTPS image URL'), findsOneWidget);
    expect(github.calls, isEmpty);
    expect(github.snapshots, hasLength(1));
  });
  testWidgets(
    'changed repository settings disable publication without losing draft',
    (tester) async {
      final github = await openEditor(tester);
      final element = tester.element(find.byType(HomepageSettingsScreen));
      final provider = element.read<SettingsProvider>();
      await provider.saveSettings(
        provider.settings.copyWith(branch: 'different'),
      );
      await tester.pumpAndSettle();
      await showKey(tester, 'homepage-publish');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('homepage-publish')))
            .onPressed,
        isNull,
      );
      expect(github.calls, isEmpty);
    },
  );
  testWidgets('reload requires confirmation before discarding homepage draft', (
    tester,
  ) async {
    final github = await openEditor(
      tester,
      remote: config((data) => data['hero']['title'] = 'Remote'),
    );
    await tester.enterText(
      find.byKey(const ValueKey('homepage-hero-title')),
      'Local',
    );
    await tester.tap(find.byTooltip('Reload homepage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(github.snapshots, hasLength(1));
    await tester.tap(find.byTooltip('Reload homepage'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Reload'));
    await tester.pumpAndSettle();
    await showKey(tester, 'homepage-hero-title');
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('homepage-hero-title')))
          .controller!
          .text,
      'Remote',
    );
    expect(github.calls, isEmpty);
  });
  testWidgets('load failure shows retry and never permits publication', (
    tester,
  ) async {
    final github = await openEditor(
      tester,
      initialFile: GitHubFileResult(
        content: '',
        sha: '',
        success: false,
        statusCode: 403,
        error: 'Permission denied',
      ),
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byKey(const Key('homepage-publish')), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Hero / Background'), findsOneWidget);
    expect(github.calls, isEmpty);
  });
  testWidgets(
    'dark editor previews empty manual selections and hidden section',
    (tester) async {
      await openEditor(tester, dark: true);
      await tapKey(tester, 'homepage-choose-trips');
      final preview = find.byKey(const Key('homepage-preview'));
      await showKey(tester, 'homepage-preview');
      expect(
        find.descendant(
          of: preview,
          matching: find.text('New dates coming soon'),
        ),
        findsOneWidget,
      );
      await tapKey(tester, 'homepage-enabled');
      await showKey(tester, 'homepage-preview');
      expect(
        find.descendant(
          of: preview,
          matching: find.text('Upcoming Batches is hidden.'),
        ),
        findsOneWidget,
      );
    },
  );
  if (!Platform.isAndroid) {
    for (final dark in [false, true]) {
      testWidgets('homepage editor golden ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        await openEditor(tester, dark: dark);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile(
            'goldens/homepage_editor_${dark ? 'dark' : 'light'}.png',
          ),
        );
      });
    }
  }
}

class MemoryStore implements SettingsStore {
  String? value;
  @override
  Future<void> init() async {}
  @override
  Future<String?> read(String key) async => value;
  @override
  Future<void> write(String key, String value) async {
    this.value = value;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}
