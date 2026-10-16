import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/models/trip_content_settings.dart';
import 'package:trip_manager_app/services/trips_parser.dart';

void main(){
  test('extra sections survive parsing, ordering and visibility changes',(){
    final first=TripContentSettings.customSection('Why choose us')..['items']=[{'title':'Local hosts','description':'Meet people who know the destination.','icon':'group'}];
    final second=TripContentSettings.customSection('Our approach');
    final sections={'custom_why_choose_us':first,'custom_our_approach':second};
    TripContentSettings.validate(sections);
    final reordered=TripContentSettings.moveSection(sections,'custom_our_approach',-1);
    expect(TripContentSettings.customKeys(reordered),['custom_our_approach','custom_why_choose_us']);
    reordered['custom_why_choose_us']['mode']='hidden';
    final trip={'id':'culture','title':'Culture','contentSections':reordered};
    final parsed=TripsParser.parseTripsData(TripsParser.generateTripsDataJs([trip])).single;
    expect(parsed['contentSections'],reordered);
    expect(TripContentSettings.customKeys(parsed['contentSections']),['custom_our_approach','custom_why_choose_us']);
    expect(TripContentSettings.newKey(sections,'Why choose us'),'custom_why_choose_us_2');
  });
  test('extra sections reject malformed keys and missing descriptions',(){
    expect(()=>TripContentSettings.validate({'custom_<script>':TripContentSettings.customSection('Bad')}),throwsFormatException);
    final section=TripContentSettings.customSection('Why choose us')..['items']=[{'title':'Hosts','description':'','icon':'group'}];
    expect(()=>TripContentSettings.validate({'custom_why':section}),throwsFormatException);
    section['items']=[{'description':'Personal support','icon':'group'}];
    TripContentSettings.validate({'custom_why':section});
  });
  test('custom highlights heading and text survive parsing',(){final section={'mode':'custom','heading':'Why Choose Us','expanded':false,'useTripHighlights':false,'items':[{'title':'Support','description':'Trip coordinator','enabled':true}]};TripContentSettings.validate({'highlights':section});final trip={'id':'culture','title':'Culture','highlights':['Existing highlight'],'contentSections':{'highlights':section}};expect(TripsParser.parseTripsData(TripsParser.generateTripsDataJs([trip])).single['contentSections'],trip['contentSections']);});

  Map<String,dynamic> policy()=>{'mode':'custom','heading':'Cancellation policy','expanded':false,'items':[{'minDays':0,'maxDays':3,'percent':100},{'minDays':4,'maxDays':5,'percent':50},{'minDays':6,'maxDays':null,'percent':25}],'refundNote':'5–7 business days','changeNote':'Contact us'};
  test('cancellation ranges reject missing and overlapping days',(){TripContentSettings.validate({'cancellation':policy()});for(final start in [3,5]){final p=policy();p['items'][1]['minDays']=start;expect(()=>TripContentSettings.validate({'cancellation':p}),throwsFormatException);}});
  test('hidden and intentionally empty custom content are valid',(){TripContentSettings.validate({'faqs':{'mode':'hidden'},'guidelines':{'mode':'custom','heading':'Guidelines','expanded':false,'items':[]}});});
  test('linked facts reject unsupported fields',(){expect(()=>TripContentSettings.validate({'glance':{'mode':'custom','heading':'Facts','expanded':true,'items':[{'label':'Location','field':'unknown','value':'','icon':'location'}]}}),throwsFormatException);});
  test('custom content survives full generation and parsing',(){final trip={'id':'culture','title':'Culture tour','location':'Kerala','price':'₹1000','image':'images/trips/test.jpg','isActive':true,'contentSections':{'cancellation':policy(),'faqs':{'mode':'hidden'}}};final source=TripsParser.generateTripsDataJs([trip]);final parsed=TripsParser.parseTripsData(source);expect(parsed.single['contentSections'],trip['contentSections']);});
}

