import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/services/departure_status.dart';
import 'package:trip_manager_app/services/trip_date_utils.dart';
import 'package:trip_manager_app/services/trips_parser.dart';
import 'package:trip_manager_app/widgets/departure_tools.dart';

void main() {
  const key = '2099-12-20/2099-12-22';
  test(
    'statuses round trip through publication and sold out blocks bookings',
    () {
      final original = TripsParser.parseTripsData('''const tripsData={demo:{
      title:"Demo",location:"Coorg",price:"₹4000",image:"images/demo.jpg",
      availableDates:["Dec 20-22, 2099"],isActive:true,
      confirmedDepartures:["$key"],soldOutDepartures:[]
    }};''').single;
      expect(original['confirmedDepartures'], [key]);
      final sold = setDepartureStatus(original, key, 'sold-out');
      expect(sold['closedDepartures'], [key]);
      expect(sold['confirmedDepartures'], isEmpty);
      expect(TripDateUtils.getUpcomingDateRanges(sold), isEmpty);
      expect(original['confirmedDepartures'], [key]);
      final parsed = TripsParser.parseTripsData(
        TripsParser.generateTripsDataJs([sold]),
      ).single;
      expect(parsed['soldOutDepartures'], [key]);
      final reopened = setDepartureStatus(parsed, key, 'available');
      expect(reopened['closedDepartures'], isEmpty);
      expect(reopened['soldOutDepartures'], isEmpty);
      expect(TripDateUtils.getUpcomingDateRanges(reopened), hasLength(1));
      final confirmed = setDepartureStatus(sold, key, 'confirmed');
      expect(confirmed['confirmedDepartures'], [key]);
      expect(confirmed['closedDepartures'], isEmpty);
      expect(
        () => setDepartureStatus(original, 'not-a-date', 'confirmed'),
        throwsArgumentError,
      );
    },
  );
  testWidgets('departure actions expose explicit batch statuses', (
    tester,
  ) async {
    String? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DepartureTools(
            dates: const ['Dec 20-22, 2099'],
            closedKeys: const [],
            onToggle: (_) {},
            onDuplicate: (_) {},
            onStatus: (date, status) {
              expect(date, key);
              chosen = status;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('departure-tools')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Departure actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark sold out'));
    await tester.pumpAndSettle();
    expect(chosen, 'sold-out');
  });
}
