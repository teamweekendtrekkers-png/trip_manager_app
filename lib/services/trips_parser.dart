/// Parser for the trips-data.js JavaScript file
/// Converts between JS format and Dart objects
class TripsParser {
  
  /// Parse the trips-data.js content into a list of trip maps
  static List<Map<String, dynamic>> parseTripsData(String jsContent) {
    final trips = <Map<String, dynamic>>[];
    
    // Find the tripsData array
    final startMatch = RegExp(r'const\s+tripsData\s*=\s*\[').firstMatch(jsContent);
    if (startMatch == null) return trips;
    
    // Extract just the array content
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
    
    final arrayContent = jsContent.substring(startIndex, endIndex);
    
    // Parse individual trip objects
    final tripMatches = RegExp(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}').allMatches(arrayContent);
    
    for (final match in tripMatches) {
      final tripStr = match.group(0)!;
      final trip = _parseJsObject(tripStr);
      if (trip.isNotEmpty) {
        trips.add(trip);
      }
    }
    
    return trips;
  }
  
  /// Parse a single JS object string into a Map
  static Map<String, dynamic> _parseJsObject(String jsObj) {
    final result = <String, dynamic>{};
    
    // Extract key-value pairs
    final patterns = {
      'id': RegExp(r'''id:\s*['"]([^'"]+)['"]'''),
      'name': RegExp(r'''name:\s*['"]([^'"]+)['"]'''),
      'destination': RegExp(r'''destination:\s*['"]([^'"]+)['"]'''),
      'description': RegExp(r'''description:\s*['"]([^'"]+)['"]'''),
      'image': RegExp(r'''image:\s*['"]([^'"]+)['"]'''),
      'difficulty': RegExp(r'''difficulty:\s*['"]([^'"]+)['"]'''),
      'pickupPoint': RegExp(r'''pickupPoint:\s*['"]([^'"]+)['"]'''),
      'price': RegExp(r'''price:\s*(\d+(?:\.\d+)?)'''),
      'discountedPrice': RegExp(r'''discountedPrice:\s*(\d+(?:\.\d+)?)'''),
      'groupSize': RegExp(r'''groupSize:\s*(\d+)'''),
      'featured': RegExp(r'''featured:\s*(true|false)'''),
    };
    
    for (final entry in patterns.entries) {
      final match = entry.value.firstMatch(jsObj);
      if (match != null) {
        final key = entry.key;
        final value = match.group(1)!;
        
        if (key == 'price' || key == 'discountedPrice') {
          result[key] = double.tryParse(value) ?? 0;
        } else if (key == 'groupSize') {
          result[key] = int.tryParse(value) ?? 0;
        } else if (key == 'featured') {
          result[key] = value == 'true';
        } else {
          result[key] = value;
        }
      }
    }
    
    // Parse dates
    final dateMatch = RegExp(r'''date:\s*['"]([^'"]+)['"]''').firstMatch(jsObj);
    if (dateMatch != null) {
      result['date'] = dateMatch.group(1);
    }
    
    // Parse highlights array
    final highlightsMatch = RegExp(r'''highlights:\s*\[(.*?)\]''', dotAll: true).firstMatch(jsObj);
    if (highlightsMatch != null) {
      final highlightsStr = highlightsMatch.group(1)!;
      result['highlights'] = RegExp(r'''['"]([^'"]+)['"]''')
          .allMatches(highlightsStr)
          .map((m) => m.group(1)!)
          .toList();
    }
    
    // Parse itinerary array
    final itineraryMatch = RegExp(r'''itinerary:\s*\[(.*?)\](?=,\s*\w+:|})''', dotAll: true).firstMatch(jsObj);
    if (itineraryMatch != null) {
      result['itinerary'] = _parseItinerary(itineraryMatch.group(1)!);
    }
    
    // Parse inclusions
    final inclusionsMatch = RegExp(r'''inclusions:\s*\[(.*?)\]''', dotAll: true).firstMatch(jsObj);
    if (inclusionsMatch != null) {
      result['inclusions'] = RegExp(r'''['"]([^'"]+)['"]''')
          .allMatches(inclusionsMatch.group(1)!)
          .map((m) => m.group(1)!)
          .toList();
    }
    
    // Parse exclusions
    final exclusionsMatch = RegExp(r'''exclusions:\s*\[(.*?)\]''', dotAll: true).firstMatch(jsObj);
    if (exclusionsMatch != null) {
      result['exclusions'] = RegExp(r'''['"]([^'"]+)['"]''')
          .allMatches(exclusionsMatch.group(1)!)
          .map((m) => m.group(1)!)
          .toList();
    }
    
    return result;
  }
  
