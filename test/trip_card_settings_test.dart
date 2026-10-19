import 'golden_platform.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/models/homepage_config.dart';
import 'package:trip_manager_app/models/trip_card_settings.dart';
import 'package:trip_manager_app/providers/settings_provider.dart';
import 'package:trip_manager_app/providers/trips_provider.dart';
import 'package:trip_manager_app/screens/trip_edit_screen.dart';
import 'package:trip_manager_app/screens/homepage_settings_screen.dart';
import 'package:trip_manager_app/services/homepage_settings_service.dart';
import 'package:trip_manager_app/services/trips_parser.dart';
import 'package:trip_manager_app/widgets/discovery_settings_editor.dart';
import 'package:trip_manager_app/widgets/trip_card_settings_editor.dart';
import 'package:trip_manager_app/widgets/homepage_sections_editor.dart';
import 'homepage_settings_test.dart' as homepage;
import 'trips_provider_publication_test.dart' as publication;

final _reference = DateTime.utc(2026, 8, 13, 12);
Map<String, dynamic> _trip() => {
  ...publication.trip('coorg', title: 'Coorg weekend'),
  'image': '',
  'duration': '2D/1N',
  'difficulty': 'Easy',
  'thingsToCarry': <String>['Raincoat', 'Walking shoes'],
};
const _cardValues = <String, String>{
  'cardImage': 'images/trips/coorg-cover.webp',
  'cardSummary': 'Waterfalls and a quiet coffee-estate weekend.',
  'departureCity': 'Bengaluru',
  'experience': 'getaway',
};

