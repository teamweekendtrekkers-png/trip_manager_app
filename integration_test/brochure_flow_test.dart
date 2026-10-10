import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/screens/trip_brochure_screen.dart';
import '../test/trip_brochure_test.dart' as brochure;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  brochure.main();
  // Opt-in manual device gate: inspect/dismiss Android's native chooser with
  // adb during the 20-second window. Never contacts GitHub or publishes data.
  if (const bool.fromEnvironment('BROCHURE_NATIVE_SHARE')) {
    testWidgets('Android native PDF share sheet opens and returns safely', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: TripBrochureScreen(brochure: brochure.brochure())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('brochure-share')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('brochure-error')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('brochure-share')))
            .onPressed,
        isNotNull,
      );
    });
  }
}
