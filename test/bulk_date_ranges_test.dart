import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/providers/trips_provider.dart';
import 'package:trip_manager_app/screens/manager_tools_screen.dart';

TripsProvider fixture() => TripsProvider(AppSettings())..restoreVersion([
 {'id':'a','title':'Alpha','availableDates':['Dec 1-3, 2099'],'custom':'keep'},
 {'id':'b','title':'Beta','availableDates':['Dec 8-10, 2099']},
]);
void main(){
 test('multiple date ranges deduplicate, preserve unrelated trips and undo together',(){
  final provider=fixture();addTearDown(provider.dispose);
  final before=jsonEncode(provider.trips);
  provider.applyBulkDateRanges({'a'},['Dec 15-17, 2099','Dec 22-24, 2099','Dec 15–17, 2099']);
  expect(provider.trips[0]['availableDates'],['Dec 1-3, 2099','Dec 15-17, 2099','Dec 22-24, 2099']);
  expect(provider.trips[0]['custom'],'keep');
  expect(provider.trips[1]['availableDates'],['Dec 8-10, 2099']);
  provider.undo();expect(jsonEncode(provider.trips),before);
  expect(()=>provider.applyBulkDateRanges({'a'},['Dec 15-17, 2099','bad range']),throwsArgumentError);
  expect(jsonEncode(provider.trips),before);
  provider.applyBulkDateRanges({'a'},['Dec 1-3, 2099','Dec 8-10, 2099'],remove:true);
  expect(provider.trips[0]['availableDates'],isEmpty);
  expect(provider.trips[1]['availableDates'],['Dec 8-10, 2099']);
 });
 testWidgets('bulk dialog reviews several pasted ranges before one application',(tester) async{
  final provider=fixture();addTearDown(provider.dispose);
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(builder:(context)=>TextButton(
   onPressed:()=>bulkDates(context,provider),child:const Text('Bulk dates'),
  )))));
  await tester.tap(find.text('Bulk dates'));await tester.pumpAndSettle();
  await tester.tap(find.text('Paste multiple ranges'));await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField),'Dec 15-17, 2099\nDec 22-24, 2099\nDec 15–17, 2099');
  await tester.tap(find.text('Add ranges'));await tester.pumpAndSettle();
  expect(find.byType(InputChip),findsNWidgets(2));
  expect(find.text('1 duplicate range(s) skipped.'),findsOneWidget);
  await tester.tap(find.text('Alpha'));await tester.pumpAndSettle();
  await tester.tap(find.text('Add 2 range(s) to 1 trip(s)'));await tester.pumpAndSettle();
  expect(provider.trips[0]['availableDates'],hasLength(3));
  expect(provider.trips[1]['availableDates'],hasLength(1));
  expect(tester.takeException(),isNull);
 });
}
