import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/services/pickup_library.dart';
import 'package:trip_manager_app/services/trips_parser.dart';
import 'package:trip_manager_app/widgets/pickup_library_dialog.dart';

Map<String, dynamic> point([String time = '9:00 PM']) => {
  'name': 'Hebbal',
  'landmark': 'Esteem Mall',
  'time': time,
  'mapLink': 'https://maps.app.goo.gl/example',
};

void main() {
  test(
    'catalogue deduplicates exact points but retains time variants and sources',
    () {
      final entries = buildPickupLibrary([
        {
          'title': 'North trip',
          'boardingLocations': [point(), point()],
        },
        {
          'title': 'Other trip',
          'boardingLocations': [
            {...point(), 'name': ' HEBBAL '},
            point('10:00 PM'),
          ],
        },
        {'title': 'Default trip', 'boardingLocations': []},
      ]);
      final hebbal = entries.where((e) => e.matches('hebbal')).toList();
      expect(hebbal, hasLength(2));
      expect(hebbal.firstWhere((e) => e.point['time'] == '9:00 PM').trips, {
        'North trip',
        'Other trip',
      });
      expect(
        entries.where((e) => e.trips.contains('Default trip')),
        hasLength(4),
      );
      expect(hebbal.every((e) => e.matches('Other trip')), isTrue);
    },
  );

  test(
    'copying preserves order, avoids duplicates and isolates edits from source trips',
    () {
      final original = point();
      final existing = TripsParser.getDefaultPickupPoints();
      final copied = mergePickupPoints(existing, [original, original]);
      expect(copied, hasLength(5));
      copied.last['time'] = '8:00 PM';
      copied.first['name'] = 'Changed locally';
      expect(original['time'], '9:00 PM');
      expect(existing.first['name'], 'Majestic');
      expect(
        mergePickupPoints(copied, [Map<String, dynamic>.from(copied.last)]),
        hasLength(5),
      );
    },
  );

  test(
    'malformed source map URLs are flagged and not spread to other trips',
    () {
      final bad = {
        ...point(),
        'mapLink': 'https://https://maps.app.goo.gl/broken',
      };
      expect(safePickupMapLink(bad['mapLink']), '');
      expect(mergePickupPoints([], [bad]).single['mapLink'], '');
      expect(bad['mapLink'], contains('https://https'));
      expect(
        safePickupMapLink(' https://maps.app.goo.gl/example '),
        'https://maps.app.goo.gl/example',
      );
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'phone chooser searches, preserves selections and copies independently, dark=$dark',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 800);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final entries = buildPickupLibrary([
          {
            'title': 'North trip',
            'boardingLocations': [
              point(),
              {...point(), 'name': 'Airport'},
            ],
          },
        ]);
        List<Map<String, dynamic>>? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async =>
                      result = await showDialog<List<Map<String, dynamic>>>(
                        context: context,
                        builder: (_) => PickupLibraryDialog(
                          entries: entries,
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
        await tester.enterText(
          find.byKey(const Key('pickup-library-search')),
          'North trip',
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Hebbal'),
          100,
          scrollable: find
              .descendant(
                of: find.byKey(const Key('pickup-library-list')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(
          find.ancestor(
            of: find.text('Hebbal'),
            matching: find.byType(CheckboxListTile),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hebbal'));
        await tester.pumpAndSettle();
        expect(find.text('Add 1 point'), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('pickup-library-search')),
          'Airport',
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Airport').last,
          100,
          scrollable: find
              .descendant(
                of: find.byKey(const Key('pickup-library-list')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(
          find.ancestor(
            of: find.text('Airport').last,
            matching: find.byType(CheckboxListTile),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Airport').last);
        await tester.pumpAndSettle();
        expect(find.text('Add 2 points'), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('pickup-library-search')),
          'not found',
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('No matching pickup points.'),
          findsOneWidget,
        );
        expect(find.text('Add 2 points'), findsOneWidget);
        await tester.tap(find.byKey(const Key('pickup-library-add')));
        await tester.pumpAndSettle();
        expect(result, hasLength(6));
        expect(result!.skip(4).map((p) => p['name']), ['Hebbal', 'Airport']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'cancel does not change a trip and enlarged text fits with keyboard',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 800);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final original = [point()];
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
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => PickupLibraryDialog(
                    entries: buildPickupLibrary([]),
                    current: original,
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
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(original.single, point());
    },
  );
}
