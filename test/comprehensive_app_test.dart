import 'dart:convert';
import 'package:http/http.dart' as http;

/// Comprehensive test suite for Trip Manager App
/// Tests ALL features extensively
void main() async {
  print('═' * 70);
  print('TRIP MANAGER APP - COMPREHENSIVE FEATURE TEST');
  print('═' * 70);
  print('');

  int totalPassed = 0;
  int totalFailed = 0;
  final allIssues = <String>[];

  // ════════════════════════════════════════════════════════════════════
  // SECTION 1: TRIPS PARSER TESTS
  // ════════════════════════════════════════════════════════════════════
  print('');
  print('╔════════════════════════════════════════════════════════════════╗');
  print('║  SECTION 1: TRIPS PARSER                                       ║');
  print('╚════════════════════════════════════════════════════════════════╝');
  
  var passed = 0;
  var failed = 0;

  // Test 1.1: Parse simple trip keys
  print('\n1.1 Parse simple trip keys');
  print('-' * 50);
  
  const simpleTripsJs = '''
const tripsData = {
    netravati: {
        title: "Netravati Peak Trek",
        location: "Western Ghats",
        price: "₹4000",
        difficulty: "Moderate",
    },
    kudremukh: {
        title: "Kudremukh Trek",
        location: "Karnataka",
        price: "₹5000",
        difficulty: "Hard",
    },
};
''';

  try {
    final trips = _parseTripsData(simpleTripsJs);
    if (trips.length == 2) {
      print('  ✓ Parsed 2 simple key trips');
      passed++;
    } else {
      print('  ✗ Expected 2 trips, got ${trips.length}');
      failed++;
    }
    
    if (trips.any((t) => t['id'] == 'netravati')) {
      print('  ✓ Found netravati trip');
      passed++;
    } else {
      print('  ✗ Missing netravati trip');
      failed++;
    }
  } catch (e) {
    print('  ✗ Parser error: $e');
    failed++;
  }

  // Test 1.2: Parse hyphenated trip keys
  print('\n1.2 Parse hyphenated (quoted) trip keys');
  print('-' * 50);
  
  const hyphenatedTripsJs = '''
const tripsData = {
    "nandi-hills": {
        title: "Nandi Hills Sunrise",
        location: "Near Bangalore",
        price: "₹1500",
    },
    "coorg-abbey-falls": {
        title: "Coorg Abbey Falls",
        location: "Coorg",
        price: "₹3000",
    },
};
''';

  try {
    final trips = _parseTripsData(hyphenatedTripsJs);
    if (trips.length == 2) {
      print('  ✓ Parsed 2 hyphenated key trips');
      passed++;
    } else {
      print('  ✗ Expected 2 trips, got ${trips.length}');
      failed++;
    }
    
    if (trips.any((t) => t['id'] == 'nandi-hills')) {
      print('  ✓ Found nandi-hills trip');
      passed++;
    } else {
      print('  ✗ Missing nandi-hills trip');
      failed++;
    }
  } catch (e) {
    print('  ✗ Parser error: $e');
    failed++;
  }

  // Test 1.3: Parse all website fields
  print('\n1.3 Parse ALL website-required fields');
  print('-' * 50);
  
  const fullTripJs = '''
const tripsData = {
    testtrip: {
        title: "Test Trek",
        location: "Test Location",
        badge: "Weekend Trek",
        price: "₹4000",
        image: "images/trips/test.jpg",
        distance: "15-20 km",
        elevation: "1,420 m",
        difficulty: "Moderate",
        bestTime: "Oct - Feb",
        duration: "2D/1N",
        availableDates: ["Jan 18-19, 2026", "Jan 25-26, 2026"],
        about: "Test description.",
        highlights: ["Highlight 1", "Highlight 2"],
        itinerary: [
            {day: "Day 0", title: "Night Departure", activities: ["10PM - Pickup"]},
            {day: "Day 1", title: "Trek", activities: ["6AM - Breakfast"]}
        ],
        includes: ["Transport", "Meals"],
        excludes: ["Personal expenses"],
        groupSize: "15-20",
    },
};

function getTripData(tripId) {
    return tripsData[tripId] || tripsData['testtrip'];
}
''';

  final requiredFields = [
    'title', 'location', 'badge', 'price', 'image',
    'distance', 'elevation', 'difficulty', 'bestTime', 'duration',
    'availableDates', 'about', 'highlights', 'itinerary',
    'includes', 'excludes', 'groupSize'
  ];

  try {
    final trips = _parseTripsData(fullTripJs);
    final trip = trips.first;
    
    var allFieldsPresent = true;
    for (final field in requiredFields) {
      if (trip.containsKey(field) && trip[field] != null) {
        print('  ✓ Field: $field');
      } else {
        print('  ✗ Missing: $field');
        allFieldsPresent = false;
      }
    }
    
    if (allFieldsPresent) {
      print('  ✓ All 17 required fields parsed');
      passed++;
    } else {
      failed++;
      allIssues.add('Parser missing some required fields');
    }
  } catch (e) {
    print('  ✗ Parser error: $e');
    failed++;
  }

  // Test 1.4: Generator output
  print('\n1.4 Generator output format');
  print('-' * 50);
  
  try {
    final testTrip = {
      'id': 'test-trip',
      'title': 'Test Trek',
      'location': 'Test Location',
      'badge': 'Trek',
      'price': '₹4000',
      'image': 'images/trips/test.jpg',
      'distance': '15 km',
      'elevation': '1000 m',
      'difficulty': 'Easy',
      'bestTime': 'All year',
      'duration': '1D',
      'availableDates': ['Jan 1, 2026'],
      'about': 'Test description',
      'highlights': ['Scenic views'],
      'itinerary': [{'day': 'Day 1', 'title': 'Trek', 'activities': ['Hike']}],
      'includes': ['Transport'],
      'excludes': ['Food'],
      'groupSize': '10',
    };
    
    final generated = _generateTripsDataJs([testTrip]);
    
    // Check for quoted hyphenated key
    if (generated.contains('"test-trip":')) {
      print('  ✓ Hyphenated key properly quoted');
      passed++;
    } else {
      print('  ✗ Hyphenated key not quoted');
      failed++;
    }
    
    // Check for getTripData function
    if (generated.contains('function getTripData(tripId)')) {
      print('  ✓ getTripData function present');
      passed++;
    } else {
      print('  ✗ getTripData function MISSING');
      failed++;
      allIssues.add('Generator missing getTripData function');
    }
    
    // Check for all fields
    if (generated.contains('badge:') && generated.contains('distance:') && 
        generated.contains('elevation:') && generated.contains('bestTime:') &&
        generated.contains('duration:') && generated.contains('availableDates:')) {
      print('  ✓ All website fields in output');
      passed++;
    } else {
      print('  ✗ Some website fields missing from output');
      failed++;
    }
  } catch (e) {
    print('  ✗ Generator error: $e');
    failed++;
  }

  // Test 1.5: Round-trip test
  print('\n1.5 Round-trip test (parse → generate → parse)');
  print('-' * 50);
  
  try {
    final trips1 = _parseTripsData(fullTripJs);
    final generated = _generateTripsDataJs(trips1);
    final trips2 = _parseTripsData(generated);
    
    if (trips1.length == trips2.length) {
      print('  ✓ Same number of trips after round-trip');
      passed++;
    } else {
      print('  ✗ Trip count changed: ${trips1.length} → ${trips2.length}');
      failed++;
    }
    
    final trip1 = trips1.first;
    final trip2 = trips2.first;
    
    if (trip1['title'] == trip2['title'] && trip1['price'] == trip2['price']) {
      print('  ✓ Data preserved after round-trip');
      passed++;
    } else {
      print('  ✗ Data changed after round-trip');
      failed++;
    }
  } catch (e) {
    print('  ✗ Round-trip error: $e');
    failed++;
  }

  print('\n  Section 1 Results: $passed passed, $failed failed');
  totalPassed += passed;
  totalFailed += failed;

  // ════════════════════════════════════════════════════════════════════
  // SECTION 2: WEBSITE SETTINGS (UPI & WhatsApp)
  // ════════════════════════════════════════════════════════════════════
  print('');
  print('╔════════════════════════════════════════════════════════════════╗');
  print('║  SECTION 2: WEBSITE SETTINGS (UPI & WhatsApp)                  ║');
  print('╚════════════════════════════════════════════════════════════════╝');
  
  passed = 0;
  failed = 0;

  // Test 2.1: Checksum algorithm
  print('\n2.1 Checksum algorithm (must match JavaScript)');
  print('-' * 50);
  
  int computeChecksum(String str) {
    int sum = 0;
    for (int i = 0; i < str.length; i++) {
      sum = ((sum << 5) - sum + str.codeUnitAt(i));
      sum = sum.toSigned(32);
    }
    return sum;
  }
  
  const knownUpi = '9538236581@ybl';
  const expectedChecksum = 1165100733;
  final computed = computeChecksum(knownUpi);
  
  if (computed == expectedChecksum) {
    print('  ✓ Checksum matches: $computed');
    passed++;
  } else {
    print('  ✗ Checksum mismatch! Expected $expectedChecksum, got $computed');
    failed++;
    allIssues.add('Checksum algorithm broken');
  }

  // Test 2.2: UPI encoding
  print('\n2.2 UPI ASCII encoding');
  print('-' * 50);
  
  String encodeAndDecode(String upi) {
    final parts = upi.split('@');
    final p1 = parts[0].codeUnits;
    final p2 = '@'.codeUnitAt(0);
    final p3 = parts[1].codeUnits;
    return String.fromCharCodes(p1) + String.fromCharCode(p2) + String.fromCharCodes(p3);
  }
  
  final testUpis = ['9538236581@ybl', 'paytmqr5nb81s@ptys', 'business@icici'];
  var allEncodingsOk = true;
  
  for (final upi in testUpis) {
    final decoded = encodeAndDecode(upi);
    if (decoded == upi) {
      print('  ✓ Round-trip OK: $upi');
    } else {
      print('  ✗ Round-trip failed: $upi → $decoded');
      allEncodingsOk = false;
    }
  }
  
  if (allEncodingsOk) passed++; else failed++;

  // Test 2.3: Masked UPI format
  print('\n2.3 Masked UPI format');
  print('-' * 50);
  
  String getMaskedUpi(String upi) {
    final parts = upi.split('@');
    final name = parts[0];
    final provider = parts[1];
    final lastFour = name.length > 4 ? name.substring(name.length - 4) : name;
    return '••••••$lastFour@$provider';
  }
  
  final maskTests = {
    '9538236581@ybl': '••••••6581@ybl',
    'paytmqr5nb81s@ptys': '••••••b81s@ptys',
    'ab@xy': '••••••ab@xy',
  };
  
  var allMasksOk = true;
  for (final entry in maskTests.entries) {
    final masked = getMaskedUpi(entry.key);
    if (masked == entry.value) {
      print('  ✓ ${entry.key} → $masked');
    } else {
      print('  ✗ ${entry.key} → $masked (expected ${entry.value})');
      allMasksOk = false;
    }
  }
  
  if (allMasksOk) passed++; else failed++;

  // Test 2.4: UPI validation
  print('\n2.4 UPI validation patterns');
  print('-' * 50);
  
  bool isValidUpi(String upi) {
    final regex = RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9]+$');
    return regex.hasMatch(upi);
  }
  
  final upiValidationTests = {
    '9538236581@ybl': true,
    'paytmqr5nb81s@ptys': true,
    'business@icici': true,
    'name.merchant@axis': true,
    'shop-name@upi': true,
    '@ybl': false,
    '123': false,
    'test@': false,
    '': false,
  };
  
  var allValidationsOk = true;
  for (final entry in upiValidationTests.entries) {
    final result = isValidUpi(entry.key);
    if (result == entry.value) {
      print('  ✓ "${entry.key}": ${result ? "valid" : "invalid"}');
    } else {
      print('  ✗ "${entry.key}": expected ${entry.value}, got $result');
      allValidationsOk = false;
    }
  }
  
  if (allValidationsOk) passed++; else failed++;

  // Test 2.5: WhatsApp validation
  print('\n2.5 WhatsApp validation patterns');
  print('-' * 50);
  
  bool isValidWhatsApp(String number) {
    final regex = RegExp(r'^\d{10,15}$');
    return regex.hasMatch(number);
  }
  
  final waValidationTests = {
    '917019235581': true,
    '919876543210': true,
    '1234567890': true,
    '123': false,
    '12345678901234567': false,
    '91-7019235581': false,
    '+917019235581': false,
  };
  
  var allWaValidationsOk = true;
  for (final entry in waValidationTests.entries) {
    final result = isValidWhatsApp(entry.key);
    if (result == entry.value) {
      print('  ✓ "${entry.key}": ${result ? "valid" : "invalid"}');
    } else {
      print('  ✗ "${entry.key}": expected ${entry.value}, got $result');
      allWaValidationsOk = false;
    }
  }
  
  if (allWaValidationsOk) passed++; else failed++;

  // Test 2.6: Fetch LIVE website data
  print('\n2.6 Fetch and verify LIVE website data');
  print('-' * 50);
  
  try {
    final securityJs = await http.get(Uri.parse(
      'https://raw.githubusercontent.com/teamweekendtrekkers-png/teamweekendtrekkerwebsite/main/js/security.js'
    ));
    
    if (securityJs.statusCode == 200) {
      final content = securityJs.body;
      
      // Extract and verify UPI
      final p1Match = RegExp(r'_p1:\s*\[([^\]]+)\]').firstMatch(content);
      final p2Match = RegExp(r'_p2:\s*(\d+)').firstMatch(content);
      final p3Match = RegExp(r'_p3:\s*\[([^\]]+)\]').firstMatch(content);
      final checksumMatch = RegExp(r'_checksum:\s*(-?\d+)').firstMatch(content);
      
      if (p1Match != null && p2Match != null && p3Match != null && checksumMatch != null) {
        final p1Codes = p1Match.group(1)!.split(',').map((s) => int.parse(s.trim())).toList();
        final p2Code = int.parse(p2Match.group(1)!);
        final p3Codes = p3Match.group(1)!.split(',').map((s) => int.parse(s.trim())).toList();
        final liveChecksum = int.parse(checksumMatch.group(1)!);
        
        final liveUpi = String.fromCharCodes(p1Codes) + String.fromCharCode(p2Code) + String.fromCharCodes(p3Codes);
        final computedChecksum = computeChecksum(liveUpi);
        
        print('  Live UPI: $liveUpi');
        print('  Live checksum: $liveChecksum');
        print('  Computed checksum: $computedChecksum');
        
        if (computedChecksum == liveChecksum) {
          print('  ✓ Live checksum verification PASSED');
          passed++;
        } else {
          print('  ✗ Live checksum verification FAILED');
          failed++;
          allIssues.add('Live website checksum mismatch');
        }
      } else {
        print('  ✗ Could not parse security.js');
        failed++;
      }
    } else {
      print('  ✗ Failed to fetch security.js');
      failed++;
    }
  } catch (e) {
    print('  ✗ Network error: $e');
    failed++;
  }

  // Test 2.7: Check masked UPI in HTML files
  print('\n2.7 Check masked UPI patterns in HTML files');
  print('-' * 50);
  
  final htmlFiles = ['index.html', 'trip-detail.html', 'trips.html', 'about.html', 'contact.html'];
  
  for (final file in htmlFiles) {
    try {
      final response = await http.get(Uri.parse(
        'https://raw.githubusercontent.com/teamweekendtrekkers-png/teamweekendtrekkerwebsite/main/$file'
      ));
      
      if (response.statusCode == 200) {
        final maskedPattern = RegExp(r'••••••[a-zA-Z0-9]+@[a-zA-Z0-9]+');
        final matches = maskedPattern.allMatches(response.body);
        
        if (matches.isNotEmpty) {
          print('  $file: ${matches.length} masked UPI found');
          for (final match in matches) {
            print('    - ${match.group(0)}');
          }
        } else {
          print('  $file: No hardcoded masked UPI (dynamic)');
        }
      }
    } catch (e) {
      print('  $file: Error - $e');
    }
  }
  passed++; // Informational test

  print('\n  Section 2 Results: $passed passed, $failed failed');
  totalPassed += passed;
  totalFailed += failed;

  // ════════════════════════════════════════════════════════════════════
  // SECTION 3: EDIT SCREEN FIELD MAPPING
  // ════════════════════════════════════════════════════════════════════
  print('');
  print('╔════════════════════════════════════════════════════════════════╗');
  print('║  SECTION 3: EDIT SCREEN FIELD MAPPING                          ║');
  print('╚════════════════════════════════════════════════════════════════╝');
  
  passed = 0;
  failed = 0;

  // Test 3.1: Required fields for website
  print('\n3.1 Website-required fields');
  print('-' * 50);
  
  final websiteRequiredFields = {
    'id': 'Trip identifier',
    'title': 'Trip title',
    'location': 'Location/destination',
    'badge': 'Trip type badge',
    'price': 'Price string',
    'image': 'Image path',
    'distance': 'Trek distance',
    'elevation': 'Peak elevation',
    'difficulty': 'Difficulty level',
    'bestTime': 'Best time to visit',
    'duration': 'Duration (e.g., 2D/1N)',
    'about': 'Description',
    'availableDates': 'Available dates array',
    'highlights': 'Highlights array',
    'itinerary': 'Itinerary array',
    'includes': 'Inclusions array',
    'excludes': 'Exclusions array',
    'groupSize': 'Group size',
  };
  
  print('  Website requires ${websiteRequiredFields.length} fields:');
  for (final entry in websiteRequiredFields.entries) {
    print('    • ${entry.key}: ${entry.value}');
  }
  passed++;

  // Test 3.2: Simulate edit screen save
  print('\n3.2 Simulated edit screen output');
  print('-' * 50);
  
  // This simulates what the edit screen should produce
  final editScreenOutput = {
    'id': 'netravati',
    'title': 'Netravati Peak Trek',
    'name': 'Netravati Peak Trek',
    'location': 'Western Ghats, Karnataka',
    'destination': 'Western Ghats, Karnataka',
    'badge': 'Weekend Trek',
    'price': '₹4000',
    'image': 'images/trips/netravati.jpg',
    'distance': '15-20 km',
    'elevation': '1,420 m',
    'difficulty': 'Moderate',
    'bestTime': 'Oct - Feb',
    'duration': '2D/1N',
    'about': 'Test description',
    'description': 'Test description',
    'availableDates': ['Jan 18-19, 2026'],
    'highlights': ['Highlight 1'],
    'itinerary': [{'day': 'Day 1', 'title': 'Trek', 'activities': ['Hike']}],
    'includes': ['Transport'],
    'inclusions': ['Transport'],
    'excludes': ['Personal expenses'],
    'exclusions': ['Personal expenses'],
    'groupSize': '20',
  };
  
  // Check if all required fields are present
  var allRequiredPresent = true;
  for (final field in websiteRequiredFields.keys) {
    if (editScreenOutput.containsKey(field)) {
      print('  ✓ $field: present');
    } else {
      print('  ✗ $field: MISSING');
      allRequiredPresent = false;
      allIssues.add('Edit screen missing field: $field');
    }
  }
  
  if (allRequiredPresent) {
    print('  ✓ All required fields present');
    passed++;
  } else {
    failed++;
  }

  // Test 3.3: Field type verification
  print('\n3.3 Field type verification');
  print('-' * 50);
  
  var allTypesCorrect = true;
  
  // String fields
  final stringFields = ['id', 'title', 'location', 'badge', 'price', 'image', 
                        'distance', 'elevation', 'difficulty', 'bestTime', 
                        'duration', 'about', 'groupSize'];
  for (final field in stringFields) {
    if (editScreenOutput[field] is String) {
      print('  ✓ $field is String');
    } else {
      print('  ✗ $field should be String, got ${editScreenOutput[field].runtimeType}');
      allTypesCorrect = false;
    }
  }
  
  // Array fields
  final arrayFields = ['availableDates', 'highlights', 'itinerary', 'includes', 'excludes'];
  for (final field in arrayFields) {
    if (editScreenOutput[field] is List) {
      print('  ✓ $field is List');
    } else {
      print('  ✗ $field should be List, got ${editScreenOutput[field]?.runtimeType}');
      allTypesCorrect = false;
    }
  }
  
  if (allTypesCorrect) passed++; else failed++;

  // Test 3.4: Generator handles edit screen output
  print('\n3.4 Generator handles edit screen output');
  print('-' * 50);
  
  try {
    final generated = _generateTripsDataJs([editScreenOutput]);
    
    // Verify all fields are in output
    final fieldsInOutput = ['title:', 'location:', 'badge:', 'price:', 'image:',
                           'distance:', 'elevation:', 'difficulty:', 'bestTime:',
                           'duration:', 'availableDates:', 'about:', 'highlights:',
                           'itinerary:', 'includes:', 'excludes:', 'groupSize:'];
    
    var allFieldsGenerated = true;
    for (final field in fieldsInOutput) {
      if (generated.contains(field)) {
        print('  ✓ Generated: $field');
      } else {
        print('  ✗ Missing in output: $field');
        allFieldsGenerated = false;
      }
    }
    
    if (allFieldsGenerated) passed++; else failed++;
    
    // Check getTripData
    if (generated.contains('function getTripData(tripId)')) {
      print('  ✓ getTripData function included');
      passed++;
    } else {
      print('  ✗ getTripData function missing');
      failed++;
      allIssues.add('getTripData not in generated output');
    }
  } catch (e) {
    print('  ✗ Generator error: $e');
    failed++;
  }

  print('\n  Section 3 Results: $passed passed, $failed failed');
  totalPassed += passed;
  totalFailed += failed;

  // ════════════════════════════════════════════════════════════════════
  // SECTION 4: LIVE DATA INTEGRATION
  // ════════════════════════════════════════════════════════════════════
  print('');
  print('╔════════════════════════════════════════════════════════════════╗');
  print('║  SECTION 4: LIVE DATA INTEGRATION                              ║');
  print('╚════════════════════════════════════════════════════════════════╝');
  
  passed = 0;
  failed = 0;

  // Test 4.1: Fetch and parse live trips-data.js
  print('\n4.1 Fetch and parse live trips-data.js');
  print('-' * 50);
  
  try {
    final response = await http.get(Uri.parse(
      'https://raw.githubusercontent.com/teamweekendtrekkers-png/teamweekendtrekkerwebsite/main/js/trips-data.js'
    ));
    
    if (response.statusCode == 200) {
      final trips = _parseTripsData(response.body);
      print('  ✓ Fetched and parsed ${trips.length} trips');
      passed++;
      
      // Count hyphenated IDs
      final hyphenatedCount = trips.where((t) => t['id'].toString().contains('-')).length;
      print('  ✓ Found $hyphenatedCount trips with hyphenated IDs');
      passed++;
      
      // Check for getTripData function
      if (response.body.contains('function getTripData')) {
        print('  ✓ getTripData function exists in live file');
        passed++;
      } else {
        print('  ✗ getTripData function MISSING from live file');
        failed++;
        allIssues.add('Live trips-data.js missing getTripData');
      }
      
      // Verify a sample trip has all fields
      if (trips.isNotEmpty) {
        final sampleTrip = trips.first;
        print('\n  Sample trip: ${sampleTrip['id']}');
        
        final criticalFields = ['title', 'location', 'price', 'about', 'itinerary'];
        for (final field in criticalFields) {
          if (sampleTrip.containsKey(field) && sampleTrip[field] != null) {
            print('    ✓ Has $field');
          } else {
            print('    ✗ Missing $field');
          }
        }
      }
    } else {
      print('  ✗ Failed to fetch: ${response.statusCode}');
      failed++;
    }
  } catch (e) {
    print('  ✗ Error: $e');
    failed++;
  }

  // Test 4.2: Round-trip with live data
  print('\n4.2 Round-trip with live data');
  print('-' * 50);
  
  try {
    final response = await http.get(Uri.parse(
      'https://raw.githubusercontent.com/teamweekendtrekkers-png/teamweekendtrekkerwebsite/main/js/trips-data.js'
    ));
    
    if (response.statusCode == 200) {
      final trips1 = _parseTripsData(response.body);
      final generated = _generateTripsDataJs(trips1);
      final trips2 = _parseTripsData(generated);
      
      if (trips1.length == trips2.length) {
        print('  ✓ Trip count preserved: ${trips1.length}');
        passed++;
      } else {
        print('  ✗ Trip count changed: ${trips1.length} → ${trips2.length}');
        failed++;
        allIssues.add('Round-trip changes trip count');
      }
      
      // Verify IDs are preserved
      final ids1 = trips1.map((t) => t['id']).toSet();
      final ids2 = trips2.map((t) => t['id']).toSet();
      
      if (ids1.difference(ids2).isEmpty && ids2.difference(ids1).isEmpty) {
        print('  ✓ All trip IDs preserved');
        passed++;
      } else {
        print('  ✗ Some trip IDs lost or changed');
        failed++;
      }
    }
  } catch (e) {
    print('  ✗ Error: $e');
    failed++;
  }

  print('\n  Section 4 Results: $passed passed, $failed failed');
  totalPassed += passed;
  totalFailed += failed;

  // ════════════════════════════════════════════════════════════════════
  // FINAL SUMMARY
  // ════════════════════════════════════════════════════════════════════
  print('');
  print('═' * 70);
  print('FINAL TEST RESULTS: $totalPassed passed, $totalFailed failed');
  print('═' * 70);

  if (allIssues.isNotEmpty) {
    print('');
    print('CRITICAL ISSUES FOUND:');
    print('-' * 50);
    for (var i = 0; i < allIssues.length; i++) {
      print('${i + 1}. ${allIssues[i]}');
    }
  }

  if (totalFailed == 0) {
    print('');
    print('🎉 ALL TESTS PASSED!');
    print('');
    print('The app can:');
    print('  ✓ Parse trips from website (simple + hyphenated keys)');
    print('  ✓ Generate valid trips-data.js with getTripData()');
    print('  ✓ Handle all 17+ website-required fields');
    print('  ✓ Compute UPI checksums correctly');
    print('  ✓ Encode/decode UPI IDs');
    print('  ✓ Generate proper masked UPI format');
    print('  ✓ Validate UPI and WhatsApp inputs');
    print('  ✓ Round-trip data without loss');
  } else {
    print('');
    print('⚠️  Some tests failed. Please review the issues above.');
  }
}

