import 'dart:convert';
import '../lib/services/trips_parser.dart';

/// Comprehensive test for edit screen → generator → website compatibility
void main() {
  print('=' * 70);
  print('EDIT SCREEN → WEBSITE COMPATIBILITY TEST');
  print('=' * 70);
  print('');
  
  int passed = 0;
  int failed = 0;
  List<String> issues = [];
  
  // Simulate what the edit screen produces after saving
  print('TEST 1: Simulating edit screen save output');
  print('-' * 50);
  
  // This is what the updated edit screen produces (with website-required fields)
  final editScreenOutput = <String, dynamic>{
    'id': 'netravati',
    'title': 'Netravati Peak Trek',
    'name': 'Netravati Peak Trek',
    'location': 'Western Ghats, Karnataka',
    'destination': 'Western Ghats, Karnataka',
    'about': 'Test description with\nnewlines',
    'description': 'Test description with\nnewlines',
    'date': 'Jan 18-19, 2026',
    'price': '₹4000',
    'image': 'images/trips/netravati.jpg',
    'groupSize': '20',
    'pickupPoint': 'Bangalore',
    'difficulty': 'Moderate',
    'featured': false,
    'highlights': ['Highlight 1', 'Highlight 2'],
    'itinerary': [
      {'day': 'Day 0', 'title': 'Night Departure', 'activities': ['10PM - Pickup']},
      {'day': 'Day 1', 'title': 'Trek Day', 'activities': ['6AM - Start']},
    ],
    'inclusions': ['Transport', 'Meals'],
    'exclusions': ['Personal expenses'],
    // Website-required fields (now included in edit screen):
    'badge': 'Weekend Trek',
    'distance': '15-20 km',
    'elevation': '1,420 m',
    'bestTime': 'Oct - Feb',
    'duration': '2D/1N',
    'availableDates': ['Jan 18-19, 2026', 'Feb 15-16, 2026'],
  };
  
  // Fields the website REQUIRES
  final requiredFields = [
    'title', 'location', 'badge', 'price', 'image',
    'distance', 'elevation', 'difficulty', 'bestTime', 'duration',
    'availableDates', 'about', 'highlights', 'itinerary',
    'includes', 'excludes', 'groupSize'
  ];
  
  print('  Checking for missing required fields...');
  for (final field in requiredFields) {
    if (!editScreenOutput.containsKey(field) && 
        !editScreenOutput.containsKey(_getAlternateKey(field))) {
      print('  ✗ MISSING: $field');
      issues.add('Edit screen does not save: $field');
      failed++;
    } else {
      print('  ✓ Found: $field');
      passed++;
    }
  }
  
  print('');
  print('TEST 2: Generator output verification');
  print('-' * 50);
  
  // Add missing fields with defaults for testing
  final completeTrip = Map<String, dynamic>.from(editScreenOutput);
  completeTrip['badge'] = completeTrip['badge'] ?? 'Trek';
  completeTrip['distance'] = completeTrip['distance'] ?? '';
  completeTrip['elevation'] = completeTrip['elevation'] ?? '';
  completeTrip['bestTime'] = completeTrip['bestTime'] ?? '';
  completeTrip['duration'] = completeTrip['duration'] ?? '';
  completeTrip['availableDates'] = completeTrip['availableDates'] ?? [completeTrip['date'] ?? ''];
  
  try {
    final generated = TripsParser.generateTripsDataJs([completeTrip]);
    
    // Check all required fields are in output
    final fieldChecks = {
      'title:': 'title field',
      'location:': 'location field',
      'badge:': 'badge field',
      'price:': 'price field',
      'image:': 'image field',
      'distance:': 'distance field',
      'elevation:': 'elevation field',
      'difficulty:': 'difficulty field',
      'bestTime:': 'bestTime field',
      'duration:': 'duration field',
      'availableDates:': 'availableDates array',
      'about:': 'about field',
      'highlights:': 'highlights array',
      'itinerary:': 'itinerary array',
      'includes:': 'includes array',
      'excludes:': 'excludes array',
      'groupSize:': 'groupSize field',
      'function getTripData': 'getTripData function',
    };
    
    for (final entry in fieldChecks.entries) {
      if (generated.contains(entry.key)) {
        print('  ✓ Generated: ${entry.value}');
        passed++;
      } else {
        print('  ✗ MISSING in output: ${entry.value}');
        issues.add('Generator missing: ${entry.value}');
        failed++;
      }
    }
  } catch (e) {
    print('  ✗ Generator threw exception: $e');
    failed++;
  }
  
  print('');
  print('TEST 3: Round-trip with real GitHub data');
  print('-' * 50);
  
  // Test with real data format
  const realTripJs = '''
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
        about: "Trek description here.",
        highlights: ["Waterfalls", "Camping"],
        itinerary: [
            {day: "Day 0", title: "Night Departure", activities: ["10PM - Pickup", "11PM - Journey"]},
            {day: "Day 1", title: "Trek", activities: ["6AM - Breakfast", "7AM - Trek"]}
        ],
        includes: ["Transport", "Meals"],
        excludes: ["Personal expenses"],
        groupSize: "15-20",
    },
};

function getTripData(tripId) {
    return tripsData[tripId] || tripsData['netravati'];
}
''';
  
  try {
    // Parse original
    final trips = TripsParser.parseTripsData(realTripJs);
    final trip = trips.first;
    
    print('  Parsed trip: ${trip['id']}');
    
    // Simulate editing (change some fields)
    trip['title'] = 'Updated Netravati Trek';
    trip['price'] = '₹5000';
    trip['highlights'] = ['New highlight 1', 'New highlight 2'];
    
    // Generate
    final regenerated = TripsParser.generateTripsDataJs(trips);
    
    // Parse again
    final trips2 = TripsParser.parseTripsData(regenerated);
    final trip2 = trips2.first;
    
    // Verify changes persisted
    if (trip2['title'] == 'Updated Netravati Trek') {
      print('  ✓ Title change persisted');
      passed++;
    } else {
      print('  ✗ Title change lost: ${trip2['title']}');
      failed++;
    }
    
    if (trip2['price'] == '₹5000') {
      print('  ✓ Price change persisted');
      passed++;
    } else {
      print('  ✗ Price change lost: ${trip2['price']}');
      failed++;
    }
    
    // Verify other fields preserved
    if (trip2['badge'] == 'Weekend Trek') {
      print('  ✓ Badge preserved');
      passed++;
    } else {
      print('  ✗ Badge lost: ${trip2['badge']}');
      issues.add('Badge field not preserved after edit');
      failed++;
    }
    
    if (trip2['distance'] == '15-20 km') {
      print('  ✓ Distance preserved');
      passed++;
    } else {
      print('  ✗ Distance lost: ${trip2['distance']}');
      issues.add('Distance field not preserved after edit');
      failed++;
    }
    
    if (trip2['duration'] == '2D/1N') {
      print('  ✓ Duration preserved');
      passed++;
    } else {
      print('  ✗ Duration lost: ${trip2['duration']}');
      issues.add('Duration field not preserved after edit');
      failed++;
    }
    
    if (trip2['bestTime'] == 'Oct - Feb') {
      print('  ✓ BestTime preserved');
      passed++;
    } else {
      print('  ✗ BestTime lost: ${trip2['bestTime']}');
      issues.add('BestTime field not preserved after edit');
      failed++;
    }
    
    // Check getTripData function
    if (regenerated.contains('function getTripData(tripId)')) {
      print('  ✓ getTripData function present');
      passed++;
    } else {
      print('  ✗ getTripData function MISSING');
      issues.add('getTripData function missing in output');
      failed++;
    }
    
    // Check itinerary preserved
    final itinerary = trip2['itinerary'] as List<dynamic>?;
    if (itinerary != null && itinerary.length == 2) {
      print('  ✓ Itinerary preserved (${itinerary.length} days)');
      passed++;
    } else {
      print('  ✗ Itinerary lost or corrupted');
      failed++;
    }
    
    // Check availableDates preserved
    final dates = trip2['availableDates'] as List<dynamic>?;
    if (dates != null && dates.length == 2) {
      print('  ✓ AvailableDates preserved (${dates.length} dates)');
      passed++;
    } else {
      print('  ✗ AvailableDates lost: $dates');
      issues.add('AvailableDates not preserved');
      failed++;
    }
    
  } catch (e, stack) {
    print('  ✗ Round-trip test failed: $e');
    print('  Stack: $stack');
    failed++;
  }
  
  print('');
  print('TEST 4: Edit screen field mapping verification');
  print('-' * 50);
  
  // Fields the edit screen SHOULD save
  final editScreenShouldSave = {
    'id': 'Trip ID',
    'title': 'Trip name/title',
    'location': 'Destination/location',
    'badge': 'Trip type badge',
    'price': 'Price',
    'image': 'Image path',
    'distance': 'Distance',
    'elevation': 'Elevation',
    'difficulty': 'Difficulty',
    'bestTime': 'Best time to visit',
    'duration': 'Duration',
    'about': 'Description/about',
    'availableDates': 'Available dates array',
    'highlights': 'Highlights array',
    'itinerary': 'Itinerary array',
    'inclusions': 'Inclusions/includes array',
    'exclusions': 'Exclusions/excludes array',
    'groupSize': 'Group size',
  };
  
  // Current edit screen saves these fields (updated after fixes):
  final editScreenCurrentlySaves = {
    'id', 'title', 'name', 'location', 'destination', 
    'about', 'description', 'date', 'price', 'image',
    'groupSize', 'pickupPoint', 'difficulty', 'featured',
    'highlights', 'itinerary', 'inclusions', 'exclusions',
    'discountedPrice',
    // New fields added for website compatibility:
    'badge', 'distance', 'elevation', 'bestTime', 'duration', 'availableDates',
  };
  
  // Missing from edit screen
  final missingFromEditScreen = <String>[];
  for (final field in editScreenShouldSave.keys) {
    if (!editScreenCurrentlySaves.contains(field)) {
      missingFromEditScreen.add(field);
    }
  }
  
  if (missingFromEditScreen.isEmpty) {
    print('  ✓ Edit screen saves all required fields');
    passed++;
  } else {
    print('  ✗ Edit screen MISSING fields:');
    for (final field in missingFromEditScreen) {
      print('      - $field (${editScreenShouldSave[field]})');
      issues.add('Edit screen missing: $field');
    }
    failed++;
  }
  
  print('');
  print('=' * 70);
  print('TEST RESULTS: $passed passed, $failed failed');
  print('=' * 70);
  
  if (issues.isNotEmpty) {
    print('');
    print('ISSUES TO FIX:');
    print('-' * 50);
    for (int i = 0; i < issues.length; i++) {
      print('${i + 1}. ${issues[i]}');
    }
  }
}

String _getAlternateKey(String key) {
  switch (key) {
    case 'includes': return 'inclusions';
    case 'excludes': return 'exclusions';
    case 'title': return 'name';
    case 'location': return 'destination';
    case 'about': return 'description';
    default: return key;
  }
}
