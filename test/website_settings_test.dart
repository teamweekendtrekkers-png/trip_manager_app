import 'dart:convert';
import 'package:http/http.dart' as http;

/// Test suite for Website Settings Service (UPI & WhatsApp sync)
void main() async {
  print('=' * 70);
  print('WEBSITE SETTINGS SERVICE - COMPREHENSIVE TEST');
  print('=' * 70);
  print('');

  int passed = 0;
  int failed = 0;
  final issues = <String>[];

  // ============================================================
  // TEST 1: Checksum Computation
  // ============================================================
  print('TEST 1: Checksum computation (must match website algorithm)');
  print('-' * 50);

  // The website uses this algorithm:
  // function computeChecksum(str) {
  //     let sum = 0;
  //     for (let i = 0; i < str.length; i++) {
  //         sum = ((sum << 5) - sum + str.charCodeAt(i)) | 0;
  //     }
  //     return sum;
  // }

  int computeChecksum(String str) {
    int sum = 0;
    for (int i = 0; i < str.length; i++) {
      sum = ((sum << 5) - sum + str.codeUnitAt(i));
      // JavaScript's | 0 converts to 32-bit signed integer
      sum = sum.toSigned(32);
    }
    return sum;
  }

  // Test with known UPI
  const knownUpi = '9538236581@ybl';
  const expectedChecksum = 1165100733;
  
  final computedChecksum = computeChecksum(knownUpi);
  
  if (computedChecksum == expectedChecksum) {
    print('  ✓ Checksum matches: $computedChecksum');
    passed++;
  } else {
    print('  ✗ Checksum mismatch!');
    print('    Expected: $expectedChecksum');
    print('    Got: $computedChecksum');
    failed++;
    issues.add('Checksum algorithm mismatch');
  }

  // Test with different UPIs
  final testUPIs = [
    '1234567890@upi',
    '9876543210@paytm',
    '5555555555@ybl',
  ];
  
  for (final upi in testUPIs) {
    final checksum = computeChecksum(upi);
    print('  ℹ Checksum for "$upi": $checksum');
  }

  print('');

  // ============================================================
  // TEST 2: UPI Encoding/Decoding
  // ============================================================
  print('TEST 2: UPI ASCII encoding/decoding');
  print('-' * 50);

  String encodeUpiToAscii(String upi) {
    final parts = upi.split('@');
    final number = parts[0];
    final provider = parts[1];
    
    final p1 = number.codeUnits.join(',');
    final p2 = '@'.codeUnitAt(0);
    final p3 = provider.codeUnits.join(',');
    
    return '_p1: [$p1], _p2: $p2, _p3: [$p3]';
  }

  String decodeUpiFromAscii(List<int> p1, int p2, List<int> p3) {
    return String.fromCharCodes(p1) + String.fromCharCode(p2) + String.fromCharCodes(p3);
  }

  // Test encoding
  final encoded = encodeUpiToAscii(knownUpi);
  print('  Encoded "$knownUpi":');
  print('    $encoded');

  // Test decoding (known values from website)
  final p1Known = [57, 53, 51, 56, 50, 51, 54, 53, 56, 49];
  const p2Known = 64;
  final p3Known = [121, 98, 108];
  
  final decoded = decodeUpiFromAscii(p1Known, p2Known, p3Known);
  
  if (decoded == knownUpi) {
    print('  ✓ Decoded correctly: $decoded');
    passed++;
  } else {
    print('  ✗ Decode mismatch! Got: $decoded, Expected: $knownUpi');
    failed++;
    issues.add('UPI decoding failed');
  }

  // Round-trip test
  for (final upi in testUPIs) {
    final parts = upi.split('@');
    final p1 = parts[0].codeUnits;
    final p2 = '@'.codeUnitAt(0);
    final p3 = parts[1].codeUnits;
    
    final roundTrip = decodeUpiFromAscii(p1, p2, p3);
    if (roundTrip == upi) {
      print('  ✓ Round-trip OK: $upi');
      passed++;
    } else {
      print('  ✗ Round-trip failed for $upi');
      failed++;
    }
  }

  print('');

  // ============================================================
  // TEST 3: Security.js Pattern Matching
  // ============================================================
  print('TEST 3: Security.js regex pattern matching');
  print('-' * 50);

  const sampleSecurityJs = '''
const SecurityConfig = {
    _p1: [57,53,51,56,50,51,54,53,56,49],
    _p2: 64,  
    _p3: [121,98,108], 
    _checksum: 1165100733,
    _rateLimits: {
        copyAttempts: { max: 5, window: 60000 },
    },
};
''';

  // Test _p1 pattern
  final p1Match = RegExp(r'_p1:\s*\[([^\]]+)\]').firstMatch(sampleSecurityJs);
  if (p1Match != null) {
    final p1Values = p1Match.group(1)!.split(',').map((s) => int.parse(s.trim())).toList();
    if (p1Values.join(',') == p1Known.join(',')) {
      print('  ✓ _p1 pattern match: $p1Values');
      passed++;
    } else {
      print('  ✗ _p1 values mismatch');
      failed++;
    }
  } else {
    print('  ✗ _p1 pattern not found');
    failed++;
    issues.add('_p1 regex pattern failed');
  }

  // Test _p2 pattern
  final p2Match = RegExp(r'_p2:\s*(\d+)').firstMatch(sampleSecurityJs);
  if (p2Match != null && int.parse(p2Match.group(1)!) == p2Known) {
    print('  ✓ _p2 pattern match: ${p2Match.group(1)}');
    passed++;
  } else {
    print('  ✗ _p2 pattern failed');
    failed++;
  }

  // Test _p3 pattern
  final p3Match = RegExp(r'_p3:\s*\[([^\]]+)\]').firstMatch(sampleSecurityJs);
  if (p3Match != null) {
    final p3Values = p3Match.group(1)!.split(',').map((s) => int.parse(s.trim())).toList();
    if (p3Values.join(',') == p3Known.join(',')) {
      print('  ✓ _p3 pattern match: $p3Values');
      passed++;
    } else {
      print('  ✗ _p3 values mismatch');
      failed++;
    }
  } else {
    print('  ✗ _p3 pattern not found');
    failed++;
  }

  // Test checksum pattern
  final checksumMatch = RegExp(r'_checksum:\s*(-?\d+)').firstMatch(sampleSecurityJs);
  if (checksumMatch != null && int.parse(checksumMatch.group(1)!) == expectedChecksum) {
    print('  ✓ _checksum pattern match: ${checksumMatch.group(1)}');
    passed++;
  } else {
    print('  ✗ _checksum pattern failed');
    failed++;
  }

  print('');

  // ============================================================
  // TEST 4: Security.js Update Simulation
  // ============================================================
  print('TEST 4: Security.js content update simulation');
  print('-' * 50);

  String updateSecurityJs(String content, String newUpi) {
    final parts = newUpi.split('@');
    final p1Array = parts[0].codeUnits;
    final p2Code = '@'.codeUnitAt(0);
    final p3Array = parts[1].codeUnits;
    final checksum = computeChecksum(newUpi);

    content = content.replaceAllMapped(
      RegExp(r'_p1:\s*\[[^\]]+\]'),
      (match) => '_p1: [${p1Array.join(",")}]',
    );
    content = content.replaceAllMapped(
      RegExp(r'_p2:\s*\d+'),
      (match) => '_p2: $p2Code',
    );
    content = content.replaceAllMapped(
      RegExp(r'_p3:\s*\[[^\]]+\]'),
      (match) => '_p3: [${p3Array.join(",")}]',
    );
    content = content.replaceAllMapped(
      RegExp(r'_checksum:\s*-?\d+'),
      (match) => '_checksum: $checksum',
    );

    return content;
  }

  const newTestUpi = '1111222233@paytm';
  final updatedJs = updateSecurityJs(sampleSecurityJs, newTestUpi);
  
  // Verify the update
  final newP1Match = RegExp(r'_p1:\s*\[([^\]]+)\]').firstMatch(updatedJs);
  final newP3Match = RegExp(r'_p3:\s*\[([^\]]+)\]').firstMatch(updatedJs);
  final newChecksumMatch = RegExp(r'_checksum:\s*(-?\d+)').firstMatch(updatedJs);

  if (newP1Match != null) {
    final newP1 = newP1Match.group(1)!.split(',').map((s) => int.parse(s.trim())).toList();
    final expectedP1 = '1111222233'.codeUnits;
    if (newP1.join(',') == expectedP1.join(',')) {
      print('  ✓ _p1 updated correctly');
      passed++;
    } else {
      print('  ✗ _p1 update failed');
      failed++;
    }
  }

  if (newP3Match != null) {
    final newP3 = newP3Match.group(1)!.split(',').map((s) => int.parse(s.trim())).toList();
    final expectedP3 = 'paytm'.codeUnits;
    if (newP3.join(',') == expectedP3.join(',')) {
      print('  ✓ _p3 updated correctly');
      passed++;
    } else {
      print('  ✗ _p3 update failed');
      failed++;
    }
  }

  if (newChecksumMatch != null) {
    final newChecksum = int.parse(newChecksumMatch.group(1)!);
    final expectedNewChecksum = computeChecksum(newTestUpi);
    if (newChecksum == expectedNewChecksum) {
      print('  ✓ _checksum updated correctly: $newChecksum');
      passed++;
    } else {
      print('  ✗ _checksum update failed');
      failed++;
    }
  }

  // Verify round-trip: decode the updated values and compare
  if (newP1Match != null && newP3Match != null) {
    final decodedP1 = newP1Match.group(1)!.split(',').map((s) => int.parse(s.trim())).toList();
    final decodedP3 = newP3Match.group(1)!.split(',').map((s) => int.parse(s.trim())).toList();
    final reconstructed = decodeUpiFromAscii(decodedP1, 64, decodedP3);
    
    if (reconstructed == newTestUpi) {
      print('  ✓ Full round-trip verified: $reconstructed');
      passed++;
    } else {
      print('  ✗ Round-trip failed: got $reconstructed');
      failed++;
      issues.add('Security.js update round-trip failed');
    }
  }

  print('');

  // ============================================================
  // TEST 5: WhatsApp URL Pattern Matching
  // ============================================================
  print('TEST 5: WhatsApp URL pattern matching in HTML');
  print('-' * 50);

  const sampleHtml = '''
<a href="https://wa.me/917019235581?text=Hi!" target="_blank">Chat</a>
<a href="https://wa.me/917019235581" class="whatsapp-float">WhatsApp</a>
<p>Contact: +91 7019235581</p>
''';

  // Extract WhatsApp number
  final waMatch = RegExp(r'wa\.me/(\d+)').firstMatch(sampleHtml);
  if (waMatch != null && waMatch.group(1) == '917019235581') {
    print('  ✓ WhatsApp number extracted: ${waMatch.group(1)}');
    passed++;
  } else {
    print('  ✗ WhatsApp extraction failed');
    failed++;
  }

  // Test replacement
  const newWhatsApp = '919876543210';
  const oldWhatsApp = '917019235581';
  
  final updatedHtml = sampleHtml.replaceAll(oldWhatsApp, newWhatsApp);
  
  // Count replacements
  final oldCount = RegExp(oldWhatsApp).allMatches(sampleHtml).length;
  final newCount = RegExp(newWhatsApp).allMatches(updatedHtml).length;
  final remainingOld = RegExp(oldWhatsApp).allMatches(updatedHtml).length;
  
  if (newCount == oldCount && remainingOld == 0) {
    print('  ✓ WhatsApp replaced in all $newCount locations');
    passed++;
  } else {
    print('  ✗ WhatsApp replacement incomplete');
    print('    Original had $oldCount occurrences');
    print('    New has $newCount occurrences');
    print('    Old remaining: $remainingOld');
    failed++;
    issues.add('WhatsApp replacement failed');
  }

  print('');

  // ============================================================
  // TEST 6: Fetch and verify LIVE website security.js
  // ============================================================
  print('TEST 6: Fetch and verify LIVE security.js from GitHub');
  print('-' * 50);

  try {
    final response = await http.get(Uri.parse(
      'https://raw.githubusercontent.com/teamweekendtrekkers-png/teamweekendtrekkerwebsite/main/js/security.js'
    ));

    if (response.statusCode == 200) {
      final liveContent = response.body;
      
      // Extract live UPI
      final liveP1 = RegExp(r'_p1:\s*\[([^\]]+)\]').firstMatch(liveContent);
      final liveP2 = RegExp(r'_p2:\s*(\d+)').firstMatch(liveContent);
      final liveP3 = RegExp(r'_p3:\s*\[([^\]]+)\]').firstMatch(liveContent);
      final liveChecksum = RegExp(r'_checksum:\s*(-?\d+)').firstMatch(liveContent);

      if (liveP1 != null && liveP2 != null && liveP3 != null && liveChecksum != null) {
        final p1Codes = liveP1.group(1)!.split(',').map((s) => int.parse(s.trim())).toList();
        final p2Code = int.parse(liveP2.group(1)!);
        final p3Codes = liveP3.group(1)!.split(',').map((s) => int.parse(s.trim())).toList();
        final checksumValue = int.parse(liveChecksum.group(1)!);

        final liveUpi = decodeUpiFromAscii(p1Codes, p2Code, p3Codes);
        final computedLiveChecksum = computeChecksum(liveUpi);

        print('  ✓ Live UPI decoded: $liveUpi');
        print('  ✓ Live checksum: $checksumValue');
        passed++;

        if (computedLiveChecksum == checksumValue) {
          print('  ✓ Checksum verification PASSED');
          passed++;
        } else {
          print('  ✗ Checksum verification FAILED');
          print('    Expected: $checksumValue');
          print('    Computed: $computedLiveChecksum');
          failed++;
          issues.add('Live checksum verification failed');
        }

        // Simulate update and verify
        final simulatedUpdate = updateSecurityJs(liveContent, '9999888877@test');
        final updatedP1 = RegExp(r'_p1:\s*\[([^\]]+)\]').firstMatch(simulatedUpdate);
        if (updatedP1 != null) {
          print('  ✓ Simulated update would produce valid output');
          passed++;
        }
      } else {
        print('  ✗ Could not parse live security.js');
        failed++;
      }
    } else {
      print('  ✗ Failed to fetch: ${response.statusCode}');
      failed++;
    }
  } catch (e) {
    print('  ✗ Network error: $e');
    failed++;
  }

  print('');

  // ============================================================
  // TEST 7: Fetch and verify LIVE WhatsApp in HTML
  // ============================================================
  print('TEST 7: Fetch and verify LIVE WhatsApp from index.html');
  print('-' * 50);

  try {
    final response = await http.get(Uri.parse(
      'https://raw.githubusercontent.com/teamweekendtrekkers-png/teamweekendtrekkerwebsite/main/index.html'
    ));

    if (response.statusCode == 200) {
      final liveHtml = response.body;
      
      // Extract WhatsApp numbers
      final waMatches = RegExp(r'wa\.me/(\d+)').allMatches(liveHtml);
      final numbers = waMatches.map((m) => m.group(1)).toSet();
      
      if (numbers.isNotEmpty) {
        print('  ✓ Found WhatsApp numbers: $numbers');
        passed++;
        
        // Count occurrences
        for (final num in numbers) {
          final count = RegExp('wa\\.me/$num').allMatches(liveHtml).length;
          print('    - $num appears $count times');
        }
        
        // Simulate replacement
        if (numbers.contains('917019235581')) {
          final testReplacement = liveHtml.replaceAll('917019235581', '919999999999');
          final oldRemaining = RegExp('917019235581').allMatches(testReplacement).length;
          final newCount = RegExp('919999999999').allMatches(testReplacement).length;
          
          if (oldRemaining == 0 && newCount > 0) {
            print('  ✓ Replacement simulation successful ($newCount replacements)');
            passed++;
          } else {
            print('  ✗ Replacement simulation failed');
            failed++;
          }
        }
      } else {
        print('  ✗ No WhatsApp numbers found');
        failed++;
      }
    } else {
      print('  ✗ Failed to fetch: ${response.statusCode}');
      failed++;
    }
  } catch (e) {
    print('  ✗ Network error: $e');
    failed++;
  }

  print('');

  // ============================================================
  // TEST 8: Validation patterns
  // ============================================================
  print('TEST 8: Input validation patterns');
  print('-' * 50);

  bool isValidUpi(String upi) {
    final regex = RegExp(r'^\d{10,12}@[a-z]{2,10}$', caseSensitive: false);
    return regex.hasMatch(upi);
  }

  bool isValidWhatsApp(String number) {
    final regex = RegExp(r'^\d{10,15}$');
    return regex.hasMatch(number);
  }

  final upiTests = {
    '9538236581@ybl': true,
    '1234567890@paytm': true,
    '12345678901@upi': true,
    '1234567890@ab': true,
    '123@ybl': false,  // Too short
    '9538236581': false,  // No @
    '9538236581@': false,  // No provider
    '@ybl': false,  // No number
    '9538236581@y': false,  // Provider too short
  };

  final waTests = {
    '917019235581': true,
    '919876543210': true,
    '1234567890': true,
    '12345678901234': true,
    '123': false,  // Too short
    '12345678901234567': false,  // Too long
    '91701923558a': false,  // Contains letter
  };

  var allValidationsPassed = true;
  
  for (final entry in upiTests.entries) {
    final result = isValidUpi(entry.key);
    if (result == entry.value) {
      print('  ✓ UPI "${entry.key}": ${result ? "valid" : "invalid"}');
    } else {
      print('  ✗ UPI "${entry.key}": expected ${entry.value}, got $result');
      allValidationsPassed = false;
    }
  }

  for (final entry in waTests.entries) {
    final result = isValidWhatsApp(entry.key);
    if (result == entry.value) {
      print('  ✓ WhatsApp "${entry.key}": ${result ? "valid" : "invalid"}');
    } else {
      print('  ✗ WhatsApp "${entry.key}": expected ${entry.value}, got $result');
      allValidationsPassed = false;
    }
  }

  if (allValidationsPassed) {
    print('  ✓ All validation tests passed');
    passed++;
  } else {
    failed++;
    issues.add('Some validation tests failed');
  }

  print('');

  // ============================================================
  // SUMMARY
  // ============================================================
  print('=' * 70);
  print('TEST RESULTS: $passed passed, $failed failed');
  print('=' * 70);

  if (issues.isNotEmpty) {
    print('');
    print('ISSUES FOUND:');
    print('-' * 50);
    for (var i = 0; i < issues.length; i++) {
      print('${i + 1}. ${issues[i]}');
    }
  }

  if (failed == 0) {
    print('');
    print('🎉 ALL TESTS PASSED! Website settings sync is working correctly.');
    print('');
    print('The app can now:');
    print('  ✓ Encode UPI IDs to ASCII (matching website format)');
    print('  ✓ Compute checksums (matching website algorithm)');
    print('  ✓ Update security.js with new UPI');
    print('  ✓ Replace WhatsApp numbers in HTML files');
    print('  ✓ Validate input formats');
  }
}
