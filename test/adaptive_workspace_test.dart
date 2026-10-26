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
import 'package:trip_manager_app/widgets/manager_navigation.dart';
import 'package:trip_manager_app/screens/trip_edit_screen.dart';
import 'package:trip_manager_app/widgets/trip_editor_sections.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    testWidgets(
      'manager usability preview at ' + size.width.toInt().toString(),
      (tester) async {
        await _setSize(tester, size);
        await tester.runAsync(() async {
          final sdk = Platform.environment['FLUTTER_ROOT'];
          if (sdk == null) return;
          for (final entry in {
            'Roboto': 'Roboto-Regular.ttf',
            'MaterialIcons': 'MaterialIcons-Regular.otf',
          }.entries) {
            final file = File(
              sdk + '/bin/cache/artifacts/material_fonts/' + entry.value,
            );
            if (!file.existsSync()) continue;
            final data = file.readAsBytesSync();
            final loader = FontLoader(entry.key)
              ..addFont(Future.value(ByteData.sublistView(data)));
            await loader.load();
          }
        });
        final providers = await _providers();
        const key = Key('manager-usability-preview');
        await tester.pumpWidget(
          RepaintBoundary(key: key, child: _app(providers, previewFonts: true)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(key),
          );
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          final directory = Directory('build/reviews')
            ..createSync(recursive: true);
          File(
            directory.path +
                '/manager-' +
                size.width.toInt().toString() +
                '.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      },
    );
  }

  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('Home and Trips share navigation at $width', (tester) async {
      await _setSize(tester, Size(width, 900));
      final providers = await _providers();
      const previewKey = Key('home-preview');
      await tester.pumpWidget(
        RepaintBoundary(
          key: previewKey,
          child: _app(providers, home: true, previewFonts: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your daily workspace'), findsOneWidget);
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(previewKey),
        );
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final directory = Directory('build/reviews')
          ..createSync(recursive: true);
        File(
          '${directory.path}/home-${width.toInt()}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
      expect(tester.takeException(), isNull);
      if (width < managerDesktopBreakpoint) {
        final nav = find.byKey(const Key('manager-bottom-navigation'));
        expect(tester.widget<NavigationBar>(nav).selectedIndex, 0);
        await tester.tap(
          find.descendant(of: nav, matching: find.text('Trips')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Trips workspace'), findsOneWidget);
        expect(tester.widget<NavigationBar>(nav).selectedIndex, 1);
        await tester.tap(find.descendant(of: nav, matching: find.text('Home')));
      } else {
        final nav = find.byKey(const Key('manager-desktop-navigation'));
        await tester.tap(
          find.descendant(of: nav, matching: find.text('Trips')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Trips workspace'), findsOneWidget);
        await tester.tap(
          find.descendant(of: nav, matching: find.text('Dashboard')),
        );
      }
      await tester.pumpAndSettle();
      expect(find.text('Your daily workspace'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets(
      'Bookings shares navigation and preserves typed fields at $width',
      (tester) async {
        await _setSize(tester, Size(width, 900));
        final providers = await _providers();
        await tester.pumpWidget(_app(providers, home: true));
        await tester.pumpAndSettle();
        Future<void> tab(String label) async {
          final shell = find.byKey(
            Key(
              width < managerDesktopBreakpoint
                  ? 'manager-bottom-navigation'
                  : 'manager-desktop-navigation',
            ),
          );
          await tester.tap(
            find.descendant(of: shell, matching: find.text(label)),
          );
          await tester.pumpAndSettle();
        }

        await tab('Trips');
        await tester.enterText(find.byType(TextField).first, 'Coorg');
        await tester.pumpAndSettle();
        expect(find.text('Varkala Escape'), findsNothing);
        await tab(
          width < managerDesktopBreakpoint ? 'Bookings' : 'Booking review',
        );
        expect(find.text('Bookings & payment review'), findsOneWidget);
        expect(find.byKey(const Key('workspace-publish')), findsNothing);
        await tester.enterText(
          find.widgetWithText(TextField, 'Administrator email'),
          'manager@example.com',
        );
        await tab('Trips');
        expect(find.text('Coorg Weekend'), findsOneWidget);
        expect(find.text('Varkala Escape'), findsNothing);
        await tab(
          width < managerDesktopBreakpoint ? 'Bookings' : 'Booking review',
        );
        expect(find.text('manager@example.com'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'card Dates & price action opens quick edit without changing the trip',
    (tester) async {
      await _setSize(tester, const Size(390, 900));
      final providers = await _providers();
      await tester.pumpWidget(_app(providers));
      await tester.pumpAndSettle();
      final before = providers.trips.trips
          .map((trip) => Map<String, dynamic>.from(trip))
          .toList();
      await tester.tap(find.text('Dates & price').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Quick edit'), findsWidgets);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(providers.trips.trips, before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('guided editor keeps text when moving between sections', (
    tester,
  ) async {
    await _setSize(tester, const Size(390, 900));
    final providers = await _providers();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: providers.trips),
          ChangeNotifierProvider.value(value: providers.settings),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const TripEditScreen(initialSection: TripEditorSection.basics),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('trip-name')),
      'Weekend draft',
    );
    await tester.tap(find.byKey(const Key('editor-guided-next')));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 5'), findsOneWidget);
    await tester.tap(find.byKey(const Key('editor-guided-back')));
    await tester.pumpAndSettle();
    expect(find.text('Weekend draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
    final navigationScroll = find
        .descendant(
          of: find.byKey(const Key('manager-desktop-navigation')),
          matching: find.byType(Scrollable),
        )
        .first;
    for (final label in [
      'Booking review',
      'Manage departures',
      'Website content',
      'Shared trip content',
      'Payments & coupons',
      'Data health',
      'Publishing status',
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        100,
        scrollable: navigationScroll,
      );
      expect(find.text(label), findsOneWidget);
    }
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
    expect(find.byKey(const Key('manager-bottom-navigation')), findsOneWidget);
    expect(find.byKey(const Key('workspace-publish')), findsOneWidget);
    expect(find.text('2 Trips'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manager-mobile-navigation')), findsOneWidget);
    expect(find.text('Website content'), findsOneWidget);
    expect(find.text('Departures'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Settings'),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('manager-mobile-navigation')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
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

Widget _app(
  ({TripsProvider trips, SettingsProvider settings}) providers, {
  bool previewFonts = false,
  bool home = false,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: providers.trips),
      ChangeNotifierProvider.value(value: providers.settings),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: previewFonts
          ? AppTheme.light().copyWith(
              textTheme: AppTheme.light().textTheme.apply(fontFamily: 'Roboto'),
              filledButtonTheme: FilledButtonThemeData(
                style: AppTheme.light().filledButtonTheme.style?.copyWith(
                  textStyle: const WidgetStatePropertyAll(
                    TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: AppTheme.light().outlinedButtonTheme.style?.copyWith(
                  textStyle: const WidgetStatePropertyAll(
                    TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              appBarTheme: AppTheme.light().appBarTheme.copyWith(
                titleTextStyle: AppTheme.light().appBarTheme.titleTextStyle
                    ?.copyWith(fontFamily: 'Roboto'),
              ),
            )
          : AppTheme.light(),
      darkTheme: AppTheme.dark(),
      scrollBehavior: const ManagerScrollBehavior(),
      home: TripsListScreen(
        toolsService: home ? _AdaptiveGitHubService() : null,
        initialDestination: home
            ? ManagerDestination.dashboard
            : ManagerDestination.trips,
      ),
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
  Future<List<WorkflowRunResult>> getRecentDeployments({
    int limit = 10,
  }) async => [];

  @override
  Future<GitHubFileResult> fetchTripsData() async => GitHubFileResult(
    content: TripsParser.generateTripsDataJs(trips),
    sha: 'trips-sha',
    success: true,
  );

  @override
  Future<GitHubFileResult> fetchFile(String filePath) async => GitHubFileResult(
    content: filePath == 'js/homepage-config.json'
        ? '{"version":1}'
        : TripsParser.generateFeaturedTripsJs(trips),
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
