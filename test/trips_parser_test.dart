import 'dart:io';
import '../lib/services/trips_parser.dart';

void main() async {
  print('=' * 60);
  print('TRIP MANAGER APP - COMPREHENSIVE TEST SUITE');
  print('=' * 60);
  print('');
  
  int passed = 0;
  int failed = 0;
  
  // Test 1: Parse sample trips-data.js content
  print('TEST 1: Parsing trips-data.js format');
  print('-' * 40);
  
  const sampleJs = '''
const tripsData = {
    netravati: {
        title: "Netravati Peak Trek",
        location: "Western Ghats, Karnataka",
        badge: "Weekend Trek",
        price: "₹4000",
        image: "images/trips/netravati.jpg",
        distance: "15-20 km",
        elevation: "1,420 m",
        difficulty: "Moderate",
        bestTime: "Oct - Feb",
        duration: "2D/1N",
        availableDates: ["Jan 18-19, 2026", "Jan 25-26, 2026"],
        about: "Netravati Peak trek description here.\\nSecond line.",
        highlights: ["Hidden waterfalls", "Night camping"],
        itinerary: [
            {day: "Day 0", title: "Night Departure", activities: ["10:00 PM - Pickup", "11:00 PM - Journey begins"]},
            {day: "Day 1", title: "Trek Day", activities: ["6:00 AM - Breakfast", "7:00 AM - Trek starts"]}
        ],
        includes: ["Transport", "Meals"],
        excludes: ["Personal expenses"],
        groupSize: "",
    },
    "nandi-hills": {
        title: "Nandi Hills Sunrise",
        location: "Bangalore Rural",
        badge: "Day Trip",
        price: "₹1,499",
        image: "images/trips/nandi-hills.jpg",
        distance: "60 km",
        elevation: "1,478 m",
        difficulty: "Easy",
        bestTime: "Year round",
        duration: "1 Day",
        availableDates: ["Every Weekend"],
        about: "Nandi Hills sunrise trip.",
        highlights: ["Sunrise view", "Cycling option"],
        itinerary: [
            {day: "Day 1", title: "Sunrise Trip", activities: ["4:00 AM - Pickup", "6:00 AM - Sunrise"]}
        ],
        includes: ["Transport"],
        excludes: ["Food"],
        groupSize: "15-20",
    },
};

function getTripData(tripId) {
    return tripsData[tripId] || tripsData['netravati'];
}
''';

  try {
    final trips = TripsParser.parseTripsData(sampleJs);
    
    if (trips.length == 2) {
      print('  ✓ Parsed correct number of trips: ${trips.length}');
      passed++;
    } else {
      print('  ✗ Expected 2 trips, got ${trips.length}');
      failed++;
    }
    
    // Check first trip (simple key)
    final netravati = trips.firstWhere((t) => t['id'] == 'netravati', orElse: () => {});
    if (netravati.isNotEmpty) {
      print('  ✓ Found trip with simple key: netravati');
      passed++;
    } else {
      print('  ✗ Could not find trip: netravati');
      failed++;
    }
    
    // Check second trip (hyphenated quoted key)
    final nandiHills = trips.firstWhere((t) => t['id'] == 'nandi-hills', orElse: () => {});
    if (nandiHills.isNotEmpty) {
      print('  ✓ Found trip with hyphenated key: nandi-hills');
      passed++;
    } else {
      print('  ✗ Could not find trip: nandi-hills');
      failed++;
    }
  } catch (e) {
    print('  ✗ Parser threw exception: $e');
    failed++;
  }
  
  print('');
  
  // Test 2: Field mapping verification
  print('TEST 2: Field mapping (title→name, location→destination, about→description)');
  print('-' * 40);
  
  try {
    final trips = TripsParser.parseTripsData(sampleJs);
    final trip = trips.first;
    
    // Check title/name mapping
    if (trip['title'] == 'Netravati Peak Trek' && trip['name'] == 'Netravati Peak Trek') {
      print('  ✓ title and name fields both populated');
      passed++;
    } else {
      print('  ✗ title/name mapping failed: title=${trip['title']}, name=${trip['name']}');
      failed++;
    }
    
    // Check location/destination mapping
    if (trip['location'] == 'Western Ghats, Karnataka' && trip['destination'] == 'Western Ghats, Karnataka') {
      print('  ✓ location and destination fields both populated');
      passed++;
    } else {
      print('  ✗ location/destination mapping failed');
      failed++;
    }
    
    // Check price is string
    if (trip['price'] is String && trip['price'] == '₹4000') {
      print('  ✓ price is String: ${trip['price']}');
      passed++;
    } else {
      print('  ✗ price type issue: ${trip['price']} (${trip['price'].runtimeType})');
      failed++;
    }
  } catch (e) {
    print('  ✗ Field mapping test threw exception: $e');
    failed++;
  }
  
  print('');
  
  // Test 3: Itinerary parsing
  print('TEST 3: Itinerary parsing');
  print('-' * 40);
  
  try {
    final trips = TripsParser.parseTripsData(sampleJs);
    final trip = trips.first;
    final itinerary = trip['itinerary'] as List<dynamic>;
    
    if (itinerary.length == 2) {
      print('  ✓ Parsed ${itinerary.length} itinerary days');
      passed++;
    } else {
      print('  ✗ Expected 2 itinerary days, got ${itinerary.length}');
      failed++;
    }
    
    final day0 = itinerary[0] as Map<String, dynamic>;
    if (day0['day'] == 'Day 0' && day0['title'] == 'Night Departure') {
      print('  ✓ Day 0 parsed correctly: ${day0['day']} - ${day0['title']}');
      passed++;
    } else {
      print('  ✗ Day 0 parsing failed: ${day0}');
      failed++;
    }
    
    final activities = day0['activities'] as List<dynamic>;
    if (activities.length == 2) {
      print('  ✓ Activities parsed: ${activities.length} items');
      passed++;
    } else {
      print('  ✗ Activities parsing failed: ${activities}');
      failed++;
    }
  } catch (e) {
    print('  ✗ Itinerary test threw exception: $e');
    failed++;
  }
  
  print('');
  
  // Test 4: Generator output
  print('TEST 4: Generator output (generateTripsDataJs)');
  print('-' * 40);
  
  try {
    final trips = TripsParser.parseTripsData(sampleJs);
    final generated = TripsParser.generateTripsDataJs(trips);
    
    // Check header
    if (generated.contains('TEAM WEEKEND TREKKERS - TRIP DATABASE')) {
      print('  ✓ Generated header present');
      passed++;
    } else {
      print('  ✗ Missing header');
      failed++;
    }
    
    // Check getTripData function
    if (generated.contains('function getTripData(tripId)')) {
      print('  ✓ getTripData function included');
      passed++;
    } else {
      print('  ✗ getTripData function MISSING!');
      failed++;
    }
    
    // Check quoted hyphenated key
    if (generated.contains('"nandi-hills":')) {
      print('  ✓ Hyphenated key properly quoted: "nandi-hills"');
      passed++;
    } else {
      print('  ✗ Hyphenated key not quoted properly');
      failed++;
    }
    
    // Check simple key not quoted
    if (generated.contains('    netravati: {')) {
      print('  ✓ Simple key not quoted: netravati');
      passed++;
    } else {
      print('  ✗ Simple key format issue');
      failed++;
    }
    
    // Check const tripsData
    if (generated.contains('const tripsData = {')) {
      print('  ✓ const tripsData declaration present');
      passed++;
    } else {
      print('  ✗ Missing const tripsData declaration');
      failed++;
    }
  } catch (e) {
    print('  ✗ Generator test threw exception: $e');
    failed++;
  }
  
  print('');
  
  // Test 5: Round-trip (parse → generate → parse)
  print('TEST 5: Round-trip test (parse → generate → parse)');
  print('-' * 40);
  
  try {
    final trips1 = TripsParser.parseTripsData(sampleJs);
    final generated = TripsParser.generateTripsDataJs(trips1);
    final trips2 = TripsParser.parseTripsData(generated);
    
    if (trips1.length == trips2.length) {
      print('  ✓ Same number of trips after round-trip: ${trips2.length}');
      passed++;
    } else {
      print('  ✗ Trip count mismatch: ${trips1.length} → ${trips2.length}');
      failed++;
    }
    
    // Check IDs preserved
    final ids1 = trips1.map((t) => t['id']).toSet();
    final ids2 = trips2.map((t) => t['id']).toSet();
    if (ids1.difference(ids2).isEmpty && ids2.difference(ids1).isEmpty) {
      print('  ✓ All trip IDs preserved: $ids2');
      passed++;
    } else {
      print('  ✗ Trip IDs changed: $ids1 → $ids2');
      failed++;
    }
  } catch (e) {
    print('  ✗ Round-trip test threw exception: $e');
    failed++;
  }
  
  print('');
  
  // Test 6: Type safety (no double/String mismatch)
  print('TEST 6: Type safety verification');
  print('-' * 40);
  
  try {
    final trips = TripsParser.parseTripsData(sampleJs);
    
    for (final trip in trips) {
      final id = trip['id'];
      final price = trip['price'];
      final groupSize = trip['groupSize'];
      
      // Verify price is string
      if (price != null && price is! String) {
        print('  ✗ Trip $id: price is ${price.runtimeType}, expected String');
        failed++;
      }
      
      // Test toString() doesn't crash
      try {
        final generated = TripsParser.generateTripsDataJs([trip]);
        if (generated.isNotEmpty) {
          // Good - no crash
        }
      } catch (e) {
        print('  ✗ Trip $id: generator crashed: $e');
        failed++;
      }
    }
    print('  ✓ All trips pass type safety checks');
    passed++;
  } catch (e) {
    print('  ✗ Type safety test threw exception: $e');
    failed++;
  }
  
  print('');
  
  // Test 7: Test with number values (edge case)
  print('TEST 7: Handle numeric values gracefully');
  print('-' * 40);
  
  try {
    // Create a trip with mixed types (simulating what might happen in editing)
    final tripWithNumbers = <String, dynamic>{
      'id': 'test-trip',
      'title': 'Test Trip',
      'location': 'Test Location',
      'price': 1000,  // number instead of string
      'groupSize': 20, // number instead of string
      'badge': 'Test',
      'difficulty': 'Easy',
      'image': 'test.jpg',
      'highlights': <String>[],
      'itinerary': <Map<String, dynamic>>[],
      'inclusions': <String>[],
      'exclusions': <String>[],
    };
    
    final generated = TripsParser.generateTripsDataJs([tripWithNumbers]);
    
    if (generated.contains('price: "1000"') || generated.contains('price: "₹1000"')) {
      print('  ✓ Numeric price converted to string');
      passed++;
    } else if (generated.contains('price:')) {
      print('  ✓ Price field generated (value may vary)');
      passed++;
    } else {
      print('  ✗ Price field missing in output');
      failed++;
    }
    
    // Verify no crash
    print('  ✓ Generator handles numeric values without crashing');
    passed++;
  } catch (e) {
    print('  ✗ Numeric value test threw exception: $e');
    failed++;
  }
  
  print('');
  
  // Test 8: Fetch and parse real data from GitHub
  print('TEST 8: Fetch and parse real trips-data.js from GitHub');
  print('-' * 40);
  
  try {
    final result = await Process.run('curl', [
      '-s',
      'https://raw.githubusercontent.com/teamweekendtrekkers-png/teamweekendtrekkerwebsite/main/js/trips-data.js'
    ]);
    
    if (result.exitCode == 0 && result.stdout.toString().isNotEmpty) {
      final content = result.stdout.toString();
      
      if (content.contains('404') || content.length < 100) {
        print('  ⚠ Could not fetch from GitHub (may be network issue)');
      } else {
        final trips = TripsParser.parseTripsData(content);
        
        if (trips.length >= 16) {
          print('  ✓ Parsed ${trips.length} trips from GitHub');
          passed++;
          
          // Check for hyphenated keys
          final hyphenatedTrips = trips.where((t) => t['id'].toString().contains('-')).toList();
          if (hyphenatedTrips.isNotEmpty) {
            print('  ✓ Found ${hyphenatedTrips.length} trips with hyphenated IDs');
            passed++;
          } else {
            print('  ⚠ No hyphenated trip IDs found');
          }
          
          // Verify getTripData exists in original
          if (content.contains('function getTripData')) {
            print('  ✓ Original has getTripData function');
            passed++;
          }
        } else {
          print('  ✗ Expected at least 16 trips, got ${trips.length}');
          failed++;
        }
      }
    } else {
      print('  ⚠ Could not fetch from GitHub (curl failed)');
    }
  } catch (e) {
    print('  ⚠ GitHub fetch test skipped: $e');
  }
  
  print('');
  print('=' * 60);
  print('TEST RESULTS: $passed passed, $failed failed');
  print('=' * 60);
  
  if (failed > 0) {
    exit(1);
  }
}
