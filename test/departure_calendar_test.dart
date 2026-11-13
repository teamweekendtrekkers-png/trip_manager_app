import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:trip_manager_app/widgets/departure_calendar.dart';
import 'package:trip_manager_app/services/departure_status.dart';

void main() {
  testWidgets('calendar fits narrow phones with readable controls', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final file = File(
        Platform.isWindows
            ? 'C:/Windows/Fonts/arial.ttf'
            : '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      );
      if (await file.exists())
        await (FontLoader(
          'CalendarPreview',
        )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [320.0, 390.0]) {
      tester.view.physicalSize = Size(width, 844);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'CalendarPreview'),
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              appBar: AppBar(title: const Text('Departure calendar')),
              body: SingleChildScrollView(
                child: DepartureCalendar(
                  referenceDate: DateTime.utc(2030, 11, 1),
                  trips: [
                    {
                      'id': 'a',
                      'title': 'Theyyam experience',
                      'availableDates': ['Nov 15-17, 2030'],
                      'confirmedDepartures': ['2030-11-15/2030-11-17'],
                    },
                  ],
                  onStatus: (_, _, _) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (width == 390)
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory('build/reviews').createSync(recursive: true);
          File(
            'build/reviews/departure-calendar-phone.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
    }
  });
  testWidgets(
    'calendar shows authored departures and sends status changes for the selected trip and date',
    (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DepartureCalendar(
                referenceDate: DateTime.utc(2030, 10, 1),
                trips: [
                  {
                    'id': 'a',
                    'title': 'Coorg',
                    'availableDates': ['Oct 4-6, 2030'],
                    'soldOutDepartures': ['2030-10-04/2030-10-06'],
                  },
                  {
                    'id': 'b',
                    'title': 'Hidden',
                    'isActive': false,
                    'availableDates': ['Oct 4-6, 2030'],
                  },
                ],
                onStatus: (id, key, status) => calls.add('$id $key $status'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Coorg'), findsOneWidget);
      expect(find.textContaining('Sold out'), findsOneWidget);
      expect(find.text('Hidden'), findsNothing);
      await tester.ensureVisible(find.byTooltip('Change departure status'));
      await tester.tap(find.byTooltip('Change departure status'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmed departure'));
      await tester.pumpAndSettle();
      expect(calls, ['a 2030-10-04/2030-10-06 confirmed']);
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No departures this month'), findsOneWidget);
    },
  );
  test(
    'closing a departure removes stale statuses and can be reopened safely',
    () {
      final original = {
        'availableDates': ['Oct 4-6, 2030'],
        'confirmedDepartures': ['2030-10-04/2030-10-06'],
      };
      final closed = setDepartureStatus(
        original,
        '2030-10-04/2030-10-06',
        'closed',
      );
      expect(departureStatus(closed, '2030-10-04/2030-10-06'), 'closed');
      expect(
        departureStatus(
          setDepartureStatus(closed, '2030-10-04/2030-10-06', 'available'),
          '2030-10-04/2030-10-06',
        ),
        'available',
      );
      expect(original['confirmedDepartures'], ['2030-10-04/2030-10-06']);
    },
  );
}
