/// Parser for the trips-data.js JavaScript file
/// Handles object format: const tripsData = { tripId: {...}, tripId2: {...} }
class TripsParser {
  
  /// Parse the trips-data.js content into a list of trip maps
  static List<Map<String, dynamic>> parseTripsData(String jsContent) {
    final trips = <Map<String, dynamic>>[];
    
    // Find the tripsData object - handle both array and object format
    final objectMatch = RegExp(r'const\s+tripsData\s*=\s*\{').firstMatch(jsContent);
    if (objectMatch == null) {
      // Try array format as fallback
      return _parseArrayFormat(jsContent);
    }
    
    // Extract the object content
    int braceCount = 0;
    int startIndex = objectMatch.end - 1;
    int? endIndex;
    
    for (int i = startIndex; i < jsContent.length; i++) {
      if (jsContent[i] == '{') braceCount++;
      if (jsContent[i] == '}') braceCount--;
      if (braceCount == 0) {
        endIndex = i + 1;
        break;
      }
    }
    
    if (endIndex == null) return trips;
    
    final objectContent = jsContent.substring(startIndex + 1, endIndex - 1);
    
    // Parse each trip entry: tripId: { ... }
    // Find top-level keys by looking for pattern: identifier: {
    final tripPattern = RegExp(r'(?:(\w+)|"([^"]+)")\s*:\s*\{');
    final matches = tripPattern.allMatches(objectContent);
    
    for (final match in matches) {
      final tripId = match.group(1) ?? match.group(2)!;
      final tripStart = match.end - 1;
      
      // Find the matching closing brace for this trip
      int braces = 0;
      int? tripEnd;
      for (int i = tripStart; i < objectContent.length; i++) {
        if (objectContent[i] == '{') braces++;
        if (objectContent[i] == '}') braces--;
        if (braces == 0) {
          tripEnd = i + 1;
          break;
        }
      }
      
      if (tripEnd == null) continue;
      
      final tripContent = objectContent.substring(tripStart, tripEnd);
      final tripData = _parseTripObject(tripId, tripContent);
      if (tripData.isNotEmpty) {
        trips.add(tripData);
      }
    }
    
    return trips;
  }
  
  /// Parse array format as fallback
  static List<Map<String, dynamic>> _parseArrayFormat(String jsContent) {
    final trips = <Map<String, dynamic>>[];
    final startMatch = RegExp(r'const\s+tripsData\s*=\s*\[').firstMatch(jsContent);
    if (startMatch == null) return trips;
    
    int bracketCount = 0;
    int startIndex = startMatch.end - 1;
    int? endIndex;
    
    for (int i = startIndex; i < jsContent.length; i++) {
      if (jsContent[i] == '[') bracketCount++;
      if (jsContent[i] == ']') bracketCount--;
      if (bracketCount == 0) {
        endIndex = i + 1;
        break;
      }
    }
    
    if (endIndex == null) return trips;
    return trips;
  }
  