void main() {
  test('multiple categories and Bestseller round-trip without altering legacy data', () {
    final modern = {..._trip(), 'experiences': ['trek', 'adventure'], 'isBestseller': true};
    final written = TripsParser.replaceTripsDataObject(
      source: '// prefix\nconst tripsData = {};\n// suffix',
      trips: [modern],
    );
    expect(written.success, isTrue, reason: written.errors.join('\n'));
    expect(written.content, startsWith('// prefix\nconst tripsData = '));
    expect(written.content, endsWith(';\n// suffix'));
    final parsed = TripsParser.parseTripsDocument(written.content!);
    expect(parsed.isValid, isTrue, reason: parsed.errors.join('\n'));
    expect(parsed.trips.single['experiences'], ['trek', 'adventure']);
    expect(parsed.trips.single['isBestseller'], isTrue);
    final old = TripsParser.parseTripsDocument(TripsParser.generateTripsDataJs([{..._trip(), 'experience': 'beach'}])).trips.single;
    expect(old['experience'], 'beach');
    expect(old.containsKey('experiences'), isFalse);
    expect(old.containsKey('isBestseller'), isFalse);
    expect(TripCardSettings.selectedExperiencesFor(old), ['beach']);
    for (final value in [null, 'trek', ['trek', 'trek'], ['unknown'], [1]]) {
      expect(TripCardSettings.validationErrors({..._trip(), 'experiences': value}), isNotEmpty);
      expect(TripsParser.replaceTripsDataObject(source: 'const tripsData = {};', trips: [{..._trip(), 'experiences': value}]).success, isFalse);
      expect(TripsParser.parseTripsDocument('const tripsData = {a: {experiences: '+jsonEncode(value)+'}};').isValid, isFalse);
    }
    expect(TripCardSettings.validationErrors({..._trip(), 'isBestseller': 'true'}), isNotEmpty);
  });

  test('new card fields round-trip and unmanaged source remains identical', () {
    const source = '// keep prefix\nconst tripsData = {};\n// keep helpers\n';
    final result = TripsParser.replaceTripsDataObject(
      source: source,
      trips: [
        {..._trip(), ..._cardValues},
      ],
    );
    expect(result.success, isTrue, reason: result.errors.join('\n'));
    expect(result.content, startsWith('// keep prefix\nconst tripsData = '));
    expect(result.content, endsWith(';\n// keep helpers\n'));
    final parsed = TripsParser.parseTripsDocument(result.content!);
    expect(parsed.errors, isEmpty);
    for (final entry in _cardValues.entries) {
      expect(parsed.trips.single[entry.key], entry.value);
    }
  });

  test('legacy absence, explicit blanks and cover fallback are preserved', () {
    final legacy = _trip()..['image'] = 'images/trips/poster.jpg';
    final source = TripsParser.generateTripsDataJs([legacy]);
    final parsed = TripsParser.parseTripsDocument(source);
    for (final field in TripCardSettings.optionalFields) {
      expect(parsed.trips.single.containsKey(field), isFalse);
      expect(source, isNot(contains('$field:')));
    }
    expect(TripCardSettings.coverFor(legacy), legacy['image']);
    expect(TripCardSettings.experienceFor(legacy), 'other');
    final blank = {
      ...legacy,
      'cardImage': '',
      'cardSummary': '',
      'departureCity': '',
    };
    expect(TripCardSettings.coverFor(blank), legacy['image']);
    expect(
      TripsParser.parseTripsDocument(
        TripsParser.generateTripsDataJs([blank]),
      ).trips.single['cardImage'],
      '',
    );
    expect(
      TripCardSettings.coverFor({...legacy, ..._cardValues}),
      _cardValues['cardImage'],
    );
  });

  test(
    'unsupported card types, values, lengths and unsafe URLs block publication',
    () {
      final invalid = <String, List<Object?>>{
        'cardImage': [
          null,
          true,
          3,
          'javascript:alert(1)',
          'images/../secret',
          'http://example.com/photo.jpg',
          ' images/trips/cover.jpg ',
          'https://user:pass@example.com/x',
          'images/a.jpg")',
        ],
        'cardSummary': [null, [], List.filled(161, 'x').join()],
        'departureCity': [null, 1, List.filled(81, 'x').join()],
        'experience': [null, 'mountain', '', ' trek ', 1],
      };
      for (final entry in invalid.entries) {
        for (final value in entry.value) {
          final changed = _trip()..[entry.key] = value;
          final result = TripsParser.replaceTripsDataObject(
            source: 'const tripsData = {};',
            trips: [changed],
          );
          expect(result.success, isFalse, reason: '${entry.key}=$value');
          expect(result.errors.join(), contains(entry.key));
          final incoming = TripsParser.parseTripsDocument(
            'const tripsData = {a: {${entry.key}: ${jsonEncode(value)}}};',
          );
          expect(incoming.isValid, isFalse, reason: '${entry.key}=$value');
        }
      }
      for (final value in TripCardSettings.experiences.keys) {
        expect(TripCardSettings.fieldError('experience', value), isNull);
      }
      expect(
        TripCardSettings.fieldError(
          'cardImage',
          'https://example.com/cover.webp?width=800',
        ),
        isNull,
      );
      expect(
        TripCardSettings.fieldError(
          'cardSummary',
          ' ${List.filled(160, 'x').join()} ',
        ),
        isNull,
      );
    },
  );

  test(
    'content warnings are advisory, current-date-aware and never mutate data',
    () {
      final trip = {
        ..._trip(),
        'title': List.filled(90, 'x').join(),
        'availableDates': ['Aug 1-2, 2026'],
        'thingsToCarry': [List.filled(200, 'x').join()],
      };
      final before = jsonEncode(trip);
      final warnings = TripCardSettings.qualityWarnings(
        trip,
        referenceDate: _reference,
      );
      expect(warnings, hasLength(4));
      expect(jsonEncode(trip), before);
      expect(
        TripCardSettings.qualityWarnings({
          ...trip,
          'isActive': false,
        }, referenceDate: _reference).join(),
        isNot(contains('No current')),
      );
      expect(
        TripCardSettings.qualityWarnings({
          ..._trip(),
          ..._cardValues,
        }, referenceDate: _reference),
        isEmpty,
      );
    },
  );

  test(
    'fake atomic publication merges optional metadata with remote changes',
    () async {
      final base = [_trip()];
      final github = publication.FakeGitHubService()
        ..queueSnapshot(
          base,
          tripsSha: 'base-trips',
          featuredSha: 'base-featured',
        )
        ..queueSnapshot(
          [
            {...base.single, 'price': '₹2,000', 'departureCity': 'Mysuru'},
          ],
          tripsSha: 'latest-trips',
          featuredSha: 'latest-featured',
        );
      final provider = publication.providerFor(github);
      await provider.loadTrips();
      provider.updateTrip(0, {
        ...provider.trips.single,
        'cardImage': _cardValues['cardImage'],
        'cardSummary': _cardValues['cardSummary'],
        'experience': 'getaway',
      });
      final result = await provider.saveTrips();
      expect(result.success, isTrue, reason: result.error);
      expect(github.atomicCalls.single.files.keys, {
        publication.tripsPath,
        publication.featuredPath,
      });
      final saved = TripsParser.parseTripsDocument(
        github.atomicCalls.single.files[publication.tripsPath]!,
      );
      expect(saved.errors, isEmpty);
      expect(saved.trips.single['price'], '₹2,000');
      expect(saved.trips.single['departureCity'], 'Mysuru');
      expect(saved.trips.single['cardSummary'], _cardValues['cardSummary']);
    },
  );

  test(
    'true card field conflicts retain local edits and create no commit',
    () async {
      final base = [
        {..._trip(), ..._cardValues},
      ];
      final github = publication.FakeGitHubService()
        ..queueSnapshot(base, tripsSha: 'base', featuredSha: 'featured')
        ..queueSnapshot(
          [
            {...base.single, 'cardSummary': 'Remote highlight'},
          ],
          tripsSha: 'latest',
          featuredSha: 'latest-featured',
        );
      final provider = publication.providerFor(github);
      await provider.loadTrips();
      provider.updateTrip(0, {
        ...provider.trips.single,
        'cardSummary': 'My highlight',
      });
      final result = await provider.saveTrips();
      expect(result.success, isFalse);
      expect(result.error, contains('cardSummary'));
      expect(github.atomicCalls, isEmpty);
      expect(provider.trips.single['cardSummary'], 'My highlight');
    },
  );

  test(
    'legacy homepage gets discovery defaults with strict boolean validation',
    () {
      final legacy = HomepageConfig.initial().toJson()..remove('discovery');
      final parsed = HomepageConfig.parse(jsonEncode(legacy));
      expect(parsed.toJson()['discovery'], {
        'enabled': true,
        'showSearch': true,
        'showExperienceFilter': true,
        'showWeekendFilter': true,
      });
      for (final edit in <void Function(Map<String, dynamic>)>[
        (data) => data['discovery'] = [],
        (data) => data['discovery']['showSearch'] = 'true',
        (data) => data['discovery']['unknown'] = true,
        (data) => data['discovery']['enabled'] = null,
      ]) {
        final data = parsed.toJson();
        edit(data);
        expect(
          () => HomepageConfig.parse(jsonEncode(data)),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'fake homepage publication merges discovery without changing trip files',
    () async {
      final base = homepage.config();
      final remote = homepage.config(
        (data) => data['hero']['title'] = 'Remote headline',
      );
      final github = homepage.MemoryGitHub([
        homepage.file(base),
        homepage.file(remote, 'latest'),
      ]);
      final service = HomepageSettingsService(github);
      await service.load();
      final draft = homepage.config(
        (data) => data['discovery']['showWeekendFilter'] = false,
      );
      final result = await service.save(draft);
      expect(result.success, isTrue, reason: result.error);
      expect(github.calls.single.keys, [HomepageSettingsService.path]);
      final saved = HomepageConfig.parse(
        github.calls.single.values.single,
      ).toJson();
      expect(saved['discovery']['showWeekendFilter'], isFalse);
      expect(saved['hero']['title'], 'Remote headline');
    },
  );

  test('homepage preserves explicitly authored whyUs content', () {
    final data = HomepageConfig.initial().toJson();
    data['sections']['whyUs']['items'][1]['title'] = 'My own package promise';
    data['sections']['whyUs']['items'][1]['text'] =
        'Read this trip’s exact inclusions.';
    final parsed = HomepageConfig.parse(jsonEncode(data)).toJson();
    expect(
      parsed['sections']['whyUs']['items'][1]['title'],
      'My own package promise',
    );
    expect(
      parsed['sections']['whyUs']['items'][1]['text'],
      'Read this trip’s exact inclusions.',
    );
  });


  Future<TripsProvider> openEditor(
    WidgetTester tester, {
    bool dark = false,
    Future<String?> Function()? uploader,
  }) async {
    tester.view.physicalSize = const Size(411, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final trip = _trip();
    final provider = TripsProvider(AppSettings())..addTrip(trip);
    provider.markChangesSaved();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TripsProvider>.value(value: provider),
          ChangeNotifierProvider<SettingsProvider>(
            create: (_) => SettingsProvider(store: _MemoryStore()),
          ),
        ],
        child: MaterialApp(
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          home: TripEditScreen(
            trip: trip,
            referenceDate: _reference,
            cardCoverUploader: uploader,
            cardImagePreviewBuilder: (path) =>
                SizedBox(height: 140, child: Text('Photo: $path')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return provider;
  }

  Future<void> save(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final button = find.descendant(
      of: find.byType(AppBar),
      matching: find.byWidgetPredicate((widget) => widget is TextButton),
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(button.hitTestable(), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> showKey(WidgetTester tester, Finder finder) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        400,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 80,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    expect(finder.hitTestable(), findsOneWidget);
  }

  testWidgets('legacy trip save does not populate optional card defaults', (
    tester,
  ) async {
    final provider = await openEditor(tester);
    await save(tester);
    for (final field in TripCardSettings.optionalFields) {
      expect(provider.trips.single.containsKey(field), isFalse, reason: field);
    }
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'card edits, cover upload and preview stay draft-only (${dark ? 'dark' : 'light'})',
      (tester) async {
        var uploads = 0;
        final provider = await openEditor(
          tester,
          dark: dark,
          uploader: () async {
            uploads++;
            return 'images/trips/new-cover.webp';
          },
        );
        for (final entry in {
          'cardSummary': '  Coffee and waterfalls  ',
          'departureCity': ' Bengaluru ',
        }.entries) {
          final input = find.byKey(ValueKey('trip-card-${entry.key}'));
          await tester.ensureVisible(input);
          await tester.enterText(input, entry.value);
          await tester.pump();
        }
        for (final key in ['beach', 'adventure']) {
          final category = find.byKey(ValueKey('trip-card-experience-${key}'));
          await tester.ensureVisible(category);
          await tester.tap(category);
          await tester.pumpAndSettle();
        }
        final bestseller = find.byKey(const Key('trip-card-bestseller'));
        await tester.ensureVisible(bestseller);
        await tester.tap(bestseller);
        await tester.pumpAndSettle();
        final upload = find.byKey(const Key('trip-card-upload'));
        await tester.ensureVisible(upload);
        await tester.tap(upload);
        await tester.pumpAndSettle();
        expect(uploads, 1);
        expect(provider.hasUnsavedChanges, isFalse);
        final preview = find.byKey(const Key('trip-card-preview'));
        expect(
          find.descendant(
            of: preview,
            matching: find.text('Coffee and waterfalls'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: preview,
            matching: find.text('Photo: images/trips/new-cover.webp'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: preview, matching: find.text('Beaches')),
          findsOneWidget,
        );
        await save(tester);
        expect(
          provider.trips.single['cardImage'],
          'images/trips/new-cover.webp',
        );
        expect(provider.trips.single['cardSummary'], 'Coffee and waterfalls');
        expect(provider.trips.single['departureCity'], 'Bengaluru');
        expect(provider.trips.single.containsKey('experience'), isFalse);
        expect(provider.trips.single['experiences'], ['beach', 'adventure']);
        expect(provider.trips.single['isBestseller'], isTrue);
        expect(provider.trips.single['image'], '');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('preview reflects unsaved destination and difficulty edits', (
    tester,
  ) async {
    final provider = await openEditor(tester);
    final destination = find.widgetWithText(TextFormField, 'Destination *');
    await tester.enterText(destination, 'Coorg, Karnataka');
    await tester.pump();
    final difficulty = find.ancestor(
      of: find.text('Difficulty'),
      matching: find.byType(DropdownButtonFormField<String>),
    );
    await tester.ensureVisible(difficulty);
    await tester.tap(difficulty);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Challenging').last);
    await tester.pumpAndSettle();
    final preview = find.byKey(const Key('trip-card-preview'));
    expect(
      find.descendant(of: preview, matching: find.text('Coorg, Karnataka')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: preview,
        matching: find.textContaining('Challenging'),
      ),
      findsOneWidget,
    );
    expect(provider.hasUnsavedChanges, isFalse);
    expect(provider.trips.single['location'], 'Karnataka');
    expect(provider.trips.single['difficulty'], 'Easy');
    expect(TripCardSettings.experiences['other'], 'Other experiences');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'invalid optional fields block editor save, not just publication',
    (tester) async {
      final provider = await openEditor(tester);
      final input = find.byKey(const Key('trip-card-cardSummary'));
      await tester.ensureVisible(input);
      await tester.enterText(input, List.filled(161, 'x').join());
      await save(tester);
      expect(
        find.descendant(of: find.byType(SnackBar), matching: find.text('Card summary must be at most 160 characters.')),
        findsOneWidget,
      );
      expect(provider.hasUnsavedChanges, isFalse);
      expect(provider.trips.single.containsKey('cardSummary'), isFalse);
    },
  );

  testWidgets(
    'unsupported loaded experience is fixable without a dropdown crash',
    (tester) async {
      final trip = {..._trip(), 'experience': 'new-website-category'};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              child: SingleChildScrollView(
                child: TripCardSettingsEditor(
                  trip: trip,
                  referenceDate: _reference,
                  onChanged: (field, value) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.state<FormState>(find.byType(Form)).validate(), isFalse);
      await tester.pump();
      expect(find.text('Choose a supported experience.'), findsOneWidget);
    },
  );

  testWidgets('discovery switches retain child choices while disabled', (
    tester,
  ) async {
    final draft = Map<String, dynamic>.from(
      HomepageConfig.initial().toJson()['discovery'] as Map,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => DiscoverySettingsEditor(
              discovery: draft,
              onChanged: (field, value) => setState(() => draft[field] = value),
            ),
          ),
        ),
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('homepage-discovery-showWeekendFilter')),
    );
    await tester.pumpAndSettle();
    expect(draft['showWeekendFilter'], isFalse);
    await tester.tap(find.byKey(const ValueKey('homepage-discovery-enabled')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('homepage-discovery-showSearch')),
          )
          .onChanged,
      isNull,
    );
    expect(draft['showSearch'], isTrue);
    await tester.tap(find.byKey(const ValueKey('homepage-discovery-enabled')));
    await tester.pumpAndSettle();
    expect(draft['showWeekendFilter'], isFalse);
  });

  testWidgets('homepage screen publishes discovery with a fake GitHub client', (
    tester,
  ) async {
    final settings = SettingsProvider(store: _MemoryStore());
    await settings.init();
    await settings.saveSettings(AppSettings(githubToken: 'fixture'));
    final github = homepage.MemoryGitHub([
      homepage.file(homepage.config()),
      homepage.file(
        homepage.config((data) => data['hero']['title'] = 'Remote headline'),
        'latest',
      ),
    ]);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          home: HomepageSettingsScreen(
            service: HomepageSettingsService(github),
            trips: [_trip()],
            referenceDate: _reference,
            imagePreviewBuilder: (_) => const SizedBox(height: 140),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final weekend = find.byKey(
      const ValueKey('homepage-discovery-showWeekendFilter'),
    );
    await showKey(tester, weekend);
    await tester.tap(weekend);
    await tester.pumpAndSettle();
    final publish = find.byKey(const Key('homepage-publish'));
    await showKey(tester, publish);
    await tester.tap(publish);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await tester.pumpAndSettle();
    expect(github.calls.single.keys, [HomepageSettingsService.path]);
    final saved = HomepageConfig.parse(
      github.calls.single.values.single,
    ).toJson();
    expect(saved['discovery']['showWeekendFilter'], isFalse);
    expect(saved['hero']['title'], 'Remote headline');
    expect(find.text('Homepage settings published.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'statistics Google rating uses the shared reviews value without altering legacy data',
    (tester) async {
      final sections =
          HomepageConfig.initial().toJson()['sections'] as Map<String, dynamic>;
      final stats = sections['stats']['items'] as List;
      final rating = stats.firstWhere((item) => item['id'] == 'rating') as Map;
      final original = rating['value'];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: HomepageSectionsEditor(
                  sections: sections,
                  onChanged: () => setState(() {}),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final statsSection = find.byKey(const ValueKey('homepage-section-stats'));
      await showKey(tester, statsSection);
      await tester.tap(statsSection);
      await tester.pumpAndSettle();
      final ratingItem = find.byKey(
        const PageStorageKey('details-section-stats-rating'),
      );
      await showKey(tester, ratingItem);
      await tester.tap(ratingItem);
      await tester.pumpAndSettle();
      final shared = find.byKey(
        const ValueKey('section-stats-rating-shared-rating'),
      );
      expect(shared, findsOneWidget);
      expect(
        find.byKey(const ValueKey('section-stats-rating-value')),
        findsNothing,
      );
      expect(
        tester.widget<Text>(shared).data,
        'Google rating: ${sections['reviews']['rating']}⭐',
      );
      final reviewsSection = find.byKey(
        const ValueKey('homepage-section-reviews'),
      );
      await showKey(tester, reviewsSection);
      await tester.tap(reviewsSection);
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('section-reviews-rating'));
      await showKey(tester, input);
      await tester.enterText(input, '4.7');
      await tester.pump();
      expect(tester.widget<Text>(shared).data, 'Google rating: 4.7⭐');
      expect(rating['value'], original);
      expect(tester.takeException(), isNull);
    },
  );

  if (!Platform.isAndroid) {
    for (final dark in [false, true]) {
      testWidgets('mobile card preview golden ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 560);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: Scaffold(
              body: Center(
                child: TripCardPreview(
                  trip: {..._trip(), ..._cardValues},
                  referenceDate: _reference,
                  imagePreviewBuilder: (_) => const SizedBox(
                    height: 140,
                    child: Center(child: Icon(Icons.landscape, size: 64)),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(Scaffold),
          platformGolden('goldens/trip_card_${dark ? 'dark' : 'light'}.png'),
        );
      });
    }
  }
}

class _MemoryStore implements SettingsStore {
  @override
  Future<void> init() async {}
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> clear() async {}
}
