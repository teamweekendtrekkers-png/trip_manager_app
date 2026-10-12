import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/widgets/trip_content_editor.dart';

void main(){
  Map<String,dynamic> defaults()=>{
    'glance':{'mode':'default','heading':'Trip at a glance','expanded':true,'items':[{'label':'Location','field':'location','value':'','icon':'location'}]},
    'cancellation':{'mode':'default','heading':'Cancellation policy','expanded':false,'items':[{'minDays':0,'maxDays':null,'percent':100}],'refundNote':'Contact us','changeNote':'Contact us'},
    'guidelines':{'mode':'default','heading':'Guidelines','expanded':false,'items':[]},
    'faqs':{'mode':'default','heading':'FAQs','expanded':false,'items':[]},
  };
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
  });
  testWidgets('content preview displays both mobile and desktop linked values',(tester) async {
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:TripContentEditor(value:const {},defaults:defaults(),trip:const {'location':'Kannur'},onChanged:(_){})))));
    await tester.tap(find.text('Mobile & desktop preview'));await tester.pumpAndSettle();expect(find.text('Mobile'),findsOneWidget);expect(find.text('Desktop'),findsOneWidget);expect(find.text('Location: Kannur'),findsNWidgets(2));
  });
}