  /// Parse a single trip object
  static Map<String, dynamic> _parseTripObject(String tripId, String tripContent) {
    final result = <String, dynamic>{'id': tripId};
    
    // Extract string fields
    final stringPatterns = {
      'title': RegExp(r'''title:\s*["']([^"']+)["']'''),
      'location': RegExp(r'''location:\s*["']([^"']+)["']'''),
      'badge': RegExp(r'''badge:\s*["']([^"']+)["']'''),
      'price': RegExp(r'''price:\s*["']([^"']+)["']'''),
      'image': RegExp(r'''image:\s*["']([^"']+)["']'''),
      'distance': RegExp(r'''distance:\s*["']([^"']+)["']'''),
      'elevation': RegExp(r'''elevation:\s*["']([^"']+)["']'''),
      'difficulty': RegExp(r'''difficulty:\s*["']([^"']+)["']'''),
      'bestTime': RegExp(r'''bestTime:\s*["']([^"']+)["']'''),
      'duration': RegExp(r'''duration:\s*["']([^"']+)["']'''),
      'about': RegExp(r'''about:\s*["'](.+?)["'](?=,\s*\n|\s*\n\s*\w+:)''', dotAll: true),
      'groupSize': RegExp(r'''groupSize:\s*["']([^"']*)["']'''),
    };
    
    for (final entry in stringPatterns.entries) {
      final match = entry.value.firstMatch(tripContent);
      if (match != null) {
        var value = match.group(1)!;
        // Unescape newlines
        value = value.replaceAll(r'\n', '\n');
        result[entry.key] = value;
      }
    }
    
    // Map title to name for consistency
    if (result['title'] != null) {
      result['name'] = result['title'];
    }
    
    // Map location to destination
    if (result['location'] != null) {
      result['destination'] = result['location'];
    }
    
    // Parse availableDates array
    final datesMatch = RegExp(r'availableDates:\s*\[(.*?)\]', dotAll: true).firstMatch(tripContent);
    if (datesMatch != null) {
      final datesStr = datesMatch.group(1)!;
      final dates = RegExp(r'''["']([^"']+)["']''')
          .allMatches(datesStr)
          .map((m) => m.group(1)!)
          .toList();
      result['availableDates'] = dates;
      // Use first date as the main date
      if (dates.isNotEmpty) {
        result['date'] = dates.first;
      }
    }
    
    // Parse highlights array
    final highlightsMatch = RegExp(r'highlights:\s*\[(.*?)\]', dotAll: true).firstMatch(tripContent);
    if (highlightsMatch != null) {
      result['highlights'] = RegExp(r'''["']([^"']+)["']''')
          .allMatches(highlightsMatch.group(1)!)
          .map((m) => m.group(1)!)
          .toList();
    }
    
    // Parse includes array
    final includesMatch = RegExp(r'includes:\s*\[(.*?)\]', dotAll: true).firstMatch(tripContent);
    if (includesMatch != null) {
      result['inclusions'] = RegExp(r'''["']([^"']+)["']''')
          .allMatches(includesMatch.group(1)!)
          .map((m) => m.group(1)!)
          .toList();
    }
    
    // Parse excludes array
    final excludesMatch = RegExp(r'excludes:\s*\[(.*?)\]', dotAll: true).firstMatch(tripContent);
    if (excludesMatch != null) {
      result['exclusions'] = RegExp(r'''["']([^"']+)["']''')
          .allMatches(excludesMatch.group(1)!)
          .map((m) => m.group(1)!)
          .toList();
    }
    
    // Parse itinerary array
    final itineraryMatch = RegExp(r'itinerary:\s*\[(.*?)\]\s*,?\s*(?:includes:|excludes:|groupSize:|$)', dotAll: true).firstMatch(tripContent);
    if (itineraryMatch != null) {
      result['itinerary'] = _parseItinerary(itineraryMatch.group(1)!);
    }
    
    // Extract numeric price from string like "₹4,000"
    if (result['price'] != null) {
      final priceStr = result['price'].toString().replaceAll(RegExp(r'[₹,\s]'), '');
      result['priceNumeric'] = double.tryParse(priceStr) ?? 0;
    }
    
    // Set featured based on badge or other criteria
    result['featured'] = result['badge'] == 'Featured' || result['badge'] == 'Popular';
    
    return result;
  }
  
  /// Parse itinerary items
  static List<Map<String, dynamic>> _parseItinerary(String itineraryStr) {
    final items = <Map<String, dynamic>>[];
    
    // Find each day object
    final dayPattern = RegExp(r'\{[^{}]*day:[^{}]*\}', dotAll: true);
    final dayMatches = dayPattern.allMatches(itineraryStr);
    
    for (final match in dayMatches) {
      final dayStr = match.group(0)!;
      final item = <String, dynamic>{};
      
      final dayMatch = RegExp(r'''day:\s*["']?([^"',}]+)["']?''').firstMatch(dayStr);
      if (dayMatch != null) {
        item['day'] = dayMatch.group(1)?.trim();
      }
      
      final titleMatch = RegExp(r'''title:\s*["']([^"']+)["']''').firstMatch(dayStr);
      if (titleMatch != null) {
        item['title'] = titleMatch.group(1);
      }
      
      // Parse activities array within the day
      final activitiesMatch = RegExp(r'activities:\s*\[(.*?)\]', dotAll: true).firstMatch(dayStr);
      if (activitiesMatch != null) {
        item['activities'] = RegExp(r'''["']([^"']+)["']''')
            .allMatches(activitiesMatch.group(1)!)
            .map((m) => m.group(1)!)
            .toList();
        // Join activities into description
        item['description'] = (item['activities'] as List).join('\n');
      }
      
      if (item.isNotEmpty) {
        items.add(item);
      }
    }
    
    return items;
  }
  
