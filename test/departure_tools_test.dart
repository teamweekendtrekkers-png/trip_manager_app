import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/widgets/departure_tools.dart';

void main(){
  testWidgets('departure tools distinguish closing from deleting and offer duplication', (tester) async {
    final closed=<String>[];int? copied;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:StatefulBuilder(builder:(context,set)=>DepartureTools(
      dates:const ['Dec 20-22, 2099'],closedKeys:closed,
      onToggle:(key)=>set((){if(!closed.remove(key))closed.add(key);}),
      onDuplicate:(index)=>copied=index,
    )))));
    await tester.tap(find.byKey(const Key('departure-tools')));await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Departure actions'));await tester.pumpAndSettle();
    await tester.tap(find.text('Close bookings'));await tester.pumpAndSettle();
    expect(closed,['2099-12-20/2099-12-22']);expect(find.text('Bookings closed'),findsOneWidget);
    await tester.tap(find.byTooltip('Departure actions'));await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate departure'));await tester.pumpAndSettle();expect(copied,0);
    await tester.tap(find.byTooltip('Departure actions'));await tester.pumpAndSettle();
    await tester.tap(find.text('Reopen bookings'));await tester.pumpAndSettle();expect(closed,isEmpty);
  });
}
