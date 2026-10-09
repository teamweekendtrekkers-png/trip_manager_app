import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/providers/settings_provider.dart';
import 'package:trip_manager_app/providers/trips_provider.dart';
import 'package:trip_manager_app/screens/trip_edit_screen.dart';
import 'package:trip_manager_app/services/trip_detail_defaults.dart';
import 'package:trip_manager_app/services/trips_parser.dart';

Map<String, dynamic> _trip() => {
  'id': 'custom-trip',
  'title': 'Custom trip',
  'location': 'Karnataka',
  'about': 'A weekend away.',
  'price': '₹999',
  'image': '',
  'difficulty': 'Moderate',
  'availableDates': <String>[],
  'thingsToCarry': <String>['Raincoat', 'Power bank'],
  'perfectFor': <String>['Couples', 'Photographers'],
};

void main() {
  test('custom sections round-trip without changing unmanaged website code', () {
    const source = '''// custom prefix
const tripsData = {
  custom: {
    title: "Custom trip",
    thingsToCarry: ["Raincoat", "Water & snacks", "Shoes 🥾"],
    perfectFor: ["Couples", "Photographers' groups", "<script>text</script>"]
  }
};
// untouched helper
const commonRules = ["Keep this exactly"];
''';
    final parsed = TripsParser.parseTripsDocument(source);
    expect(parsed.errors, isEmpty);
    final trip = parsed.trips.single;
    expect(trip['perfectFor'], [
      'Couples',
      "Photographers' groups",
      '<script>text</script>',
    ]);
    trip['thingsToCarry'] = <String>['Warm clothes', 'Torch'];
    trip['perfectFor'] = <String>['Families', 'First Timers'];
    final written = TripsParser.replaceTripsDataObject(
      source: source,
      trips: [trip],
    );
    expect(written.success, isTrue, reason: written.errors.join('\n'));
    expect(written.content, startsWith('// custom prefix\nconst tripsData = '));
    expect(
      written.content,
      endsWith(
        '};\n// untouched helper\nconst commonRules = ["Keep this exactly"];\n',
      ),
    );
    final reparsed = TripsParser.parseTripsDocument(written.content!);
    expect(reparsed.errors, isEmpty);
    expect(reparsed.trips.single['perfectFor'], ['Families', 'First Timers']);
    expect(reparsed.trips.single['thingsToCarry'], ['Warm clothes', 'Torch']);
  });

  test('legacy field absence and explicit empty defaults are preserved', () {
    final legacy = TripsParser.parseTripsDocument(
      'const tripsData = { old: {title: "Old", thingsToCarry: []} };',
    );
    final source = TripsParser.generateTripsDataJs(legacy.trips);
    expect(source, isNot(contains('perfectFor:')));
    expect(
      TripsParser.parseTripsDocument(source).trips.single['thingsToCarry'],
      isEmpty,
    );
    final empty = _trip()..['perfectFor'] = <String>[];
    final parsed = TripsParser.parseTripsDocument(
      TripsParser.generateTripsDataJs([empty]),
    );
    expect(parsed.trips.single['perfectFor'], isEmpty);
  });

  test('wrong types in either customizable list block publication', () {
    for (final field in ['perfectFor', 'thingsToCarry']) {
      for (final value in [
        'bad',
        <dynamic>[1],
        <dynamic>[
          {'label': 'Bad'},
        ],
        null,
      ]) {
        final trip = _trip()..[field] = value;
        final result = TripsParser.replaceTripsDataObject(
          source: 'const tripsData = {};',
          trips: [trip],
        );
        expect(result.success, isFalse);
        expect(result.content, isNull);
        expect(result.errors.join(), contains(field));
      }
    }
  });

  Future<TripsProvider> openEditor(
    WidgetTester tester, {
    bool darkMode = false,
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
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
          home: TripEditScreen(trip: trip, index: 0),
        ),
      ),
    );
    return provider;
  }

  Finder section(String field) =>
      find.byKey(ValueKey('trip-detail-list-$field'));

  Future<void> showSection(WidgetTester tester, String field) async {
    await tester.ensureVisible(section(field));
    await tester.pumpAndSettle();
  }

  Future<void> saveEditor(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.save),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('edits, adds and removes audience tags and saves both lists', (
    tester,
  ) async {
    final provider = await openEditor(tester);
    await showSection(tester, 'perfectFor');
    await tester.tap(
      find
          .descendant(
            of: section('perfectFor'),
            matching: find.byIcon(Icons.edit),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Families',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: section('perfectFor'),
        matching: find.byIcon(Icons.add_circle),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Corporate teams',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: section('perfectFor'),
            matching: find.byIcon(Icons.delete),
          )
          .at(1),
    );
    await tester.pumpAndSettle();
    expect(provider.hasUnsavedChanges, isFalse);
    expect(provider.trips.single['perfectFor'], ['Couples', 'Photographers']);
    await saveEditor(tester);
    expect(provider.trips.single['perfectFor'], [
      'Families',
      'Corporate teams',
    ]);
    expect(provider.trips.single['thingsToCarry'], ['Raincoat', 'Power bank']);
    final reparsed = TripsParser.parseTripsDocument(
      TripsParser.generateTripsDataJs(provider.trips),
    );
    expect(reparsed.errors, isEmpty);
    expect(reparsed.trips.single['perfectFor'], [
      'Families',
      'Corporate teams',
    ]);
  });

  testWidgets(
    'packing editor edits custom items and saves an empty list for defaults',
    (tester) async {
      final provider = await openEditor(tester);
      await showSection(tester, 'thingsToCarry');
      await tester.tap(
        find
            .descendant(
              of: section('thingsToCarry'),
              matching: find.byIcon(Icons.edit),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Warm jacket',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Warm jacket'), findsOneWidget);
      for (var count = 0; count < 2; count++) {
        await tester.tap(
          find
              .descendant(
                of: section('thingsToCarry'),
                matching: find.byIcon(Icons.delete),
              )
              .first,
        );
        await tester.pumpAndSettle();
      }
      await saveEditor(tester);
      expect(provider.trips.single['thingsToCarry'], isEmpty);
      expect(provider.trips.single['perfectFor'], ['Couples', 'Photographers']);
    },
  );

  testWidgets('Use defaults populates both website sections in dark mode', (
    tester,
  ) async {
    final provider = await openEditor(tester, darkMode: true);
    for (final field in ['perfectFor', 'thingsToCarry']) {
      final button = find.byKey(ValueKey('use-defaults-$field'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }
    await saveEditor(tester);
    expect(
      provider.trips.single['thingsToCarry'],
      TripDetailDefaults.thingsToCarry,
    );
    expect(provider.trips.single['perfectFor'], TripDetailDefaults.perfectFor);
  });
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
