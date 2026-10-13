import 'golden_platform.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/models/trip_section_settings.dart';
import 'package:trip_manager_app/providers/settings_provider.dart';
import 'package:trip_manager_app/providers/trips_provider.dart';
import 'package:trip_manager_app/screens/trip_edit_screen.dart';
import 'package:trip_manager_app/services/trips_parser.dart';
import 'package:trip_manager_app/widgets/trip_section_settings_editor.dart';
import 'trip_brochure_test.dart' as brochure;
import 'trips_provider_publication_test.dart' as publication;

Map<String, dynamic> _fixture() => {
  ...publication.trip('section-trip', title: 'Section trip', dates: const []),
  'about': 'A quiet weekend away.',
  'difficulty': 'Moderate',
  'image': '',
  'inclusions': <String>['Transport'],
  'exclusions': <String>['Lunch'],
  'itinerary': <Map<String, dynamic>>[],
  'boardingLocations': <Map<String, dynamic>>[],
};

void main() {
  test(
    'all initial-state combinations round-trip without changing helpers',
    () {
      const source = '// prefix\nconst tripsData = {};\n// keep helpers\n';
      final keys = TripSectionSettings.titles.keys.toList();
      for (var mask = 0; mask < (1 << keys.length); mask++) {
        final expanded = [
          for (var index = 0; index < keys.length; index++)
            if ((mask & (1 << index)) != 0) keys[index],
        ];
        final result = TripsParser.replaceTripsDataObject(
          source: source,
          trips: [
            {..._fixture(), 'expandedSections': expanded},
          ],
        );
        expect(result.success, isTrue, reason: result.errors.join('\n'));
        expect(result.content, startsWith('// prefix\nconst tripsData = '));
        expect(result.content, endsWith(';\n// keep helpers\n'));
        final parsed = TripsParser.parseTripsDocument(result.content!);
        expect(parsed.errors, isEmpty);
        expect(parsed.trips.single['expandedSections'], expanded);
        expect(parsed.trips.single['about'], _fixture()['about']);
        expect(parsed.trips.single['inclusions'], _fixture()['inclusions']);
        expect(parsed.trips.single['exclusions'], _fixture()['exclusions']);
      }
      final legacy = TripsParser.generateTripsDataJs([_fixture()]);
      expect(legacy, isNot(contains('expandedSections:')));
      expect(TripSectionSettings.expandedFor(_fixture()), isEmpty);
    },
  );

  test(
    'invalid, unknown, duplicate and nested preferences block publishing',
    () {
      for (final value in [
        null,
        true,
        'about',
        <String, dynamic>{},
        [1],
        ['unknown'],
        ['about', 'about'],
        [
          ['about'],
        ],
      ]) {
        expect(TripSectionSettings.validationError(value), isNotNull);
        final result = TripsParser.replaceTripsDataObject(
          source: 'const tripsData = {};',
          trips: [
            {..._fixture(), 'expandedSections': value},
          ],
        );
        expect(result.success, isFalse);
        expect(result.content, isNull);
        expect(result.errors.join(), contains('expandedSections'));
      }
      for (final literal in [
        'null',
        'true',
        '"about"',
        '{}',
        '[1]',
        '["unknown"]',
        '["about", "about"]',
      ]) {
        final parsed = TripsParser.parseTripsDocument(
          'const tripsData = {a: {title: "A", expandedSections: $literal}};',
        );
        expect(parsed.isValid, isFalse, reason: literal);
        expect(parsed.errors.join(), contains('expandedSections'));
      }
    },
  );

  test('collapsing sections never changes any brochure content', () {
    final original = brochure.content(brochure.brochure());
    for (final expanded in [
      <String>[],
      TripSectionSettings.titles.keys.toList(),
    ]) {
      final rendered = brochure.brochure({
        ...brochure.fixture(),
        'expandedSections': expanded,
      });
      expect(brochure.content(rendered), original);
    }
  });

  test(
    'atomic fake publication merges display settings with remote price edits',
    () async {
      final base = [_fixture()];
      final service = publication.FakeGitHubService()
        ..queueSnapshot(base, tripsSha: 'base', featuredSha: 'base-featured')
        ..queueSnapshot(
          [
            {...base.single, 'price': '₹4,000'},
          ],
          tripsSha: 'remote',
          featuredSha: 'remote-featured',
        );
      final provider = publication.providerFor(service);
      addTearDown(provider.dispose);
      await provider.loadTrips();
      provider.updateTrip(0, {
        ...provider.trips.single,
        'expandedSections': <String>['about', 'includes'],
      });
      final saved = await provider.saveTrips();
      expect(saved.success, isTrue, reason: saved.error);
      expect(service.atomicCalls, hasLength(1));
      final call = service.atomicCalls.single;
      expect(call.files.keys.toSet(), {
        publication.tripsPath,
        publication.featuredPath,
      });
      expect(
        call.files[publication.tripsPath],
        endsWith('// SOURCE TRIPS SUFFIX\n'),
      );
      final parsed = TripsParser.parseTripsDocument(
        call.files[publication.tripsPath]!,
      );
      expect(parsed.errors, isEmpty);
      expect(parsed.trips.single['expandedSections'], ['about', 'includes']);
      expect(parsed.trips.single['price'], '₹4,000');
    },
  );

  test(
    'conflicting section preferences block without writing either file',
    () async {
      final base = [_fixture()];
      final service = publication.FakeGitHubService()
        ..queueSnapshot(base, tripsSha: 'base', featuredSha: 'base-featured')
        ..queueSnapshot(
          [
            {
              ...base.single,
              'expandedSections': <String>['highlights'],
            },
          ],
          tripsSha: 'remote',
          featuredSha: 'remote-featured',
        );
      final provider = publication.providerFor(service);
      addTearDown(provider.dispose);
      await provider.loadTrips();
      provider.updateTrip(0, {
        ...provider.trips.single,
        'expandedSections': <String>['about'],
      });
      final saved = await provider.saveTrips();
      expect(saved.success, isFalse);
      expect(saved.error, contains('expandedSections'));
      expect(service.atomicCalls, isEmpty);
      expect(provider.hasUnsavedChanges, isTrue);
    },
  );

  Future<TripsProvider> open(WidgetTester tester, {required bool dark}) async {
    tester.view.physicalSize = const Size(411, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final trip = _fixture();
    final provider = TripsProvider(AppSettings())..addTrip(trip);
    provider.markChangesSaved();
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TripsProvider>.value(value: provider),
          ChangeNotifierProvider<SettingsProvider>(
            create: (_) => SettingsProvider(store: _MemoryStore()),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          TripEditScreen(trip: provider.trips.single, index: 0),
                    ),
                  ),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    return provider;
  }

  Future<void> toggle(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey('section-expanded-$key'));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets(
      'draft toggles, cancellation, save and restoration in ${dark ? "dark" : "light"} mode',
      (tester) async {
        final provider = await open(tester, dark: dark);
        await toggle(tester, 'about');
        await toggle(tester, 'includes');
        expect(provider.trips.single.containsKey('expandedSections'), isFalse);
        expect(provider.hasUnsavedChanges, isFalse);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();
        expect(provider.trips.single.containsKey('expandedSections'), isFalse);
        await tester.tap(find.text('Open editor'));
        await tester.pumpAndSettle();
        await toggle(tester, 'highlights');
        await toggle(tester, 'thingsToCarry');
        await tester.tap(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byIcon(Icons.save),
          ),
        );
        await tester.pumpAndSettle();
        expect(provider.trips.single['expandedSections'], [
          'highlights',
          'thingsToCarry',
        ]);
        expect(provider.hasUnsavedChanges, isTrue);
        await tester.tap(find.text('Open editor'));
        await tester.pumpAndSettle();
        final target = find.byKey(
          const ValueKey('section-expanded-highlights'),
        );
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(target).value, isTrue);
        await toggle(tester, 'highlights');
        await toggle(tester, 'thingsToCarry');
        await tester.tap(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byIcon(Icons.save),
          ),
        );
        await tester.pumpAndSettle();
        expect(provider.trips.single['expandedSections'], isEmpty);
        expect(provider.trips.single['about'], _fixture()['about']);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('section display ${dark ? "dark" : "light"} golden', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(411, 650);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          home: Scaffold(
            body: SafeArea(
              child: TripSectionSettingsEditor(
                expandedSections: const ['about'],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(Scaffold),
        platformGolden(
          'goldens/trip_sections_${dark ? "dark" : "light"}.png',
        ),
      );
    }, skip: Platform.isAndroid);
  }

  testWidgets(
    'saving unrelated editor fields keeps legacy preferences absent',
    (tester) async {
      final provider = await open(tester, dark: false);
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.save),
        ),
      );
      await tester.pumpAndSettle();
      expect(provider.trips.single.containsKey('expandedSections'), isFalse);
    },
  );
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
