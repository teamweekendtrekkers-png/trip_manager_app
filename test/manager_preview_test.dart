import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/models/homepage_config.dart';
import 'package:trip_manager_app/providers/settings_provider.dart';
import 'package:trip_manager_app/providers/trips_provider.dart';
import 'package:trip_manager_app/screens/trip_edit_screen.dart';
import 'package:trip_manager_app/widgets/trip_editor_sections.dart';
import 'package:trip_manager_app/widgets/departure_selection_editor.dart';
import 'package:trip_manager_app/widgets/trip_content_editor.dart';
import 'package:trip_manager_app/models/trip_content_settings.dart';
import 'package:trip_manager_app/theme/app_theme.dart';
import 'trips_provider_publication_test.dart' as fixtures;

class MemorySettings implements SettingsStore {
  @override
  Future<void> init() async {}
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> clear() async {}
}

Future<void> capture(
  WidgetTester tester,
  GlobalKey key,
  String filename,
) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/reviews')..createSync(recursive: true);
    File(
      '${directory.path}/$filename',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets('extra-section controls fit a phone screen', (tester) async {
    await tester.runAsync(() async {final font=File(Platform.isWindows?'C:/Windows/Fonts/arial.ttf':'/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');if(await font.exists()) await (FontLoader('SectionPreview')..addFont(font.readAsBytes().then((bytes)=>ByteData.sublistView(bytes)))).load();});
    tester.view.physicalSize = const Size(390,900); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final key=GlobalKey();
    var value=<String,dynamic>{'custom_why_choose_us':TripContentSettings.customSection('Why choose us')..['items']=[{'title':'Local hosts','description':'Support throughout your journey.','icon':'group'}]};
    final defaults={for(final key in TripContentSettings.titles.keys) key:key=='cancellation'?{'mode':'default','heading':'Cancellation policy','expanded':false,'items':[{'minDays':0,'maxDays':null,'percent':100}]}:{'mode':'default','heading':TripContentSettings.titles[key],'expanded':false,'items':[]}};
    await tester.pumpWidget(MaterialApp(theme:ThemeData(fontFamily:'SectionPreview'),home:RepaintBoundary(key:key,child:Scaffold(appBar:AppBar(title:const Text('Edit website sections')),body:SingleChildScrollView(child:StatefulBuilder(builder:(context,set)=>TripContentEditor(value:value,defaults:defaults,onChanged:(next)=>set(()=>value=next))))))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Why choose us'));await tester.tap(find.text('Why choose us'));await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add item').last);await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);
    await capture(tester,key,'custom-trip-sections-phone.png');
  });
  ThemeData previewTheme() {
    final base = AppTheme.light();
    const style = WidgetStatePropertyAll(
      TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle:
            (base.appBarTheme.titleTextStyle ?? const TextStyle(fontSize: 20))
                .copyWith(fontFamily: 'Roboto'),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: base.filledButtonTheme.style?.copyWith(textStyle: style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: base.outlinedButtonTheme.style?.copyWith(textStyle: style),
      ),
    );
  }

  Future<void> fonts(WidgetTester tester) async {
    await tester.runAsync(() async {
      final text = File(
        Platform.isWindows
            ? 'C:/Windows/Fonts/arial.ttf'
            : '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      );
      if (await text.exists())
        await (FontLoader('Roboto')..addFont(
              text.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
            ))
            .load();
      final icons = File(
        '../${Platform.isWindows ? 'flutter' : 'flutter-linux'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (await icons.exists())
        await (FontLoader('MaterialIcons')..addFont(
              icons.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
            ))
            .load();
    });
  }

  for (final width in [390.0, 1440.0])
    testWidgets('focused editor and live preview fit $width', (tester) async {
      await fonts(tester);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = SettingsProvider(store: MemorySettings());
      await settings.init();
      final service = fixtures.FakeGitHubService()
        ..queueSnapshot(
          [
            fixtures.trip(
              'a',
              title: 'Coorg weekend',
              dates: ['Oct 16-18, 2026'],
            ),
          ],
          tripsSha: 't',
          featuredSha: 'f',
        );
      final provider = fixtures.providerFor(service);
      await provider.loadTrips();
      final key = GlobalKey();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: provider),
          ],
          child: MaterialApp(
            theme: previewTheme(),
            home: RepaintBoundary(
              key: key,
              child: TripEditScreen(
                trip: provider.trips.single,
                index: 0,
                initialSection: TripEditorSection.basics,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('editor-save-draft')), findsOneWidget);
      if (width > 1100) {
        expect(
          find.text(
            'Draft content preview · Layout is approximate; links and payments are disabled.',
          ),
          findsOneWidget,
        );
      }
      await capture(tester, key, 'productivity-editor-${width.toInt()}.png');
      await tester.enterText(find.byType(TextFormField).first, 'My unsaved trip title');
      await tester.tap(find.byKey(const Key('editor-next-section'))); await tester.pumpAndSettle();
      expect(tester.widget<TripEditorSectionPicker>(find.byType(TripEditorSectionPicker)).value, TripEditorSection.dates);
      await tester.tap(find.byKey(const Key('editor-previous-section'))); await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text, 'My unsaved trip title');
      expect(provider.trips.single['title'], 'Coorg weekend');
      expect(find.byKey(const Key('editor-publish-help')), findsOneWidget);
      await tester.tap(find.byKey(const Key('editor-quick-actions'))); await tester.pumpAndSettle();
      expect(find.text('Preview / share PDF'), findsOneWidget);
      expect(find.text('Find an editor field'), findsOneWidget);
      await capture(tester, key, 'trip-actions-${width.toInt()}.png');
      await tester.tap(find.text('Preview / share PDF')); await tester.pumpAndSettle();
      expect(find.text('Trip Brochure'), findsOneWidget);
      expect(find.text('My unsaved trip title'), findsOneWidget);
      expect(provider.trips.single['title'], 'Coorg weekend');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
      settings.dispose();
    });
  testWidgets(
    'selection preview respects trip and individual date choices on a phone',
    (tester) async {
      await fonts(tester);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final config = HomepageConfig.initial().toJson();
      final options = config['upcomingBatches'] as Map;
      options['tripSelection'] = 'selected';
      options['tripIds'] = ['a'];
      options['departureSelection'] = 'selected';
      options['departures'] = [
        {'tripId': 'a', 'date': 'Oct 16-18, 2026'},
      ];
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: previewTheme(),
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              appBar: AppBar(title: const Text('Upcoming Batches selection')),
              body: SingleChildScrollView(
                child: DepartureSelectionEditor(
                  draft: config,
                  trips: [
                    fixtures.trip(
                      'a',
                      title: 'Coorg weekend',
                      dates: ['Oct 16-18, 2026', 'Oct 23-25, 2026'],
                    ),
                    fixtures.trip(
                      'b',
                      title: 'Beach getaway',
                      dates: ['Oct 16-18, 2026'],
                    ),
                  ],
                  referenceDate: DateTime.utc(2026, 10, 14),
                  onChanged: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final preview = find.byKey(const Key('homepage-selection-preview'));
      expect(
        find.descendant(of: preview, matching: find.text('Coorg weekend')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: preview, matching: find.text('Beach getaway')),
        findsNothing,
      );
      await capture(tester, key, 'productivity-departure-selection.png');
    },
  );
}