  /// Parse itinerary items
  static List<Map<String, dynamic>> _parseItinerary(String itineraryStr) {
    final items = <Map<String, dynamic>>[];
    final dayMatches = RegExp(r'\{([^{}]+)\}').allMatches(itineraryStr);
    
    for (final match in dayMatches) {
      final dayStr = match.group(1)!;
      final item = <String, dynamic>{};
      
      final dayMatch = RegExp(r'''day:\s*(\d+)''').firstMatch(dayStr);
      if (dayMatch != null) {
        item['day'] = int.parse(dayMatch.group(1)!);
      }
      
      final titleMatch = RegExp(r'''title:\s*['"]([^'"]+)['"]''').firstMatch(dayStr);
      if (titleMatch != null) {
        item['title'] = titleMatch.group(1);
      }
      
      final descMatch = RegExp(r'''description:\s*['"]([^'"]+)['"]''').firstMatch(dayStr);
      if (descMatch != null) {
        item['description'] = descMatch.group(1);
      }
      
      if (item.isNotEmpty) {
        items.add(item);
      }
    }
    
    return items;
  }
  
  /// Generate trips-data.js content from trip maps
  static String generateTripsDataJs(List<Map<String, dynamic>> trips) {
    final buffer = StringBuffer();
    buffer.writeln('// Trip data for Team Weekend Trekkers');
    buffer.writeln('// Auto-generated by Trip Manager App');
    buffer.writeln('// Last updated: ${DateTime.now().toIso8601String()}');
    buffer.writeln();
    buffer.writeln('const tripsData = [');
    
    for (int i = 0; i < trips.length; i++) {
      final trip = trips[i];
      buffer.writeln('    {');
      buffer.writeln("        id: '${_escapeJs(trip['id'] ?? '')}',");
      buffer.writeln("        name: '${_escapeJs(trip['name'] ?? '')}',");
      buffer.writeln("        destination: '${_escapeJs(trip['destination'] ?? '')}',");
      buffer.writeln("        date: '${_escapeJs(trip['date'] ?? '')}',");
      buffer.writeln("        description: '${_escapeJs(trip['description'] ?? '')}',");
      buffer.writeln("        image: '${_escapeJs(trip['image'] ?? '')}',");
      buffer.writeln("        price: ${trip['price'] ?? 0},");
      
      if (trip['discountedPrice'] != null) {
        buffer.writeln("        discountedPrice: ${trip['discountedPrice']},");
      }
      
      buffer.writeln("        difficulty: '${_escapeJs(trip['difficulty'] ?? 'Moderate')}',");
      buffer.writeln("        groupSize: ${trip['groupSize'] ?? 20},");
      buffer.writeln("        pickupPoint: '${_escapeJs(trip['pickupPoint'] ?? '')}',");
      buffer.writeln("        featured: ${trip['featured'] ?? false},");
      
      // Highlights
      final highlights = trip['highlights'] as List<dynamic>? ?? [];
      buffer.writeln("        highlights: [");
      for (final h in highlights) {
        buffer.writeln("            '${_escapeJs(h.toString())}',");
      }
      buffer.writeln("        ],");
      
      // Itinerary
      final itinerary = trip['itinerary'] as List<dynamic>? ?? [];
      buffer.writeln("        itinerary: [");
      for (final item in itinerary) {
        if (item is Map) {
          buffer.writeln("            {");
          buffer.writeln("                day: ${item['day'] ?? 1},");
          buffer.writeln("                title: '${_escapeJs(item['title']?.toString() ?? '')}',");
          buffer.writeln("                description: '${_escapeJs(item['description']?.toString() ?? '')}'");
          buffer.writeln("            },");
        }
      }
      buffer.writeln("        ],");
      
      // Inclusions
      final inclusions = trip['inclusions'] as List<dynamic>? ?? [];
      buffer.writeln("        inclusions: [");
      for (final inc in inclusions) {
        buffer.writeln("            '${_escapeJs(inc.toString())}',");
      }
      buffer.writeln("        ],");
      
      // Exclusions
      final exclusions = trip['exclusions'] as List<dynamic>? ?? [];
      buffer.writeln("        exclusions: [");
      for (final exc in exclusions) {
        buffer.writeln("            '${_escapeJs(exc.toString())}',");
      }
      buffer.writeln("        ]");
      
      buffer.writeln('    }${i < trips.length - 1 ? ',' : ''}');
    }
    
    buffer.writeln('];');
    return buffer.toString();
  }
  
  /// Escape special characters for JavaScript strings
  static String _escapeJs(String str) {
    return str
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }
}
