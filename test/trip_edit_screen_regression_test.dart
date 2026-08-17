import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/providers/settings_provider.dart';
import 'package:trip_manager_app/providers/trips_provider.dart';
import 'package:trip_manager_app/screens/trip_edit_screen.dart';

void main() {
  Map<String, dynamic> tripWithDates(List<String> dates) => <String, dynamic>{
    'id': 'misty-hills',
    'title': 'Misty Hills Trek',
    'name': 'Misty Hills Trek',
    'location': 'Western Ghats',
    'destination': 'Western Ghats',
    'about': 'A quiet weekend trek.',
    'description': 'A quiet weekend trek.',
    'date': dates.isEmpty ? '' : dates.first,
    'price': '₹999',
    'image': '',
    'featured': false,
    'isActive': true,
    'availableDates': dates,
    'highlights': <String>['Sunrise views'],
    'itinerary': <Map<String, dynamic>>[],
    'inclusions': <String>[],
    'exclusions': <String>[],
    'thingsToCarry': <String>[],
    'galleryImages': <String>[],
    'boardingLocations': <Map<String, dynamic>>[],
  };

  Widget buildSubject(TripsProvider provider, Map<String, dynamic> trip) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TripsProvider>.value(value: provider),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(store: _MemorySettingsStore()),
        ),
      ],
      child: MaterialApp(home: TripEditScreen(trip: trip, index: 0)),
    );
  }

  Finder appBarSaveButton() => find.descendant(
    of: find.byType(AppBar),
    matching: find.byIcon(Icons.save),
  );

  testWidgets('keeps an invalid legacy date visible and blocks saving', (
    tester,
  ) async {
    final trip = tripWithDates(<String>['weekend after monsoon']);
    final provider = TripsProvider(AppSettings())..addTrip(trip);
    provider.markChangesSaved();

    await tester.pumpWidget(buildSubject(provider, trip));

    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('date-range-0')),
        matching: find.text('weekend after monsoon'),
      ),
      findsOneWidget,
    );
    expect(find.text('Invalid — edit or remove before saving'), findsOneWidget);

    await tester.tap(appBarSaveButton());
    await tester.pump();

    expect(
      find.text('Fix or remove 1 invalid date range(s) before saving.'),
      findsOneWidget,
    );
    expect(find.text('Edit Trip'), findsOneWidget);
    expect(provider.hasUnsavedChanges, isFalse);
    expect(provider.trips.single['availableDates'], <String>[
      'weekend after monsoon',
    ]);
  });

  testWidgets('shows semantic duplicate ranges and blocks saving', (
    tester,
  ) async {
    final trip = tripWithDates(<String>[
      'Aug 14-16, 2026',
      'Aug 14 – 16, 2026',
    ]);
    final provider = TripsProvider(AppSettings())..addTrip(trip);
    provider.markChangesSaved();

    await tester.pumpWidget(buildSubject(provider, trip));
    expect(
      find.text('Duplicate — edit or remove before saving'),
      findsNWidgets(2),
    );

    await tester.tap(appBarSaveButton());
    await tester.pump();
    expect(
      find.text('Remove 1 duplicate date range(s) before saving.'),
      findsOneWidget,
    );
    expect(provider.hasUnsavedChanges, isFalse);
  });

  testWidgets(
    'shows the website empty-date preview without a validation error',
    (tester) async {
      final trip = tripWithDates(const <String>[]);
      final provider = TripsProvider(AppSettings())..addTrip(trip);
      provider.markChangesSaved();

      await tester.pumpWidget(buildSubject(provider, trip));

      expect(find.byKey(const Key('dates-empty-state')), findsOneWidget);
      expect(find.textContaining('New dates coming soon'), findsOneWidget);
      expect(find.textContaining('Invalid —'), findsNothing);
    },
  );

  testWidgets('calendar adds, edits, and removes a canonical range', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final trip = tripWithDates(const <String>[]);
    final provider = TripsProvider(AppSettings())..addTrip(trip);
    provider.markChangesSaved();

    await tester.pumpWidget(buildSubject(provider, trip));
    await tester.scrollUntilVisible(
      find.byKey(const Key('add-date-range')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('add-date-range')));
    await tester.pumpAndSettle();

    expect(find.text('Add trip dates'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp(r'August 14, 2026')).first);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel(RegExp(r'August 16, 2026')).first);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Aug 14-16, 2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('edit-date-0')));
    await tester.pumpAndSettle();
    expect(find.text('Edit trip dates'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp(r'August 14, 2026')).first);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel(RegExp(r'August 17, 2026')).first);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Aug 14-17, 2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('remove-date-0')));
    await tester.pump();
    expect(find.byKey(const Key('dates-empty-state')), findsOneWidget);
  });

  testWidgets('calendar can edit valid ranges outside the default window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final trip = tripWithDates(<String>[
      'Dec 31-Jan 1, 2019-2020',
      'Jan 1-2, 2099',
    ]);
    final provider = TripsProvider(AppSettings())..addTrip(trip);
    provider.markChangesSaved();

    await tester.pumpWidget(buildSubject(provider, trip));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('edit-date-0')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey<String>('edit-date-0')));
    await tester.pumpAndSettle();
    expect(find.text('Edit trip dates'), findsOneWidget);
    expect(find.text('December 2019'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('edit-date-1')));
    await tester.pumpAndSettle();
    expect(find.text('Edit trip dates'), findsOneWidget);
    expect(find.text('January 2099'), findsOneWidget);
  });

  testWidgets('visibility switches update immediately and persist on save', (
    tester,
  ) async {
    final trip = tripWithDates(<String>['Aug 14-16, 2026']);
    final provider = TripsProvider(AppSettings())..addTrip(trip);
    provider.markChangesSaved();

    await tester.pumpWidget(buildSubject(provider, trip));
    await tester.scrollUntilVisible(
      find.text('Active Trip'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.text('Active Trip'));
    await tester.pump();
    expect(
      find.text('Trip is greyed out and hidden from bookings'),
      findsOneWidget,
    );

    await tester.tap(appBarSaveButton());
    await tester.pumpAndSettle();

    expect(provider.trips.single['isActive'], isFalse);
    expect(provider.hasUnsavedChanges, isTrue);
  });

  testWidgets('opens every difficulty label used by the live website', (
    tester,
  ) async {
    for (final difficulty in const <String>[
      'Challenging',
      'Easy-Moderate',
      'Moderate-Hard',
      'Website Future Label',
    ]) {
      final trip = tripWithDates(const <String>[])..['difficulty'] = difficulty;
      final provider = TripsProvider(AppSettings())..addTrip(trip);

      await tester.pumpWidget(buildSubject(provider, trip));
      await tester.pump();

      expect(tester.takeException(), isNull, reason: difficulty);
      expect(find.text(difficulty), findsOneWidget, reason: difficulty);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}

final class _MemorySettingsStore implements SettingsStore {
  @override
  Future<void> clear() async {}

  @override
  Future<void> init() async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}