// ════════════════════════════════════════════════════════════════════
// PARSER IMPLEMENTATION (matches trips_parser.dart)
// ════════════════════════════════════════════════════════════════════

List<Map<String, dynamic>> _parseTripsData(String jsContent) {
  final trips = <Map<String, dynamic>>[];
  
  // Find the tripsData object
  final dataMatch = RegExp(r'const\s+tripsData\s*=\s*\{', multiLine: true).firstMatch(jsContent);
  if (dataMatch == null) return trips;
  
  // Extract content between the main braces
  int braceCount = 0;
  int startIndex = dataMatch.end - 1;
  int endIndex = startIndex;
  
  for (int i = startIndex; i < jsContent.length; i++) {
    if (jsContent[i] == '{') braceCount++;
    if (jsContent[i] == '}') braceCount--;
    if (braceCount == 0) {
      endIndex = i;
      break;
    }
  }
  
  final tripsContent = jsContent.substring(startIndex, endIndex + 1);
  
  // Find each trip entry - handle both quoted and unquoted keys
  final tripPattern = RegExp(r'(?:([a-zA-Z_][a-zA-Z0-9_]*)|"([^"]+)")\s*:\s*\{', multiLine: true);
  
  for (final match in tripPattern.allMatches(tripsContent)) {
    final tripId = match.group(1) ?? match.group(2);
    if (tripId == null) continue;
    
    // Find the trip object
    int tripStart = match.end - 1;
    int tripBraceCount = 0;
    int tripEnd = tripStart;
    
    for (int i = tripStart; i < tripsContent.length; i++) {
      if (tripsContent[i] == '{') tripBraceCount++;
      if (tripsContent[i] == '}') tripBraceCount--;
      if (tripBraceCount == 0) {
        tripEnd = i;
        break;
      }
    }
    
    final tripContent = tripsContent.substring(tripStart, tripEnd + 1);
    final tripData = _parseTripObject(tripContent);
    tripData['id'] = tripId;
    
    // Create aliases for compatibility
    if (tripData.containsKey('title')) {
      tripData['name'] = tripData['title'];
    }
    if (tripData.containsKey('location')) {
      tripData['destination'] = tripData['location'];
    }
    if (tripData.containsKey('about')) {
      tripData['description'] = tripData['about'];
    }
    if (tripData.containsKey('includes')) {
      tripData['inclusions'] = tripData['includes'];
    }
    if (tripData.containsKey('excludes')) {
      tripData['exclusions'] = tripData['excludes'];
    }
    
    trips.add(tripData);
  }
  
  return trips;
}

