import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/widgets/trip_content_editor.dart';

  Map<String,dynamic> defaults()=>{
    'glance':{'mode':'default','heading':'Trip at a glance','expanded':true,'items':[{'label':'Location','field':'location','value':'','icon':'location'}]},
    'cancellation':{'mode':'default','heading':'Cancellation policy','expanded':false,'items':[{'minDays':0,'maxDays':null,'percent':100}],'refundNote':'Contact us','changeNote':'Contact us'},
    'guidelines':{'mode':'default','heading':'Guidelines','expanded':false,'items':[]},
    'faqs':{'mode':'default','heading':'FAQs','expanded':false,'items':[]},
  };

void main(){
  testWidgets('create an independent Why choose us section and preview it',(tester) async {
    var value=<String,dynamic>{};
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:StatefulBuilder(builder:(context,set)=>TripContentEditor(value:value,defaults:defaults(),trip:const {'highlights':['Existing experience']},onChanged:(next)=>set(()=>value=next)))))));
    await tester.tap(find.text('Add section'));await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('new-section-heading')),'Why choose us');
    await tester.tap(find.text('Create section'));await tester.pumpAndSettle();
    expect(value['custom_why_choose_us']['heading'],'Why choose us');expect(value.containsKey('highlights'),false);
    final addItem=find.descendant(of:find.byKey(const ValueKey('trip-content-custom_why_choose_us')),matching:find.text('Add item'));
    await tester.ensureVisible(addItem);await tester.tap(addItem);await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField,'Description'),'Local hosts and personal support.');
    await tester.tap(find.text('Save item'));await tester.pumpAndSettle();
    expect(value['custom_why_choose_us']['items'][0]['description'],'Local hosts and personal support.');
    await tester.ensureVisible(find.text('Mobile & desktop preview'));await tester.tap(find.text('Mobile & desktop preview'));await tester.pumpAndSettle();
    expect(find.descendant(of:find.byType(AlertDialog),matching:find.textContaining('Local hosts and personal support.')),findsNWidgets(2));
    expect(find.descendant(of:find.byType(AlertDialog),matching:find.text('Why choose us')),findsNWidgets(2));
    expect(tester.takeException(),isNull);
  });
  testWidgets('renaming highlights preserves trip text and visibility through hide/restore',(tester) async {
    var value=<String,dynamic>{};
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:StatefulBuilder(builder:(context,set)=>TripContentEditor(value:value,defaults:defaults(),trip:const {'highlights':['Theyyam night','Coastal sunsets']},onChanged:(next)=>set(()=>value=next)))))));
    await tester.ensureVisible(find.text('What Makes It Special'));await tester.tap(find.text('What Makes It Special'));await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('content-mode-highlights')));await tester.tap(find.byKey(const ValueKey('content-mode-highlights')));await tester.pumpAndSettle();await tester.tap(find.text('Customise this trip').last);await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('highlights-heading')));await tester.enterText(find.byKey(const ValueKey('highlights-heading')),'Why Choose Us');await tester.pumpAndSettle();
    expect(value['highlights']['heading'],'Why Choose Us');expect(value['highlights']['items'][0]['description'],'Theyyam night');expect(value['highlights']['useTripHighlights'],false);
    await tester.ensureVisible(find.byTooltip('Hide item').first);await tester.tap(find.byTooltip('Hide item').first);await tester.pumpAndSettle();expect(value['highlights']['items'][0]['enabled'],false);
    await tester.ensureVisible(find.byKey(const ValueKey('content-mode-highlights')));await tester.tap(find.byKey(const ValueKey('content-mode-highlights')));await tester.pumpAndSettle();await tester.tap(find.text('Hide section').last);await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('content-mode-highlights')));await tester.pumpAndSettle();await tester.tap(find.text('Customise this trip').last);await tester.pumpAndSettle();expect(value['highlights']['heading'],'Why Choose Us');expect(value['highlights']['items'][0]['enabled'],false);expect(value['highlights']['items'][1]['description'],'Coastal sunsets');
  });


  testWidgets('custom section editing preserves linked fields and stable input focus',(tester) async {
    var value=<String,dynamic>{};final inherited=defaults();
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:StatefulBuilder(builder:(context,set)=>TripContentEditor(value:value,defaults:inherited,trip:const {'location':'Kannur'},onChanged:(next)=>set(()=>value=next)))))));
    await tester.tap(find.text('Trip at a glance'));await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('content-mode-glance')));await tester.pumpAndSettle();
    await tester.tap(find.text('Customise this trip').last);await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('glance-heading')),'Coastal trip facts');await tester.pump();
    expect(value['glance']['heading'],'Coastal trip facts');expect(value['glance']['items'][0]['field'],'location');expect(inherited['glance']['heading'],'Trip at a glance');
    await tester.ensureVisible(find.byTooltip('Hide item'));await tester.tap(find.byTooltip('Hide item'));await tester.pumpAndSettle();expect(value['glance']['items'][0]['enabled'],false);expect(value['glance']['items'][0]['field'],'location');
    await tester.ensureVisible(find.byKey(const ValueKey('content-mode-glance')));
    await tester.tap(find.byKey(const ValueKey('content-mode-glance')));await tester.pumpAndSettle();await tester.tap(find.text('Hide section').last);await tester.pumpAndSettle();expect(value['glance']['mode'],'hidden');
    await tester.tap(find.byKey(const ValueKey('content-mode-glance')));await tester.pumpAndSettle();await tester.tap(find.text('Customise this trip').last);await tester.pumpAndSettle();expect(value['glance']['heading'],'Coastal trip facts');expect(value['glance']['items'][0]['enabled'],false);
  });
  testWidgets('content preview displays both mobile and desktop linked values',(tester) async {
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:TripContentEditor(value:const {},defaults:defaults(),trip:const {'location':'Kannur'},onChanged:(_){})))));
    await tester.tap(find.text('Mobile & desktop preview'));await tester.pumpAndSettle();expect(find.text('Mobile'),findsOneWidget);expect(find.text('Desktop'),findsOneWidget);expect(find.text('Location: Kannur'),findsNWidgets(2));
  });
}

