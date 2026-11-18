import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/services/pickup_library.dart';
import 'package:trip_manager_app/theme/app_theme.dart';
import 'package:trip_manager_app/widgets/pickup_library_dialog.dart';
import 'manager_preview_test.dart' as previews;

void main() {
  for (final dark in [false, true]) {
    testWidgets('pickup library phone preview dark=$dark', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
            theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
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
                appBar: AppBar(title: const Text('Trip pickup points')),
                body: Center(
                  child: FilledButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => PickupLibraryDialog(
                        current: const [],
                        entries: buildPickupLibrary([
                          {
                            'title': 'North Karnataka trip',
                            'boardingLocations': [
                              {
                                'name': 'Hebbal',
                                'landmark': 'Esteem Mall bus stop',
                                'time': '9:15 PM',
                                'mapLink': 'https://maps.app.goo.gl/example',
                              },
                            ],
                          },
                        ]),
                      ),
                    ),
                    child: const Text('Reuse pickup points'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Reuse pickup points'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('pickup-library-search')),
        'Hebbal',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.ancestor(
          of: find.text('Hebbal').last,
          matching: find.byType(CheckboxListTile),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hebbal').last);
      await tester.pumpAndSettle();
      expect(find.text('Add 1 point'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await previews.capture(
        tester,
        boundary,
        'pickup-library-${dark ? 'dark' : 'light'}.png',
      );
    });
  }
}
