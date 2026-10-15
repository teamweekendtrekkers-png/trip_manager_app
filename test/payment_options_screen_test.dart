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
    'manager saves two accounts, switches the active pair and chooses optional request trips',
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
      await show(tester, 'payment-eligibility');
      await tester.tap(find.byKey(const Key('payment-eligibility')));
      await tester.pumpAndSettle();
      await show(tester, 'payment-trip-demo');
      await tester.tap(find.byKey(const Key('payment-trip-demo')));
      await tester.pumpAndSettle();
      await show(tester, 'payment-upi-id');
      await tester.enterText(find.byKey(const Key('payment-upi-id')), 'primary@upi');
      await show(tester, 'payment-receiver-name');
      await tester.enterText(find.byKey(const Key('payment-receiver-name')), 'Primary receiver');
      await show(tester, 'payment-upload-qr');
      await tester.tap(find.byKey(const Key('payment-upload-qr')));
      await tester.pumpAndSettle();
      await show(tester, 'payment-show-qr');
      await tester.tap(find.byKey(const Key('payment-show-qr')));
      await tester.pumpAndSettle();
      await show(tester, 'payment-profile-0');
      await tester.tap(find.byKey(const Key('payment-profile-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Backup account').last);
      await tester.pumpAndSettle();
      await show(tester, 'payment-upi-id');
      expect(tester.widget<TextField>(find.byKey(const Key('payment-upi-id'))).controller!.text, '');
      await tester.enterText(find.byKey(const Key('payment-upi-id')), 'backup@upi');
      await show(tester, 'payment-receiver-name');
      await tester.enterText(find.byKey(const Key('payment-receiver-name')), 'Backup receiver');
      await show(tester, 'payment-upload-qr');
      await tester.tap(find.byKey(const Key('payment-upload-qr')));
      await tester.pumpAndSettle();
      await show(tester, 'payment-use-account');
      await tester.tap(find.byKey(const Key('payment-use-account')));
      await tester.pumpAndSettle();
      expect(github.commits, 0);
      await show(tester, 'payment-publish');
      await tester.tap(find.byKey(const Key('payment-publish')));
      await tester.pumpAndSettle();
      expect(find.text('Active account: Backup account'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
      await tester.pumpAndSettle();
      expect(github.commits, 1);
      final payment = jsonDecode(github.content)['payment'];
      expect(payment['checkoutVersion'], 2);
      expect(payment['mode'], 'direct');
      expect(payment['showQr'], true);
      expect(payment['activeProfileId'], 'backup');
      expect(payment['upiId'], 'backup@upi');
      expect(payment['receiverName'], 'Backup receiver');
      expect(payment['profiles'][0]['upiId'], 'primary@upi');
      expect(payment['profiles'][1]['upiId'], 'backup@upi');
      expect(payment['qrImage'], 'images/trips/demo-qr.png');
      expect(payment['requestTripIds'], ['demo']);
      expect(tripService.atomicCalls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
