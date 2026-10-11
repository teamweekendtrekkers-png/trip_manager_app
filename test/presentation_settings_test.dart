import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/models/homepage_config.dart';
import 'package:trip_manager_app/models/trip_card_settings.dart';
import 'package:trip_manager_app/services/trips_parser.dart';

void main() {
  test('legacy homepage keeps text and selections with optional presentation defaults', () {
    final config = HomepageConfig.parse(jsonEncode({'version':1, 'hero':{'title':'Custom title'}})).toJson();
    expect(config['hero']['title'], 'Custom title');
    expect(config['presentation']['heroMotion'], false);
    expect(config['presentation']['heroSlides'], isEmpty);
  });
  test('hero controls preserve safe photos and reject unsupported palettes and injected paths', () {
    final valid = {'preset':'ocean', 'heroMobileImage':'images/mobile.jpg', 'heroFocalPoint':'top', 'heroMotion':true, 'heroSlides':['images/second.jpg','https://example.com/third.webp']};
    expect(HomepageConfig.parse(jsonEncode({'version':1, 'presentation':valid})).toJson()['presentation'], valid);
    for (final invalid in [
      {...valid,'preset':'custom-red'}, {...valid,'heroMobileImage':'images/../secret'},
      {...valid,'heroMotion':'true'}, {...valid,'heroSlides':['images/1.jpg','images/2.jpg','images/3.jpg']},
      {...valid,'heroFocalPoint':'50%;evil'}, {...valid,'heroSlides':['javascript:alert(1)']},
    ]) {
      expect(() => HomepageConfig.parse(jsonEncode({'version':1,'presentation':invalid})), throwsFormatException);
    }
  });
  test('photo focus round-trips without changing descriptions and helper code', () {
    const source = 'const tripsData = {};\n// keep helpers';
    final result = TripsParser.replaceTripsDataObject(source:source,trips:[
      {'id':'focus-trip','title':'Custom trip','location':'Coorg','price':'₹3500','image':'images/cover.jpg','duration':'2D/1N','difficulty':'Easy','about':'Keep my copy','cardFocalPoint':'left','imageFocalPoint':'top'}
    ]);
    expect(result.success, true, reason:result.errors.join('\n'));
    expect(result.content, endsWith('// keep helpers'));
    final trip=TripsParser.parseTripsDocument(result.content!).trips.single;
    expect(trip['cardFocalPoint'],'left');expect(trip['imageFocalPoint'],'top');
    expect(trip['about'],'Keep my copy');
    expect(TripCardSettings.fieldError('cardFocalPoint','url(evil)'),isNotNull);
  });
}
