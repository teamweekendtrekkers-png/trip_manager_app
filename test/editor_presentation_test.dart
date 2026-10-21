import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/widgets/inline_formatting.dart';
import 'package:trip_manager_app/widgets/gallery_order_editor.dart';
import 'package:trip_manager_app/widgets/batch_color_picker.dart';
import 'package:trip_manager_app/services/trips_parser.dart';

void main(){
 test('selected words toggle bold, italic, both and removal without losing emoji',(){
  final text='🌞 Meet your guide';
  var value=TextEditingValue(text:text,selection:TextSelection(baseOffset:text.indexOf('your'),extentOffset:text.indexOf('your')+4));
  value=toggleInlineStyle(value,InlineStyle.bold);expect(value.text,'🌞 Meet **your** guide');
  value=toggleInlineStyle(value,InlineStyle.italic);expect(value.text,'🌞 Meet ***your*** guide');
  value=toggleInlineStyle(value,InlineStyle.both);expect(value.text,text);
  expect(plainInlineText('**bold** and *italic* and ***both***'),'bold and italic and both');
  expect(plainInlineText('**Local *hosts***'),'Local hosts');
 });
 test('multiline activities retain their rows and empty selections are unchanged',(){
  const text='First activity\nSecond activity';
  final value=TextEditingValue(text:text,selection:TextSelection(baseOffset:0,extentOffset:text.length));
  expect(toggleInlineStyle(value,InlineStyle.bold).text,'**First activity**\n**Second activity**');
  const collapsed=TextEditingValue(text:'hello',selection:TextSelection.collapsed(offset:2));
  expect(toggleInlineStyle(collapsed,InlineStyle.bold),collapsed);
 });
 test('gallery reorder leaves input and separately selected card cover intact',(){
  final photos=['images/a.jpg','images/b.jpg','images/c.jpg'];
  expect(reorderGallery(photos,0,3),['images/b.jpg','images/c.jpg','images/a.jpg']);
  expect(photos,['images/a.jpg','images/b.jpg','images/c.jpg']);
 });
 test('formatted text, gallery sequence and colour survive source-preserving publication',(){
  const source='''const tripsData = { demo: {title:"Demo",price:"₹999",image:"images/cover.jpg",galleryImages:["images/a.jpg","images/b.jpg"],about:"Hello",isActive:true} };
// Preserve this footer.
''';
  final parsed=TripsParser.parseTripsDocument(source);
  expect(parsed.isValid,isTrue,reason:parsed.errors.join('\n'));
  final trip=parsed.trips.single;
  trip['description']='Meet **local hosts** and *explore*';
  trip['about']=trip['description'];
  trip['galleryImages']=['images/b.jpg','images/a.jpg'];trip['cardImage']='images/cover.jpg';trip['batchColor']='violet';trip['maxTravellers']=6;
  final result=TripsParser.replaceTripsDataObject(source:source,trips:[trip]);
  expect(result.success,isTrue,reason:result.errors.join('\n'));
  final saved=TripsParser.parseTripsDocument(result.content!).trips.single;
  expect(saved['about'],trip['about']);expect(saved['galleryImages'],trip['galleryImages']);expect(saved['cardImage'],'images/cover.jpg');expect(saved['batchColor'],'violet');expect(saved['maxTravellers'],6);
  expect(result.content,contains('// Preserve this footer.'));
  trip['batchColor']='red;display:none';expect(TripsParser.replaceTripsDataObject(source:source,trips:[trip]).success,isFalse);
 });
 testWidgets('selection formatting updates the field callback, as normal typing does',(tester)async{
  final controller=TextEditingController(text:'Hello traveller');String? saved;
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:TextField(controller:controller,contextMenuBuilder:formattingContextMenu,onChanged:(value)=>saved=value))));
  await tester.tap(find.byType(TextField));controller.selection=const TextSelection(baseOffset:6,extentOffset:15);await tester.pump();
  tester.state<EditableTextState>(find.byType(EditableText)).showToolbar();await tester.pumpAndSettle();
  await tester.tap(find.text('Bold').last);await tester.pumpAndSettle();
  expect(controller.text,'Hello **traveller**');expect(saved,controller.text);
  await tester.pumpWidget(const SizedBox());controller.dispose();
 });
 testWidgets('numbered photos have keyboard-friendly move actions',(tester)async{
  var photos=['images/a.jpg','images/b.jpg'];
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:StatefulBuilder(builder:(context,set)=>GalleryOrderEditor(photos:photos,imageBuilder:(_)=>const ColoredBox(color:Colors.green),onChanged:(value)=>set(()=>photos=value),onRemove:(_){ })))));
  expect(find.text('Photo 1'),findsOneWidget);expect(find.text('Photo 2'),findsOneWidget);
  await tester.tap(find.byTooltip('Photo 1 actions'));await tester.pumpAndSettle();await tester.tap(find.text('Move down'));await tester.pumpAndSettle();
  expect(photos,['images/b.jpg','images/a.jpg']);
 });
 testWidgets('batch colour selection previews the chosen trip palette',(tester)async{
  var colour='forest';
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:StatefulBuilder(builder:(context,set)=>BatchColorPicker(value:colour,onChanged:(value)=>set(()=>colour=value))))));
  await tester.tap(find.byKey(const ValueKey('batch-color-blue')));await tester.pumpAndSettle();expect(colour,'blue');
 });
}
