import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trip_manager_app/widgets/trip_section_settings_editor.dart';
import '../test/trip_section_settings_test.dart' as sections;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  sections.main();
  if (const bool.fromEnvironment('TRIP_SECTIONS_SCREENSHOTS')) {
    testWidgets('captures the native Android display panel in both themes', (
      tester,
    ) async {
      await binding.convertFlutterSurfaceToImage();
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            // Mount each theme fresh; screenshots should not capture a theme fade.
            key: ValueKey(dark),
            themeAnimationDuration: Duration.zero,
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: Scaffold(
              appBar: AppBar(title: const Text('Trip Manager')),
              body: SingleChildScrollView(
                child: TripSectionSettingsEditor(
                  expandedSections: const ['about'],
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final name = 'trip-sections-${dark ? "dark" : "light"}';
        await binding.takeScreenshot(name);
      }
    });
  }
}
