import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/screens/upcoming_batches_screen.dart';

void main() {
  Widget buildSubject({
    required List<Map<String, dynamic>> trips,
    Brightness brightness = Brightness.light,
  }) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: brightness,
        ),
        useMaterial3: true,
      ),
      home: UpcomingBatchesScreen(
        trips: trips,
        referenceDate: DateTime(2026, 8, 13),
      ),
    );
  }

  testWidgets('previews an upcoming batch from the supplied in-memory trips', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        trips: [
          {
            'id': 'misty-hills',
            'title': 'Misty Hills Trek',
            'location': 'Western Ghats',
            'price': '₹2,999',
            'availableDates': ['Aug 14-16, 2026'],
            'isActive': true,
          },
        ],
      ),
    );

    expect(find.text('Upcoming Batches'), findsOneWidget);
    expect(find.text('Unsaved data preview'), findsOneWidget);
    expect(find.text('Next 1 batch'), findsOneWidget);
    expect(find.text('AUG 14–16, 2026'), findsOneWidget);
    expect(find.text('Friday Departures'), findsOneWidget);
    expect(find.text('Misty Hills Trek'), findsOneWidget);
    expect(find.text('Western Ghats'), findsOneWidget);
    expect(find.text('₹2,999'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the empty state in a dark Material theme', (tester) async {
    await tester.pumpWidget(
      buildSubject(trips: const [], brightness: Brightness.dark),
    );

    expect(find.text('New dates coming soon'), findsOneWidget);
    expect(
      find.text('There are no active trips with current or upcoming dates.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
