import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/models/homepage_config.dart';
import 'package:trip_manager_app/widgets/website_pages_editor.dart';
void main(){
 test('older configurations gain editable pages and roundtrip custom copy',(){
  final data=HomepageConfig.initial().toJson()..remove('pages');
  final legacy=HomepageConfig.parse(jsonEncode(data)).toJson();
  expect(legacy['pages']['aboutTitle'],'About Us');
  legacy['pages']['aboutTitle']='Meet our team';
  legacy['pages']['aboutPromises']='Kind hosts\\nClear prices';
  expect(HomepageConfig.parse(jsonEncode(legacy)).toJson()['pages'],legacy['pages']);
  legacy['pages']['aboutTitle']=42;
  expect(()=>HomepageConfig.parse(jsonEncode(legacy)),throwsFormatException);
 });
 testWidgets('About page editor updates the selected field without changing other pages',(tester)async{
  final pages=HomepageConfig.initial().toJson()['pages'] as Map<String,dynamic>;
  var changes=0;
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:WebsitePagesEditor(pages:pages,onChanged:()=>changes++,initiallyExpanded:true)))));
  await tester.enterText(find.byKey(const ValueKey('website-page-aboutTitle')),'Our community');
  expect(pages['aboutTitle'],'Our community');expect(pages['contactTitle'],'Contact Us');expect(changes,1);
 });
}
