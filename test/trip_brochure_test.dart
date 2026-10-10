import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/providers/settings_provider.dart';
import 'package:trip_manager_app/providers/trips_provider.dart';
import 'package:trip_manager_app/screens/trip_edit_screen.dart';
import 'package:trip_manager_app/screens/trip_brochure_screen.dart';
import 'package:trip_manager_app/services/trip_brochure_service.dart';
import 'package:trip_manager_app/services/trips_parser.dart';

final reference = DateTime.utc(2026, 8, 13, 12);
Map<String, dynamic> fixture() => {
  'id': 'misty-hills',
  'title': 'Misty Hills 🥾',
  'location': 'Coorg',
  'price': '₹3,499',
  'duration': '2 days',
  'difficulty': 'Easy',
  'about': 'Clouds & coffee.',
  'availableDates': ['Aug 14-16, 2026', 'Aug 21-23, 2026'],
  'itinerary': [
    {
      'day': 'Day 0',
      'title': 'Departure',
      'description': 'Start here.',
      'activities': ['Board at 9 PM', 'Welcome 🧭'],
    },
    {
      'day': 'Day 1',
      'title': 'Trek',
      'activities': ['See sunrise'],
    },
  ],
  'includes': ['Transport'],
  'excludes': ['Lunch'],
  'thingsToCarry': ['Raincoat'],
  'perfectFor': ['Friends'],
  'boardingLocations': [
    {'name': 'Majestic', 'time': '9 PM', 'landmark': 'Metro'},
  ],
};
TripBrochure brochure([Map<String, dynamic>? trip]) => TripBrochure.fromTrip(
  trip ?? fixture(),
  referenceDate: reference,
  whatsapp: '7019235581',
);
String content(TripBrochure value) =>
    value.blocks.map((block) => block.text).join('\n');