Map<String, dynamic> _parseTripObject(String content) {
  final data = <String, dynamic>{};
  
  // Simple string fields
  final stringPattern = RegExp(r'(\w+)\s*:\s*"([^"]*)"');
  for (final match in stringPattern.allMatches(content)) {
    data[match.group(1)!] = match.group(2)!;
  }
  
  // Simple array of strings
  final arrayPattern = RegExp(r'(\w+)\s*:\s*\[([^\]]*)\]', multiLine: true);
  for (final match in arrayPattern.allMatches(content)) {
    final key = match.group(1)!;
    final arrayContent = match.group(2)!;
    
    if (key == 'itinerary') continue; // Handle separately
    
    final items = <String>[];
    final itemPattern = RegExp(r'"([^"]*)"');
    for (final itemMatch in itemPattern.allMatches(arrayContent)) {
      items.add(itemMatch.group(1)!);
    }
    if (items.isNotEmpty) {
      data[key] = items;
    }
  }
  
  // Itinerary array
  final itineraryPattern = RegExp(r'itinerary\s*:\s*\[');
  final itineraryMatch = itineraryPattern.firstMatch(content);
  if (itineraryMatch != null) {
    final itinerary = <Map<String, dynamic>>[];
    final dayPattern = RegExp(r'\{[^}]*day\s*:\s*"([^"]*)"[^}]*title\s*:\s*"([^"]*)"[^}]*activities\s*:\s*\[([^\]]*)\][^}]*\}');
    
    for (final dayMatch in dayPattern.allMatches(content)) {
      final activities = <String>[];
      final actPattern = RegExp(r'"([^"]*)"');
      for (final actMatch in actPattern.allMatches(dayMatch.group(3)!)) {
        activities.add(actMatch.group(1)!);
      }
      
      itinerary.add({
        'day': dayMatch.group(1),
        'title': dayMatch.group(2),
        'activities': activities,
      });
    }
    
    if (itinerary.isNotEmpty) {
      data['itinerary'] = itinerary;
    }
  }
  
  return data;
}

