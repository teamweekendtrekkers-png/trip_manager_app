import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:trip_manager_app/services/draft_store.dart';
import 'package:trip_manager_app/services/carry_library.dart';
import 'package:trip_manager_app/services/pickup_library.dart';
import 'package:trip_manager_app/services/reusable_library_store.dart';
import 'package:trip_manager_app/widgets/carry_library_dialog.dart';
import 'package:trip_manager_app/widgets/library_manager_dialog.dart';

void main() {
  test(
    'library edits, additions, hides and restores persist by repository and kind',
    () async {
      final directory = await Directory(
        'build/library-tests',
      ).create(recursive: true).then((d) => d.createTemp());
      Hive.init(directory.path);
      await DraftStore.init();
      try {
        final source = {
          'title': 'Hill trip',
          'thingsToCarry': ['Raincoat'],
        };
        final base = buildCarryLibrary([source]);
        final store = ReusableLibraryStore(
          kind: 'carry',
          scope: 'repository-A',
        );
        final changes = store.load();
        changes.values['raincoat'] = {'text': '**Warm raincoat**'};
        changes.values['custom:one'] = {'text': 'Headlamp'};
        changes.hidden.add('water bottle');
        await store.save(changes);
        await DraftStore.close();
        await DraftStore.init();
        final reopened = ReusableLibraryStore(
          kind: 'carry',
          scope: 'repository-A',
        );
        expect(
          resolveCarryLibrary(
            base,
            reopened,
          ).any((e) => e.text == '**Warm raincoat**'),
          isTrue,
        );
        expect(
          resolveCarryLibrary(base, reopened).any((e) => e.text == 'Headlamp'),
          isTrue,
        );
        expect(
          resolveCarryLibrary(
            base,
            reopened,
          ).any((e) => e.id == 'water bottle'),
          isFalse,
        );
        expect(source['thingsToCarry'], ['Raincoat']);
        expect(
          ReusableLibraryStore(
            kind: 'carry',
            scope: 'repository-B',
          ).load().values,
          isEmpty,
        );
        expect(
          ReusableLibraryStore(
            kind: 'pickup',
            scope: 'repository-A',
          ).load().values,
          isEmpty,
        );
        final restored = reopened.load()..hidden.remove('water bottle');
        await reopened.save(restored);
        expect(
          resolveCarryLibrary(
            base,
            reopened,
          ).any((e) => e.id == 'water bottle'),
          isTrue,
        );
      } finally {
        await DraftStore.close();
        expect(
          directory.absolute.path.startsWith(
            '${Directory.current.absolute.path}${Platform.pathSeparator}',
          ),
          isTrue,
        );
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'pickup overrides are independent and deduplicated before reuse',
    () async {
      final original = <String, dynamic>{
        'name': 'Hebbal',
        'landmark': 'Mall',
        'time': '9 PM',
        'mapLink': '',
      };
      final entries = buildPickupLibrary([
        {
          'title': 'North trip',
          'boardingLocations': [original],
        },
      ]);
      final store = ReusableLibraryStore.memory('pickup'),
          changes = LibraryChanges();
      changes.values[pickupIdentity(original)] = {...original, 'time': '10 PM'};
      changes.values['custom:duplicate'] = {...original, 'time': '10 PM'};
      await store.save(changes);
      final resolved = resolvePickupLibrary(
        entries,
        store,
      ).where((e) => e.point['name'] == 'Hebbal').toList();
      expect(resolved, hasLength(1));
      expect(resolved.single.point['time'], '10 PM');
      expect(original['time'], '9 PM');
      final hidden = store.load()
        ..hidden.add(pickupIdentity(resolved.single.point));
      await store.save(hidden);
      expect(
        resolvePickupLibrary(
          entries,
          store,
        ).where((e) => e.point['name'] == 'Hebbal'),
        isEmpty,
      );
    },
  );

  test('unavailable storage never claims to save a library edit', () async {
    await DraftStore.close();
    final store = ReusableLibraryStore(kind: 'carry', scope: 'unavailable');
    await expectLater(
      store.save(
        LibraryChanges(
          values: {
            'custom:one': {'text': 'Torch'},
          },
        ),
      ),
      throwsStateError,
    );
    expect(store.load().values, isEmpty);
  });

  testWidgets('library management stays usable with enlarged phone text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.runAsync(() async {
      final sdk = Platform.environment['FLUTTER_ROOT'];
      if (sdk == null) return;
      for (final entry in {
        'Roboto': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf',
      }.entries) {
        final file = File(
          '$sdk/bin/cache/artifacts/material_fonts/${entry.value}',
        );
        if (!file.existsSync()) continue;
        await (FontLoader(entry.key)..addFont(
              Future.value(ByteData.sublistView(file.readAsBytesSync())),
            ))
            .load();
      }
    });
    const preview = Key('library-preview');
    await tester.pumpWidget(
      RepaintBoundary(
        key: preview,
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'Roboto'),
          builder: (_, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 844),
              textScaler: TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: LibraryManagerDialog(
            store: ReusableLibraryStore.memory('carry'),
            base: carryRecords(
              buildCarryLibrary([
                {
                  'title': 'Hill trip',
                  'thingsToCarry': ['Warm waterproof jacket'],
                },
              ]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('library-manager-save')).hitTestable(),
      findsOneWidget,
    );
    await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(find.byKey(preview))
          .toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      Directory('build/reviews').createSync(recursive: true);
      File(
        'build/reviews/library-manager-320.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });

  for (final dark in [false, true]) {
    testWidgets(
      'manage library edits and hides future copies without changing current trip, dark=$dark',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 900);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final store = ReusableLibraryStore.memory('carry');
        final base = buildCarryLibrary([
          {
            'title': 'Hill trip',
            'thingsToCarry': ['Raincoat'],
          },
        ]);
        final current = ['Raincoat'];
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: CarryLibraryDialog(
              entries: base,
              current: current,
              store: store,
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('manage-carry-library')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('library-manager-search')),
          'Raincoat',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Edit library item'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('library-field-text')),
          '**Warm raincoat**',
        );
        await tester.tap(find.byKey(const Key('library-item-save')));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Hide from reusable library'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('library-manager-save')));
        await tester.pumpAndSettle();
        expect(current, ['Raincoat']);
        expect(store.load().hidden, contains('warm raincoat'));
        expect(
          resolveCarryLibrary(
            base,
            store,
          ).where((e) => e.id == 'warm raincoat'),
          isEmpty,
        );
        await tester.tap(find.byKey(const Key('manage-carry-library')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('library-manager-search')),
          'Warm raincoat',
        );
        await tester.tap(find.byKey(const Key('library-show-hidden')));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Restore library item'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('library-manager-save')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('carry-library-search')),
          'Warm raincoat',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('carry-select-results')));
        await tester.pumpAndSettle();
        expect(find.text('Add 1 item'), findsOneWidget);
        expect(current, ['Raincoat']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'pickup library validates Maps links and saves a standalone item',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final store = ReusableLibraryStore.memory('pickup');
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) =>
                      LibraryManagerDialog(store: store, base: const []),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('library-add-item')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('library-field-name')),
        'Metro stop',
      );
      await tester.enterText(
        find.byKey(const Key('library-field-time')),
        '8:30 PM',
      );
      await tester.enterText(
        find.byKey(const Key('library-field-mapLink')),
        'not-a-link',
      );
      await tester.tap(find.byKey(const Key('library-item-save')));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a valid HTTPS link, or leave it blank.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('library-field-mapLink')),
        'https://maps.app.goo.gl/example',
      );
      await tester.tap(find.byKey(const Key('library-item-save')));
      await tester.pumpAndSettle();
      expect(store.load().values, isEmpty);
      await tester.tap(find.byKey(const Key('library-manager-save')));
      await tester.pumpAndSettle();
      final entries = resolvePickupLibrary([], store);
      expect(entries.single.point['name'], 'Metro stop');
      expect(entries.single.point['time'], '8:30 PM');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'add item is staged and cancelling library management discards it',
    (tester) async {
      final store = ReusableLibraryStore.memory('carry');
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) =>
                      LibraryManagerDialog(store: store, base: const []),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('library-add-item')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('library-field-text')),
        'Warm gloves',
      );
      await tester.tap(find.byKey(const Key('library-item-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.load().values, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
