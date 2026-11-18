import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/services/carry_library.dart';
import 'package:trip_manager_app/widgets/carry_library_dialog.dart';

void main() {
  test(
    'all trips and standard items are searchable without merging distinct advice',
    () {
      final library = buildCarryLibrary([
        {
          'title': 'Coastal trip',
          'thingsToCarry': [
            'Raincoat',
            ' Water bottle ',
            'Water bottle — 2 litres',
          ],
        },
        {
          'title': 'Hill trip',
          'thingsToCarry': ['**RAINCOAT**', '**Thermal jacket**'],
        },
        {'title': 'Empty trip', 'thingsToCarry': []},
        {'title': 'Legacy trip'},
      ]);
      expect(library.where((e) => e.id == 'raincoat'), hasLength(1));
      expect(library.firstWhere((e) => e.id == 'raincoat').trips, {
        'Coastal trip',
        'Hill trip',
      });
      expect(library.where((e) => e.trips.contains('Empty trip')), isEmpty);
      expect(
        library.where((e) => e.trips.contains('Legacy trip')),
        hasLength(8),
      );
      expect(
        library
            .firstWhere((e) => e.id == 'thermal jacket')
            .matches('thermal jacket'),
        isTrue,
      );
    },
  );

  test(
    'legacy bullet checklists split without losing their words or source text',
    () {
      final text =
          'Trip Packing Checklist ' +
          [
            'Backpack',
            'Water bottle',
            'Raincoat',
            'Trekking shoes',
            'Personal medicines',
            'Toiletries',
            'Zip-lock bags',
          ].map((s) => '• $s — pack safely for this destination ').join();
      final parts = splitCarryChecklist(text);
      expect(parts, hasLength(8));
      expect(
        parts.join().replaceAll(RegExp(r'\s+'), ''),
        text.replaceAll(RegExp(r'\s+'), ''),
      );
      final prose = List.filled(
        25,
        'A careful packing note without bullet items.',
      ).join(' ');
      expect(splitCarryChecklist(prose), [prose]);
      final library = buildCarryLibrary([
        {
          'title': 'Source trek',
          'thingsToCarry': [text],
        },
      ]);
      expect(
        library.where((e) => e.text.contains('Trip Packing Checklist')),
        isEmpty,
      );
      expect(mergeCarryItems([text], [parts[1]]), [text]);
    },
  );

  test('emoji lists expose individual items without source headings', () {
    const text =
        '🎒 Things to Carry — Hill Trek 🥾 Trekking Shoes — Good grip for the trail 🎒 Backpack — Comfortable daypack for this trip 💧 Water Bottle — Carry at least two litres on the trail 🧥 Raincoat — Keep dry during unpredictable weather';
    expect(splitCarryChecklist(text), hasLength(5));
    final source = {
      'title': 'Hill Trek',
      'thingsToCarry': [text],
    };
    expect(
      buildCarryLibrary([source]).where((e) => e.trips.contains('Hill Trek')),
      hasLength(4),
    );
    expect(source['thingsToCarry'], [text]);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'phone supports cross-search selection, select results and existing items, dark=$dark',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 800);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final current = ['Raincoat'];
        final entries = buildCarryLibrary([
          {
            'title': 'Winter trip',
            'thingsToCarry': ['Raincoat', '**Thermal jacket**', 'Torch'],
          },
        ]);
        List<String>? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async =>
                      result = await showDialog<List<String>>(
                        context: context,
                        builder: (_) => CarryLibraryDialog(
                          entries: entries,
                          current: current,
                        ),
                      ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('carry-library-search')),
          'Winter trip',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('carry-select-results')));
        await tester.pumpAndSettle();
        expect(find.text('Add 2 items'), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('carry-library-search')),
          'nothing matching',
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('No matching items.'), findsOneWidget);
        expect(find.text('Add 2 items'), findsOneWidget);
        await tester.tap(find.byKey(const Key('carry-library-add')));
        await tester.pumpAndSettle();
        expect(result, ['Raincoat', '**Thermal jacket**', 'Torch']);
        expect(current, ['Raincoat']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'empty lists remain empty on cancel with larger text and keyboard',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 800);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      List<String>? result;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => result = await showDialog<List<String>>(
                  context: context,
                  builder: (_) => CarryLibraryDialog(
                    entries: buildCarryLibrary([]),
                    current: const [],
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('carry-library-add')))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    },
  );
}
