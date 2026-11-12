import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/widgets/text_formatting_tools.dart';
import 'package:trip_manager_app/widgets/trip_cover_picker.dart';
import 'package:trip_manager_app/widgets/inline_formatting.dart';

void main() {
  testWidgets(
    'formatting controls preserve selected words and preview updates',
    (tester) async {
      final controller = TextEditingController(text: 'Meet your guide');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(controller: controller),
                  TextFormattingTools(controller: controller),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      controller.selection = const TextSelection(
        baseOffset: 5,
        extentOffset: 9,
      );
      await tester.pump();
      await tester.tap(find.text('Bold'));
      await tester.pump();
      expect(controller.text, 'Meet **your** guide');
      await tester.tap(find.text('Preview text'));
      await tester.pump();
      expect(
        tester.widget<FormattedText>(find.byType(FormattedText)).data,
        controller.text,
      );
      await tester.tap(find.text('Italic'));
      await tester.pump();
      expect(controller.text, 'Meet ***your*** guide');
      await tester.tap(find.text('Bold'));
      await tester.pump();
      expect(controller.text, 'Meet *your* guide');
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'cover picker selects an existing gallery photo without uploading',
    (tester) async {
      final controller = TextEditingController(
        text: 'images/trips/default.jpg',
      );
      var uploads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TripCoverPicker(
                controller: controller,
                galleryPhotos: const [
                  'images/gallery/hills.jpg',
                  'images/gallery/hills.jpg',
                ],
                onUpload: () => uploads++,
                onCamera: () {},
                onLibrary: () {},
                previewBuilder: (path) => Text('Preview: $path'),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('old placeholder'), findsOneWidget);
      await tester.tap(find.text('Use gallery photo'));
      await tester.pumpAndSettle();
      expect(find.text('Photo 1'), findsOneWidget);
      expect(find.text('Photo 2'), findsNothing);
      await tester.tap(find.text('Photo 1'));
      await tester.pumpAndSettle();
      expect(controller.text, 'images/gallery/hills.jpg');
      expect(find.textContaining('old placeholder'), findsNothing);
      expect(uploads, 0);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'photo and formatting controls fit a small phone with larger text',
    (tester) async {
      await tester.runAsync(() async {
        final sdk = Platform.environment['FLUTTER_ROOT'];
        if (sdk == null) return;
        for (final entry in {
          'Roboto': 'Roboto-Regular.ttf',
          'MaterialIcons': 'MaterialIcons-Regular.otf',
        }.entries) {
          final file = File(
            '$sdk/bin/cache/artifacts/material_fonts/${entry.value}',
          );
          if (!file.existsSync()) continue;
          final loader = FontLoader(entry.key)
            ..addFont(
              Future.value(ByteData.sublistView(file.readAsBytesSync())),
            );
          await loader.load();
        }
      });
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          theme: ThemeData(fontFamily: 'Roboto'),
          home: RepaintBoundary(
            key: const Key('editor-controls-preview'),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormattingTools(controller: controller),
                      TripCoverPicker(
                        controller: controller,
                        galleryPhotos: const [],
                        onUpload: () {},
                        onCamera: () {},
                        onLibrary: () {},
                        previewBuilder: (_) => const SizedBox(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('editor-controls-preview')),
        );
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final directory = Directory('build/reviews')
          ..createSync(recursive: true);
        File(
          '${directory.path}/editor-controls-320.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
