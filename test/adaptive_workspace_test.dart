import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/providers/settings_provider.dart';
import 'package:trip_manager_app/providers/trips_provider.dart';
import 'package:trip_manager_app/screens/trips_list_screen.dart';
import 'package:trip_manager_app/services/github_service.dart';
import 'package:trip_manager_app/services/trips_parser.dart';
import 'package:trip_manager_app/theme/app_theme.dart';

void main() {
  for(final size in [const Size(390,844),const Size(1440,900)]) {
    testWidgets('manager usability preview at '+size.width.toInt().toString(),(tester) async {
      await _setSize(tester,size);await tester.runAsync(() async {
        final sdk=Platform.environment['FLUTTER_ROOT'];if(sdk==null)return;
        for(final entry in {'Roboto':'Roboto-Regular.ttf','MaterialIcons':'MaterialIcons-Regular.otf'}.entries){
          final file=File(sdk+'/bin/cache/artifacts/material_fonts/'+entry.value);if(!file.existsSync())continue;final data=file.readAsBytesSync();final loader=FontLoader(entry.key)..addFont(Future.value(ByteData.sublistView(data)));await loader.load();
        }
      });final providers=await _providers();
      const key=Key('manager-usability-preview');await tester.pumpWidget(RepaintBoundary(key:key,child:_app(providers,previewFonts:true)));await tester.pumpAndSettle();expect(tester.takeException(),isNull);
      await tester.runAsync(() async {final boundary=tester.renderObject<RenderRepaintBoundary>(find.byKey(key));final image=await boundary.toImage(pixelRatio:1);final bytes=await image.toByteData(format:ui.ImageByteFormat.png);image.dispose();
      final directory=Directory('build/reviews')..createSync(recursive:true);File(directory.path+'/manager-'+size.width.toInt().toString()+'.png').writeAsBytesSync(bytes!.buffer.asUint8List());});
    });
  }

  testWidgets('desktop presents labelled navigation and keyboard search', (
    tester,
  ) async {
    await _setSize(tester, const Size(1440, 900));
    final providers = await _providers();
    await tester.pumpWidget(_app(providers));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('manager-desktop-navigation')), findsOneWidget);
    expect(find.byKey(const Key('manager-mobile-navigation')), findsNothing);
    expect(find.byKey(const Key('desktop-workspace-summary')), findsOneWidget);
    expect(find.text('Website content'), findsOneWidget);
    expect(find.text('Payments & coupons'), findsOneWidget);
    expect(find.text('Shared trip content'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Data health'),120,scrollable:find.descendant(of:find.byKey(const Key('manager-desktop-navigation')),matching:find.byType(Scrollable)).first);
    expect(find.text('Data health'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Publishing status'),100,scrollable:find.descendant(of:find.byKey(const Key('manager-desktop-navigation')),matching:find.byType(Scrollable)).first);
    expect(find.text('Publishing status'), findsOneWidget);
    expect(find.text('2 Trips'), findsNothing);
    expect(find.text('2'), findsWidgets);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    final search = tester.widget<TextField>(find.byType(TextField).first);
    expect(search.focusNode?.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone keeps navigation compact and touch accessible', (
    tester,
  ) async {
    await _setSize(tester, const Size(390, 844));
    final providers = await _providers();
    await tester.pumpWidget(_app(providers));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('manager-desktop-navigation')), findsNothing);
    expect(find.text('Trips workspace'), findsOneWidget);
    expect(find.byTooltip('More tools'), findsOneWidget);
    expect(find.byKey(const Key('manager-bottom-navigation')),findsOneWidget);
    expect(find.byKey(const Key('workspace-publish')),findsOneWidget);
    expect(find.text('2 Trips'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manager-mobile-navigation')), findsOneWidget);
    expect(find.text('Website content'), findsOneWidget);
    expect(find.text('Departures'), findsWidgets);
    expect(find.text('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

Future<({TripsProvider trips, SettingsProvider settings})> _providers() async {
  final settings = SettingsProvider(store: _MemorySettingsStore());
  await settings.init();
  await settings.saveSettings(AppSettings(githubToken: 'test-token'));
  final service = _AdaptiveGitHubService();
  return (
    trips: TripsProvider(settings.settings, serviceFactory: (_) => service),
    settings: settings,
  );
}

Widget _app(({TripsProvider trips, SettingsProvider settings}) providers,{bool previewFonts=false}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: providers.trips),
      ChangeNotifierProvider.value(value: providers.settings),
    ],
    child: MaterialApp(
      theme: previewFonts?AppTheme.light().copyWith(textTheme:AppTheme.light().textTheme.apply(fontFamily:'Roboto'),appBarTheme:AppTheme.light().appBarTheme.copyWith(titleTextStyle:AppTheme.light().appBarTheme.titleTextStyle?.copyWith(fontFamily:'Roboto'))):AppTheme.light(),
      darkTheme: AppTheme.dark(),
      scrollBehavior: const ManagerScrollBehavior(),
      home: const TripsListScreen(),
    ),
  );
}

final class _MemorySettingsStore implements SettingsStore {
  final values = <String, String>{};

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<void> init() async {}

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

final class _AdaptiveGitHubService extends GitHubService {
  _AdaptiveGitHubService() : super(settings: AppSettings());

  final trips = <Map<String, dynamic>>[
    _trip('coorg', 'Coorg Weekend'),
    _trip('varkala', 'Varkala Escape', featured: true),
  ];

  @override
  Future<GitHubFileResult> fetchTripsData() async => GitHubFileResult(
    content: TripsParser.generateTripsDataJs(trips),
    sha: 'trips-sha',
    success: true,
  );

  @override
  Future<GitHubFileResult> fetchFile(String filePath) async => GitHubFileResult(
    content: TripsParser.generateFeaturedTripsJs(trips),
    sha: 'featured-sha',
    success: true,
  );
}

Map<String, dynamic> _trip(String id, String title, {bool featured = false}) =>
    <String, dynamic>{
      'id': id,
      'title': title,
      'name': title,
      'location': 'Karnataka',
      'price': '₹3,999',
      'image': '',
      'featured': featured,
      'isActive': true,
      'availableDates': <String>['Jan 1-2, 2099'],
      'highlights': <String>['Views'],
      'itinerary': <Map<String, dynamic>>[],
      'inclusions': <String>[],
      'exclusions': <String>[],
    };
