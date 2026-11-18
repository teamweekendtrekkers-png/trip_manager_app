import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/services/carry_library.dart';
import 'package:trip_manager_app/widgets/carry_library_dialog.dart';
import 'package:trip_manager_app/theme/app_theme.dart';
import 'manager_preview_test.dart' as previews;

void main() {
  testWidgets('things to carry phone preview supports formatted choices', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.runAsync(() async {
      final sdk = Platform.environment['FLUTTER_ROOT'];
      if (sdk == null) return;
      for (final font in {
        'Roboto': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf',
      }.entries) {
        final file = File(
          '$sdk/bin/cache/artifacts/material_fonts/${font.value}',
        );
        if (file.existsSync())
          await (FontLoader(font.key)..addFont(
                Future.value(ByteData.sublistView(file.readAsBytesSync())),
              ))
              .load();
      }
    });
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light().copyWith(
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                textStyle: const TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => CarryLibraryDialog(
                      current: const ['Raincoat'],
                      entries: buildCarryLibrary([
                        {
                          'title': 'Winter trek',
                          'thingsToCarry': [
                            'Raincoat',
                            '**Thermal jacket**',
                            'Torch / headlamp',
                          ],
                        },
                      ]),
                    ),
                  ),
                  child: const Text('Open packing library'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open packing library'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('carry-library-search')),
      'Winter trek',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('carry-select-results')));
    await tester.pumpAndSettle();
    expect(find.text('Add 2 items'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await previews.capture(tester, boundary, 'carry-library-phone.png');
  });
}