void main() {
  test(
    'read-only brochure includes every itinerary field, Unicode, context and safe booking link',
    () {
      final trip = fixture(), before = jsonEncode(fixture());
      final value = brochure(trip), body = content(brochure(trip));
      for (final text in [
        'Misty Hills 🥾',
        '₹3,499',
        'Day 0: Departure',
        'Start here.',
        'Board at 9 PM',
        'Welcome 🧭',
        'Day 1: Trek',
        'See sunrise',
        'Transport',
        'Lunch',
        'Raincoat',
        'Majestic — 9 PM — Metro',
        'WhatsApp: +917019235581',
      ]) {
        expect(body, contains(text));
      }
      expect(
        body.indexOf('Board at 9 PM'),
        lessThan(body.indexOf('See sunrise')),
      );
      expect(jsonEncode(trip), before);
      expect(value.filename, 'misty-hills-brochure.pdf');
      expect(
        value.bookingUrl,
        'https://www.teamweekendtrekkers.com/trips/misty-hills/',
      );
    },
  );
  test(
    'selected departure uses normalized ranges and rejects stale or removed selections',
    () {
      final selected = TripBrochure.fromTrip(
        fixture(),
        referenceDate: reference,
        selectedDate: 'Aug 21 – 23, 2026',
      );
      expect(content(selected), contains('Selected departure'));
      expect(content(selected), isNot(contains('Aug 14–16, 2026')));
      for (final date in ['invalid', 'Aug 1-3, 2026', 'Sep 4-6, 2026']) {
        expect(
          content(
            TripBrochure.fromTrip(
              fixture(),
              referenceDate: reference,
              selectedDate: date,
            ),
          ),
          contains('Upcoming departures'),
        );
      }
    },
  );
  test(
    'empty/inactive trips retain defaults and never advertise stale departures',
    () {
      expect(content(brochure({})), contains('Detailed itinerary coming soon'));
      expect(content(brochure({})), contains('Trekking shoes'));
      expect(
        content(
          brochure({
            'itinerary': [
              {'title': 'Arrival'},
            ],
          }),
        ),
        contains('Day 1: Arrival'),
      );
      expect(content(brochure({})), contains('Majestic'));
      expect(
        content(brochure({...fixture(), 'isActive': false})),
        contains('Currently unavailable for booking'),
      );
      expect(
        content(brochure({...fixture(), 'isActive': false})),
        contains('New dates coming soon'),
      );
    },
  );
  test('editor aliases override stale remote inclusion/exclusion values', () {
    final body = content(
      brochure({
        ...fixture(),
        'inclusions': ['Draft transport'],
        'exclusions': ['Draft dinner'],
      }),
    );
    expect(body, contains('Draft transport'));
    expect(body, isNot(contains('• Transport')));
    expect(body, contains('Draft dinner'));
    expect(body, isNot(contains('• Lunch')));
  });
  test(
    'malformed values, unsafe paths and huge content are contained without mutating trip schema',
    () {
      final value = brochure({
        'id': '../evil)',
        'title': '<script> / ..\\ trip',
        'itinerary': [
          null,
          {
            'activities': ['<script>literal</script>'],
          },
        ],
        'boardingLocations': [null],
      });
      expect(content(value), contains('<script>literal</script>'));
      expect(value.filename, matches(RegExp(r'^[a-z0-9-]+\.pdf$')));
      expect(
        value.bookingUrl,
        'https://www.teamweekendtrekkers.com/trips.html',
      );
      expect(() => brochure({'title': 'x' * 500001}), throwsFormatException);
    },
  );
  test(
    'image PDF streams, object offsets, page counts and URL fallback are well-formed',
    () {
      final image = Uint8List.fromList(ZLibEncoder().convert([255, 255, 255]));
      final bytes = TripBrochurePdf.encodePages([
        image,
        image,
      ], 'javascript:evil)');
      final source = latin1.decode(bytes);
      expect(source, startsWith('%PDF-1.4'));
      expect(source, contains('/Count 2'));
      expect(source, contains('/Filter /FlateDecode'));
      expect(source, isNot(contains('javascript:')));
      final start = int.parse(
        RegExp(r'startxref\n(\d+)').firstMatch(source)!.group(1)!,
      );
      expect(source.substring(start, start + 4), 'xref');
      final offsets = RegExp(
        r'^(\d{10}) 00000 n ',
        multiLine: true,
      ).allMatches(source).toList();
      for (var index = 0; index < offsets.length; index++) {
        expect(
          source.substring(int.parse(offsets[index].group(1)!)),
          startsWith('${index + 1} 0 obj\n'),
        );
      }
      expect(() => TripBrochurePdf.encodePages([], ''), throwsFormatException);
      expect(
        () => TripBrochurePdf.encodePages([Uint8List(0)], ''),
        throwsFormatException,
      );
    },
  );
  testWidgets(
    'real multipage renderer completes and encodes every page with a booking footer',
    (tester) async {
      final trip = {
        ...fixture(),
        'itinerary': [
          {
            'day': 'Day 1',
            'title': 'Long itinerary',
            'activities': List.generate(
              80,
              (index) =>
                  'Activity $index: walk, enjoy views 🥾 and return safely. ' *
                  4,
            ),
          },
        ],
      };
      final bytes = await tester.runAsync(
        () => TripBrochurePdf.generate(brochure(trip)),
      );
      expect(bytes, isNotNull);
      final source = latin1.decode(bytes!);
      final count = int.parse(
        RegExp(r'/Type /Pages /Count (\d+)').firstMatch(source)!.group(1)!,
      );
      expect(count, greaterThan(3));
      expect(RegExp(r'/Subtype /Image').allMatches(source).length, count);
      expect(RegExp(r'/Subtype /Link').allMatches(source).length, count);
      if (const bool.fromEnvironment('BROCHURE_VERIFY') &&
          !Platform.isAndroid) {
        await tester.runAsync(() async {
          await File('/tmp/twt-brochure-app.pdf').writeAsBytes(bytes);
          final website = File(
            '/home/simplifybytes/TravelBooking/js/trips-data.js',
          );
          final parsed = TripsParser.parseTripsDocument(
            await website.readAsString(),
          );
          expect(parsed.errors, isEmpty);
          expect(parsed.trips.length, 25);
          for (final item in parsed.trips) {
            final model = brochure(item), body = content(brochure(item));
            for (final day in item['itinerary'] as List) {
              for (final activity in day['activities'] as List) {
                expect(body, contains(activity.toString().trim()));
              }
            }
            expect(model.filename, endsWith('.pdf'));
          }
        });
      }
    },
  );

  Future<void> open(
    WidgetTester tester, {
    bool dark = false,
    Future<Uint8List> Function(TripBrochure)? generator,
    Future<void> Function(Uint8List, String)? share,
  }) async {
    if (!Platform.isAndroid) {
      tester.view.physicalSize = const Size(411, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? ThemeData.dark() : ThemeData.light(),
        home: TripBrochureScreen(
          brochure: brochure(),
          generator: generator,
          sharePdf: share,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'preview and sharing use a PDF filename/MIME-compatible bytes without publishing',
    (tester) async {
      final shared = <String>[];
      await open(
        tester,
        generator: (_) async => Uint8List.fromList([37, 80, 68, 70]),
        share: (bytes, filename) async {
          expect(bytes.take(4), [37, 80, 68, 70]);
          shared.add(filename);
        },
      );
      expect(find.text('Trip Brochure'), findsOneWidget);
      await tester.tap(find.byKey(const Key('brochure-share')));
      await tester.pumpAndSettle();
      expect(shared, ['misty-hills-brochure.pdf']);
      expect(find.byKey(const Key('brochure-error')), findsNothing);
    },
  );
  testWidgets(
    'generation failure retains preview and allows retry in dark mode',
    (tester) async {
      var calls = 0;
      await open(
        tester,
        dark: true,
        generator: (_) async {
          if (++calls == 1) throw StateError('Test failure');
          return Uint8List.fromList([37, 80, 68, 70]);
        },
        share: (_, _) async {},
      );
      await tester.tap(find.byKey(const Key('brochure-share')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('brochure-error')), findsOneWidget);
      await tester.tap(find.byKey(const Key('brochure-share')));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byKey(const Key('brochure-error')), findsNothing);
    },
  );
  testWidgets(
    'busy export blocks duplicate shares and returning before completion is safe',
    (tester) async {
      final pending = Completer<Uint8List>();
      var calls = 0;
      await open(
        tester,
        generator: (_) {
          calls++;
          return pending.future;
        },
        share: (_, _) async {},
      );
      await tester.tap(find.byKey(const Key('brochure-share')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('brochure-share')))
            .onPressed,
        isNull,
      );
      expect(calls, 1);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      pending.complete(Uint8List.fromList([37, 80, 68, 70]));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'editor brochure sees unsaved controllers and leaves provider records untouched',
    (tester) async {
      final settings = SettingsProvider(store: _MemoryStore());
      await settings.init();
      final trip = fixture(), before = jsonEncode(fixture());
      final provider = TripsProvider(AppSettings())..addTrip(trip);
      provider.markChangesSaved();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: provider),
          ],
          child: MaterialApp(home: TripEditScreen(trip: trip, index: 0)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Unsaved new title',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('trip-brochure')),
        450,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 35,
      );
      await tester.ensureVisible(find.byKey(const Key('trip-brochure')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('trip-brochure')));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved new title'), findsOneWidget);
      expect(provider.hasUnsavedChanges, isFalse);
      expect(jsonEncode(trip), before);
      expect(provider.trips.single['title'], 'Misty Hills 🥾');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Edit Trip'), findsOneWidget);
    },
  );
}

class _MemoryStore implements SettingsStore {
  String? value;
  @override
  Future<void> init() async {}
  @override
  Future<String?> read(String key) async => value;
  @override
  Future<void> write(String key, String next) async {
    value = next;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}
