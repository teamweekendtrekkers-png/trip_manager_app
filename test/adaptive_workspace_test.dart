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
    expect(find.text('Homepage'), findsOneWidget);
    expect(find.text('Data health'), findsOneWidget);
    expect(find.text('Deployment'), findsOneWidget);
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
    expect(find.text('2 Trips'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manager-mobile-navigation')), findsOneWidget);
    expect(find.text('Homepage'), findsOneWidget);
    expect(find.text('Upcoming batches'), findsOneWidget);
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

Widget _app(({TripsProvider trips, SettingsProvider settings}) providers) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: providers.trips),
      ChangeNotifierProvider.value(value: providers.settings),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
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
