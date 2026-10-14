import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trip_manager_app/providers/settings_provider.dart';
import 'package:trip_manager_app/providers/trips_provider.dart';
import 'package:trip_manager_app/screens/commerce_settings_screen.dart';
import 'package:trip_manager_app/services/commerce_settings_service.dart';
import 'commerce_settings_test.dart' show MemoryCommerce;
import 'manager_preview_test.dart' show MemorySettings;
import 'trips_provider_publication_test.dart' as fixtures;

void main() {
  Future<void> show(WidgetTester tester, String key) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final target = find.byKey(ValueKey(key));
    if (target.evaluate().isEmpty) {
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        target,
        300,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 60,
      );
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'manager controls both paths, approved dates, QR upload, hide and publish',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = SettingsProvider(store: MemorySettings());
      await settings.init();
      final github = MemoryCommerce();
      final tripService = fixtures.FakeGitHubService()
        ..queueSnapshot(
          [
            fixtures.trip('demo', title: 'Demo trip')
              ..['availableDates'] = ['Dec 20-22, 2099'],
          ],
          tripsSha: 'base',
          featuredSha: 'featured',
        );
      final trips = TripsProvider(
        tripService.settings,
        serviceFactory: (_) => tripService,
      );
      await trips.loadTrips();
      addTearDown(trips.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: trips),
          ],
          child: MaterialApp(
            home: CommerceSettingsScreen(
              service: CommerceSettingsService(github),
              qrUploader: () async => 'images/trips/demo-qr.png',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await show(tester, 'payment-mode');
      await tester.tap(find.byKey(const Key('payment-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Offer both options').last);
      await tester.pumpAndSettle();
      await show(tester, 'payment-eligibility');
      await tester.tap(find.byKey(const Key('payment-eligibility')));
      await tester.pumpAndSettle();
      await show(tester, 'payment-trip-demo');
      await tester.tap(find.byKey(const Key('payment-trip-demo')));
      await tester.pumpAndSettle();
      await show(tester, 'payment-departure-demo|2099-12-20/2099-12-22');
      await tester.tap(
        find.byKey(const Key('payment-departure-demo|2099-12-20/2099-12-22')),
      );
      await tester.pumpAndSettle();
      await show(tester, 'payment-upload-qr');
      await tester.tap(find.byKey(const Key('payment-upload-qr')));
      await tester.pumpAndSettle();
      await show(tester, 'payment-show-qr');
      await tester.tap(find.byKey(const Key('payment-show-qr')));
      await tester.pumpAndSettle();
      await show(tester, 'payment-instructions');
      await tester.enterText(
        find.byKey(const Key('payment-instructions')),
        'Verify the receiver name before paying.',
      );
      await tester.pumpAndSettle();
      expect(github.commits, 0);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('payment-publish')),
        300,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 50,
      );
      await tester.tap(find.byKey(const Key('payment-publish')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Direct payment → Payment details submitted'),
        findsWidgets,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
      await tester.pumpAndSettle();
      expect(github.commits, 1);
      final payment = jsonDecode(github.content)['payment'];
      expect(payment['mode'], 'both');
      expect(payment['showQr'], true);
      expect(payment['qrImage'], 'images/trips/demo-qr.png');
      expect(payment['directDepartures'], [
        {'tripId': 'demo', 'dateKey': '2099-12-20/2099-12-22'},
      ]);
      expect(tripService.atomicCalls, isEmpty);
      await show(tester, 'payment-show-qr');
      await tester.tap(find.byKey(const Key('payment-show-qr')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('payment-qr-image')))
            .controller!
            .text,
        'images/trips/demo-qr.png',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
