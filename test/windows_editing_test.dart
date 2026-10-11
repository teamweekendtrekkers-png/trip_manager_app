import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/providers/settings_provider.dart';
import 'package:trip_manager_app/providers/trips_provider.dart';
import 'package:trip_manager_app/screens/trip_edit_screen.dart';
import 'package:trip_manager_app/theme/app_theme.dart';

void main() {
  testWidgets('Windows mouse focus, selection and keyboard edits survive preview rebuilds and save', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final trips = TripsProvider(AppSettings())..addTrip({
      'id': 'desktop-edit', 'title': 'Original trip', 'location': 'Bengaluru',
      'about': 'Original description', 'price': '₹3500', 'image': '',
      'difficulty': 'Moderate', 'availableDates': <String>[],
    });
    addTearDown(trips.dispose);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<TripsProvider>.value(value: trips),
        ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider(store: _Store())),
      ],
      child: MaterialApp(theme: AppTheme.light(), scrollBehavior: const ManagerScrollBehavior(),
        home: TripEditScreen(trip: trips.trips.single, index: 0)),
    ));
    await tester.pumpAndSettle();
    expect(const ManagerScrollBehavior().dragDevices, isNot(contains(PointerDeviceKind.mouse)));
    final name = find.byKey(const ValueKey('trip-name'));
    await tester.tap(name, kind: PointerDeviceKind.mouse);
    await tester.pump();
    final editable = tester.widget<EditableText>(find.descendant(of: name, matching: find.byType(EditableText)));
    expect(editable.focusNode.hasFocus, isTrue);
    await tester.enterText(name, 'Updated desktop trip');
    await tester.pump();
    expect(editable.focusNode.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pump();
    expect(editable.controller.selection.isCollapsed, isFalse);
    final about = find.byKey(const ValueKey('trip-about'));
    await tester.ensureVisible(about);
    await tester.tap(about, kind: PointerDeviceKind.mouse);
    await tester.enterText(about, 'Updated description on Windows');
    await tester.pump();
    await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.save)));
    await tester.pumpAndSettle();
    expect(trips.trips.single['title'], 'Updated desktop trip');
    expect(trips.trips.single['about'], 'Updated description on Windows');
    expect(tester.takeException(), isNull);
  });
}
class _Store implements SettingsStore {
  @override Future<void> init() async {}
  @override Future<String?> read(String key) async => null;
  @override Future<void> write(String key, String value) async {}
  @override Future<void> clear() async {}
}
