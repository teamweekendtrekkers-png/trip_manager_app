import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/widgets/quick_trip_editor.dart';
import 'package:trip_manager_app/widgets/trip_editor_sections.dart';
import 'package:trip_manager_app/services/quick_edit_safety.dart';

Map<String,dynamic> trip() => {'id':'kannur','title':'Kannur Theyyam','price':'₹6,599','availableDates':['Oct 30-Nov 1, 2026'],'date':'Oct 30-Nov 1, 2026','highlights':['Theyyam night'],'contentSections':{'faqs':{'mode':'hidden'}},'customField':'keep'};

void main(){
  testWidgets('section arrows navigate in order and stop at the ends on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(360, 800); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    var selected = TripEditorSection.all;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(builder: (context, update) =>
      TripEditorSectionPicker(value: selected, onChanged: (next) => update(() => selected = next))))));
    expect(tester.widget<IconButton>(find.byKey(const Key('editor-previous-section'))).onPressed, isNull);
    for (final expected in TripEditorSection.values.skip(1)) {
      await tester.tap(find.byKey(const Key('editor-next-section'))); await tester.pumpAndSettle();
      expect(selected, expected);
    }
    expect(tester.widget<IconButton>(find.byKey(const Key('editor-next-section'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('editor-previous-section'))); await tester.pumpAndSettle();
    expect(selected, TripEditorSection.itinerary);
    expect(tester.takeException(), isNull);
  });
  test('quick edits retain concurrent unrelated fields and reject same-field changes',(){
    final initial=trip(),edited={...trip(),'price':'₹6999'},current={...trip(),'customField':'remote edit'};
    final merged=mergeQuickTripEdit(current,initial,edited);
    expect(merged['price'],'₹6999');expect(merged['customField'],'remote edit');expect(merged['contentSections'],initial['contentSections']);
    expect(()=>mergeQuickTripEdit({...current,'price':'₹7999'},initial,edited),throwsStateError);
    expect(()=>mergeQuickTripEdit({...current,'id':'other'},initial,edited),throwsStateError);
    expect(initial['price'],'₹6,599');
  });
  testWidgets('focused editor sections exclude other panels without leaving blank spacers',(tester) async {
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Column(children:visibleEditorChildren(TripEditorSection.photos,const [TripEditorPanel(section:TripEditorSection.basics,child:Text('Name field')),SizedBox(height:100),TripEditorPanel(section:TripEditorSection.photos,child:Text('Photo field'))])))));
    expect(find.text('Photo field'),findsOneWidget);expect(find.text('Name field'),findsNothing);expect(find.byWidgetPredicate((w)=>w is SizedBox && w.height==100),findsNothing);
  });
  testWidgets('quick price draft preserves unrelated fields and legacy visibility absence',(tester) async {
    Map<String,dynamic>? saved;final original=trip();
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(builder:(ctx)=>TextButton(onPressed:() async {saved=await showDialog<Map<String,dynamic>>(context:ctx,builder:(_)=>QuickTripEditor(trip:original));},child:const Text('Open quick edit'))))));
    await tester.tap(find.text('Open quick edit'));await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('quick-trip-price')),'6999');await tester.tap(find.byKey(const Key('quick-trip-save')));await tester.pumpAndSettle();
    expect(saved!['price'],'₹6999');expect(saved!['highlights'],original['highlights']);expect(saved!['contentSections'],original['contentSections']);expect(saved!['availableDates'],original['availableDates']);expect(saved!.containsKey('featured'),false);expect(saved!.containsKey('isActive'),false);expect(original['price'],'₹6,599');
  });
  testWidgets('quick edit rejects an invalid price and can remove every date',(tester) async {
    Map<String,dynamic>? saved;final original=trip();
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(builder:(ctx)=>TextButton(onPressed:() async {saved=await showDialog<Map<String,dynamic>>(context:ctx,builder:(_)=>QuickTripEditor(trip:original));},child:const Text('Open quick edit'))))));
    await tester.tap(find.text('Open quick edit'));await tester.pumpAndSettle();await tester.enterText(find.byKey(const Key('quick-trip-price')),'wrong');await tester.tap(find.byKey(const Key('quick-trip-save')));await tester.pumpAndSettle();expect(saved,isNull);expect(find.text('Enter a valid price, for example 4499.'),findsOneWidget);
    await tester.enterText(find.byKey(const Key('quick-trip-price')),'6599');await tester.ensureVisible(find.byTooltip('Remove departure 1'));await tester.tap(find.byTooltip('Remove departure 1'));await tester.pumpAndSettle();await tester.tap(find.byKey(const Key('quick-trip-save')));await tester.pumpAndSettle();expect(saved!['availableDates'],isEmpty);expect(saved!.containsKey('date'),false);expect(original['availableDates'],isNotEmpty);
  });
}

