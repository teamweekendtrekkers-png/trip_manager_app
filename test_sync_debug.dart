import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('═' * 60);
  print('TESTING UPI SYNC FUNCTIONALITY');
  print('═' * 60);
  
  // Test 1: Check current website UPI
  print('\n1. CURRENT WEBSITE STATE:');
  print('-' * 40);
  
  final securityJs = await http.get(Uri.parse(
    'https://raw.githubusercontent.com/teamweekendtrekkers-png/teamweekendtrekkerwebsite/main/js/security.js'
  ));
  
  final p1Match = RegExp(r'_p1:\s*\[([^\]]+)\]').firstMatch(securityJs.body);
  final p2Match = RegExp(r'_p2:\s*(\d+)').firstMatch(securityJs.body);
  final p3Match = RegExp(r'_p3:\s*\[([^\]]+)\]').firstMatch(securityJs.body);
  final checksumMatch = RegExp(r'_checksum:\s*(-?\d+)').firstMatch(securityJs.body);
  
  if (p1Match != null && p2Match != null && p3Match != null) {
    final p1Codes = p1Match.group(1)!.split(',').map((s) => int.parse(s.trim())).toList();
    final p2Code = int.parse(p2Match.group(1)!);
    final p3Codes = p3Match.group(1)!.split(',').map((s) => int.parse(s.trim())).toList();
    
    final currentUpi = String.fromCharCodes(p1Codes) + String.fromCharCode(p2Code) + String.fromCharCodes(p3Codes);
    final currentChecksum = int.parse(checksumMatch!.group(1)!);
    
    print('  security.js UPI: $currentUpi');
    print('  security.js checksum: $currentChecksum');
    
    // Compute expected checksum
    int sum = 0;
    for (int i = 0; i < currentUpi.length; i++) {
      sum = ((sum << 5) - sum + currentUpi.codeUnitAt(i)).toSigned(32);
    }
    print('  Computed checksum: $sum');
    print('  Checksum valid: ${sum == currentChecksum ? "✓ YES" : "✗ NO"}');
  }
  
  // Test 2: Check masked UPI in HTML files
  print('\n2. MASKED UPI IN HTML FILES:');
  print('-' * 40);
  
  final htmlFiles = ['index.html', 'trip-detail.html', 'trips.html', 'about.html', 'contact.html'];
  final maskedPattern = RegExp(r'••••••[a-zA-Z0-9]+@[a-zA-Z0-9]+');
  
  for (final file in htmlFiles) {
    try {
      final response = await http.get(Uri.parse(
        'https://raw.githubusercontent.com/teamweekendtrekkers-png/teamweekendtrekkerwebsite/main/$file'
      ));
      final matches = maskedPattern.allMatches(response.body).toList();
      if (matches.isNotEmpty) {
        print('  $file: ${matches.map((m) => m.group(0)).toSet().join(", ")}');
      } else {
        print('  $file: NO masked UPI found');
      }
    } catch (e) {
      print('  $file: Error - $e');
    }
  }
  
  // Test 3: Simulate what sync SHOULD do
  print('\n3. SYNC SIMULATION:');
  print('-' * 40);
  
  const newUpi = 'ttrekkers@ybl';  // Test UPI
  final parts = newUpi.split('@');
  final p1Array = parts[0].codeUnits;
  final p2Code = '@'.codeUnitAt(0);
  final p3Array = parts[1].codeUnits;
  
  int checksum = 0;
  for (int i = 0; i < newUpi.length; i++) {
    checksum = ((checksum << 5) - checksum + newUpi.codeUnitAt(i)).toSigned(32);
  }
  
  print('  New UPI: $newUpi');
  print('  _p1 array: [${p1Array.join(",")}]');
  print('  _p2 value: $p2Code');
  print('  _p3 array: [${p3Array.join(",")}]');
  print('  _checksum: $checksum');
  
  final lastFour = parts[0].length > 4 ? parts[0].substring(parts[0].length - 4) : parts[0];
  final maskedUpi = '••••••$lastFour@${parts[1]}';
  print('  Masked display: $maskedUpi');
  
  print('\n4. WHAT SHOULD BE UPDATED:');
  print('-' * 40);
  print('  • js/security.js: _p1, _p2, _p3, _checksum');
  print('  • index.html: masked UPI → $maskedUpi');
  print('  • trip-detail.html: masked UPI → $maskedUpi');
  print('  • trips.html: masked UPI → $maskedUpi');
  print('  • about.html: masked UPI → $maskedUpi');
  print('  • contact.html: masked UPI → $maskedUpi');
  
  print('\n═' * 60);
}