  /// Generate trips-data.js content from trip maps (maintains object format)
  static String generateTripsDataJs(List<Map<String, dynamic>> trips) {
    final buffer = StringBuffer();
    buffer.writeln('// ============================================');
    buffer.writeln('// TEAM WEEKEND TREKKERS - TRIP DATABASE');
    buffer.writeln('// ============================================');
    buffer.writeln('// ');
    buffer.writeln('// Last updated: ${DateTime.now().toString().substring(0, 16)}');
    buffer.writeln('// Updated via Trip Manager Mobile App');
    buffer.writeln('// ============================================');
    buffer.writeln();
    buffer.writeln('const tripsData = {');
    
    for (int i = 0; i < trips.length; i++) {
      final trip = trips[i];
      final tripId = (trip['id'] ?? 'trip_${i + 1}').toString();
      
      final quotedId = tripId.contains("-") ? '"$tripId"' : tripId;
      buffer.writeln('    $quotedId: {');
      buffer.writeln('        title: "${_escapeJs((trip['title'] ?? trip['name'] ?? '').toString())}",');
      buffer.writeln('        location: "${_escapeJs((trip['location'] ?? trip['destination'] ?? '').toString())}",');
      buffer.writeln('        badge: "${_escapeJs((trip['badge'] ?? 'Trek').toString())}",');
      buffer.writeln('        price: "${_escapeJs((trip['price'] ?? '₹0').toString())}",');
      buffer.writeln('        image: "${_escapeJs((trip['image'] ?? 'images/trips/default.jpg').toString())}",');
      buffer.writeln('        distance: "${_escapeJs((trip['distance'] ?? '').toString())}",');
      buffer.writeln('        elevation: "${_escapeJs((trip['elevation'] ?? '').toString())}",');
      buffer.writeln('        difficulty: "${_escapeJs((trip['difficulty'] ?? 'Moderate').toString())}",');
      buffer.writeln('        bestTime: "${_escapeJs((trip['bestTime'] ?? '').toString())}",');
      buffer.writeln('        duration: "${_escapeJs((trip['duration'] ?? '').toString())}",');
      
      // Available dates
      final dates = trip['availableDates'] as List<dynamic>? ?? [];
      buffer.writeln('        availableDates: [${dates.map((d) => '"${_escapeJs(d.toString())}"').join(', ')}],');
      
      // About
      buffer.writeln('        about: "${_escapeJs((trip['about'] ?? trip['description'] ?? '').toString())}",');
      
      // Highlights
      final highlights = trip['highlights'] as List<dynamic>? ?? [];
      buffer.writeln('        highlights: [${highlights.map((h) => '"${_escapeJs(h.toString())}"').join(', ')}],');
      
      // Itinerary
      final itinerary = trip['itinerary'] as List<dynamic>? ?? [];
      buffer.writeln('        itinerary: [');
      for (final day in itinerary) {
        if (day is Map) {
          buffer.writeln('            {day: "${_escapeJs(day['day']?.toString() ?? '')}", title: "${_escapeJs(day['title']?.toString() ?? '')}", activities: [${(day['activities'] as List<dynamic>? ?? []).map((a) => '"${_escapeJs(a.toString())}"').join(', ')}]},');
        }
      }
      buffer.writeln('        ],');
      
      // Includes
      final includes = trip['inclusions'] as List<dynamic>? ?? trip['includes'] as List<dynamic>? ?? [];
      buffer.writeln('        includes: [${includes.map((i) => '"${_escapeJs(i.toString())}"').join(', ')}],');
      
      // Excludes
      final excludes = trip['exclusions'] as List<dynamic>? ?? trip['excludes'] as List<dynamic>? ?? [];
      buffer.writeln('        excludes: [${excludes.map((e) => '"${_escapeJs(e.toString())}"').join(', ')}],');
      
      buffer.writeln('        groupSize: "${_escapeJs((trip['groupSize'] ?? '').toString())}",');
      buffer.writeln('    },');
    }
    
    buffer.writeln('};');
    buffer.writeln();
    buffer.writeln('// ============================================');
    buffer.writeln('// GET TRIP DATA FUNCTION');
    buffer.writeln('// ============================================');
    buffer.writeln('// Returns trip data by ID, defaults to \'netravati\' if not found');
    buffer.writeln('function getTripData(tripId) {');
    buffer.writeln('    return tripsData[tripId] || tripsData[\'netravati\'];');
    buffer.writeln('}');
    return buffer.toString();
  }
  
  /// Escape special characters for JavaScript strings
  static String _escapeJs(String str) {
    return str
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }
}