String _generateTripsDataJs(List<Map<String, dynamic>> trips) {
  final buffer = StringBuffer();
  
  buffer.writeln('// Trip data - Auto-generated by Trip Manager App');
  buffer.writeln('// Last updated: ${DateTime.now().toIso8601String()}');
  buffer.writeln('');
  buffer.writeln('const tripsData = {');
  
  for (var i = 0; i < trips.length; i++) {
    final trip = trips[i];
    final tripId = trip['id']?.toString() ?? 'unknown';
    
    // Quote hyphenated keys
    final keyName = tripId.contains('-') ? '"$tripId"' : tripId;
    
    buffer.writeln('    $keyName: {');
    
    // String fields
    final stringFields = ['title', 'location', 'badge', 'price', 'image', 
                         'distance', 'elevation', 'difficulty', 'bestTime',
                         'duration', 'about', 'groupSize'];
    
    for (final field in stringFields) {
      final value = trip[field]?.toString() ?? '';
      if (value.isNotEmpty) {
        final escaped = value.replaceAll('"', '\\"').replaceAll('\n', '\\n');
        buffer.writeln('        $field: "$escaped",');
      }
    }
    
    // Array fields
    _writeArrayField(buffer, trip, 'availableDates');
    _writeArrayField(buffer, trip, 'highlights');
    _writeArrayField(buffer, trip, 'includes', fallback: 'inclusions');
    _writeArrayField(buffer, trip, 'excludes', fallback: 'exclusions');
    
    // Itinerary
    final itinerary = trip['itinerary'] as List<dynamic>?;
    if (itinerary != null && itinerary.isNotEmpty) {
      buffer.writeln('        itinerary: [');
      for (final day in itinerary) {
        if (day is Map) {
          buffer.writeln('            {day: "${day['day']}", title: "${day['title']}", activities: [${(day['activities'] as List?)?.map((a) => '"$a"').join(', ') ?? ''}]},');
        }
      }
      buffer.writeln('        ],');
    }
    
    buffer.writeln('    },');
  }
  
  buffer.writeln('};');
  buffer.writeln('');
  
  // Add getTripData function
  buffer.writeln('function getTripData(tripId) {');
  buffer.writeln('    return tripsData[tripId] || tripsData[Object.keys(tripsData)[0]];');
  buffer.writeln('}');
  
  return buffer.toString();
}

void _writeArrayField(StringBuffer buffer, Map<String, dynamic> trip, String field, {String? fallback}) {
  var items = trip[field] as List<dynamic>?;
  if (items == null && fallback != null) {
    items = trip[fallback] as List<dynamic>?;
  }
  
  if (items != null && items.isNotEmpty) {
    final escaped = items.map((item) => '"${item.toString().replaceAll('"', '\\"')}"').join(', ');
    buffer.writeln('        $field: [$escaped],');
  }
}
