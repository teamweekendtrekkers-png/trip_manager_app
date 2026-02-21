import 'package:trip_manager_app/services/trips_parser.dart';

void main() {
  // 1. Parse the real featured-trips.js
  const featuredJs = '''
const featuredTripIds = [
    "rameshwaram-dhanushkodi",
    "varkala-kochi-christmas",
    "kannur-theyyam",
    "gokarna-new-year-party",
];
  ''';
  
  final ids = TripsParser.parseFeaturedTripIds(featuredJs);
  print('✓ Parsed ${ids.length} featured IDs: $ids');
  assert(ids.length == 4);
  assert(ids.contains('rameshwaram-dhanushkodi'));
  assert(ids.contains('gokarna-new-year-party'));
  
  // 2. Simulate trips loaded from trips-data.js
  final trips = [
    {'id': 'gokarna-new-year-party', 'title': 'Gokarna', 'featured': false},
    {'id': 'rameshwaram-dhanushkodi', 'title': 'Rameshwaram', 'featured': false},
    {'id': 'nandi-hills', 'title': 'Nandi Hills Sunrise', 'featured': false},
    {'id': 'ooty', 'title': 'Ooty', 'featured': false},
  ];
  
  // 3. Sync featured from featured-trips.js (like loadTrips does)
  for (final trip in trips) {
    trip['featured'] = ids.contains(trip['id']);
  }
  
  print('After sync from featured-trips.js:');
  for (final t in trips) {
    print('  ${t["id"]}: featured=${t["featured"]}');
  }
  assert(trips[0]['featured'] == true);  // gokarna
  assert(trips[1]['featured'] == true);  // rameshwaram
  assert(trips[2]['featured'] == false); // nandi-hills
  assert(trips[3]['featured'] == false); // ooty
  print('✓ Sync correct');
  
  // 4. User toggles nandi-hills to featured
  trips[2]['featured'] = true;
  print('\nAfter toggling nandi-hills:');
  print('  nandi-hills: featured=${trips[2]["featured"]}');
  
  // 5. Generate featured-trips.js
  final output = TripsParser.generateFeaturedTripsJs(trips);
  print('\n--- Generated featured-trips.js ---');
  print(output);
  print('--- End ---');
  
  // 6. Verify the output
  assert(output.contains('"nandi-hills"'), 'nandi-hills should be in output');
  assert(output.contains('"gokarna-new-year-party"'), 'gokarna should be in output');
  assert(output.contains('"rameshwaram-dhanushkodi"'), 'rameshwaram should be in output');
  assert(!output.contains('"ooty"'), 'ooty should NOT be in output');
  assert(output.contains('const featuredTripIds'), 'Should have const declaration');
  assert(output.contains('function getFeaturedTrips()'), 'Should have function');
  
  // 7. Re-parse the generated output
  final reParsed = TripsParser.parseFeaturedTripIds(output);
  print('Re-parsed IDs: $reParsed');
  assert(reParsed.length == 3);
  assert(reParsed.contains('nandi-hills'));
  assert(reParsed.contains('gokarna-new-year-party'));
  assert(reParsed.contains('rameshwaram-dhanushkodi'));
  
  // 8. Test unfeaturing - toggle nandi-hills OFF
  trips[2]['featured'] = false;
  final output2 = TripsParser.generateFeaturedTripsJs(trips);
  final reParsed2 = TripsParser.parseFeaturedTripIds(output2);
  assert(reParsed2.length == 2);
  assert(!reParsed2.contains('nandi-hills'));
  print('✓ Unfeaturing works too');
  
  print('\n🎉 ALL CHECKS PASSED - Featured toggle is working correctly!');
}
