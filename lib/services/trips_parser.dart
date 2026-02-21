/// Parser for the trips-data.js JavaScript file
/// Handles object format: const tripsData = { tripId: {...}, tripId2: {...} }
class TripsParser {
  
  /// Default pickup points used by the website when trip has no custom boardingLocations
  static List<Map<String, dynamic>> getDefaultPickupPoints() {
    return [
      {
        'name': 'Majestic',
        'landmark': 'Metro Station / Shantala Silks',
        'time': '8:30 PM - 10:00 PM',
        'mapLink': 'https://maps.google.com/?q=Majestic+Metro+Station+Bangalore',
      },
      {
        'name': 'Koramangala',
        'landmark': 'Kota Kochari, Opp Forum Mall',
        'time': '9:00 PM - 10:30 PM',
        'mapLink': 'https://maps.google.com/?q=Forum+Mall+Koramangala+Bangalore',
      },
      {
        'name': 'Silk Board',
        'landmark': 'Silk Board Junction',
        'time': '9:15 PM - 10:45 PM',
        'mapLink': 'https://maps.google.com/?q=Silk+Board+Junction+Bangalore',
      },
      {
        'name': 'Electronic City',
        'landmark': 'Infosys Gate / Toll Plaza',
        'time': '9:45 PM - 11:15 PM',
        'mapLink': 'https://maps.google.com/?q=Electronic+City+Infosys+Bangalore',
      },
    ];
  }
  
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
    
    // Track seen IDs to detect duplicates
    final seenIds = <String>{};
    
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
        // Flag duplicate IDs as errors
        if (seenIds.contains(tripId)) {
          tripData['_duplicateWarning'] = true;
          tripData['_duplicateMessage'] = 'Duplicate trip ID: "$tripId" appears multiple times. The website only uses the last occurrence.';
        }
        seenIds.add(tripId);
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
    
    // Extract string fields - use patterns that properly handle apostrophes in double-quoted strings
    // The pattern "([^"]*)" matches content between double quotes, allowing apostrophes inside
    final stringPatterns = {
      'title': RegExp(r'title:\s*"([^"]*)"'),
      'location': RegExp(r'location:\s*"([^"]*)"'),
      'badge': RegExp(r'badge:\s*"([^"]*)"'),
      'price': RegExp(r'price:\s*"([^"]*)"'),
      'image': RegExp(r'image:\s*"([^"]*)"'),
      'distance': RegExp(r'distance:\s*"([^"]*)"'),
      'elevation': RegExp(r'elevation:\s*"([^"]*)"'),
      'difficulty': RegExp(r'difficulty:\s*"([^"]*)"'),
      'bestTime': RegExp(r'bestTime:\s*"([^"]*)"'),
      'duration': RegExp(r'duration:\s*"([^"]*)"'),
      'about': RegExp(r'about:\s*"(.+?)"(?=,\s*\n|\s*\n\s*\w+:)', dotAll: true),
      'groupSize': RegExp(r'groupSize:\s*"([^"]*)"'),
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
      // Use _parseStringArray to properly handle apostrophes in strings
      final rawDates = _parseStringArray(datesStr);
      // Handle corrupted data where dates were stored as single string with newlines
      final dates = <String>[];
      for (final date in rawDates) {
        if (date.contains('\n')) {
          // Split newline-joined dates into separate entries
          dates.addAll(date.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty));
        } else {
          dates.add(date);
        }
      }
      result['availableDates'] = dates;
      // Use first date as the main date
      if (dates.isNotEmpty) {
        result['date'] = dates.first;
      }
    }
    
    // Parse highlights array - handle double-quoted strings with apostrophes
    final highlightsMatch = RegExp(r'highlights:\s*\[(.*?)\]', dotAll: true).firstMatch(tripContent);
    if (highlightsMatch != null) {
      result['highlights'] = _parseStringArray(highlightsMatch.group(1)!);
    }
    
    // Parse includes array - handle double-quoted strings with apostrophes
    final includesMatch = RegExp(r'includes:\s*\[(.*?)\]', dotAll: true).firstMatch(tripContent);
    if (includesMatch != null) {
      result['inclusions'] = _parseStringArray(includesMatch.group(1)!);
    }
    
    // Parse excludes array - handle double-quoted strings with apostrophes
    final excludesMatch = RegExp(r'excludes:\s*\[(.*?)\]', dotAll: true).firstMatch(tripContent);
    if (excludesMatch != null) {
      result['exclusions'] = _parseStringArray(excludesMatch.group(1)!);
    }
    
    // Parse thingsToCarry array
    final thingsToCarryMatch = RegExp(r'thingsToCarry:\s*\[(.*?)\]', dotAll: true).firstMatch(tripContent);
    if (thingsToCarryMatch != null) {
      result['thingsToCarry'] = _parseStringArray(thingsToCarryMatch.group(1)!);
    } else {
      result['thingsToCarry'] = <String>[];
    }
    
    // Parse galleryImages array - handle double-quoted strings with apostrophes
    final galleryMatch = RegExp(r'galleryImages:\s*\[(.*?)\]', dotAll: true).firstMatch(tripContent);
    if (galleryMatch != null) {
      result['galleryImages'] = _parseStringArray(galleryMatch.group(1)!);
    } else {
      result['galleryImages'] = <String>[];
    }
    
    // Parse boardingLocations array
    final boardingMatch = RegExp(r'boardingLocations:\s*\[(.*?)\]\s*,?\s*(?:galleryImages:|groupSize:|$)', dotAll: true).firstMatch(tripContent);
    if (boardingMatch != null) {
      result['boardingLocations'] = _parseBoardingLocations(boardingMatch.group(1)!);
    } else {
      result['boardingLocations'] = <Map<String, dynamic>>[];
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
    
    // Parse featured as independent boolean field
    // First check for explicit featured: true/false in the data
    final featuredMatch = RegExp(r'featured:\s*(true|false)').firstMatch(tripContent);
    if (featuredMatch != null) {
      result['featured'] = featuredMatch.group(1) == 'true';
    } else {
      // Legacy fallback: derive from badge for data that doesn't have the field yet
      result['featured'] = result['badge'] == 'Featured' || result['badge'] == 'Popular';
    }
    
    // Parse isActive field (defaults to true if not present)
    final isActiveMatch = RegExp(r'isActive:\s*(true|false)').firstMatch(tripContent);
    if (isActiveMatch != null) {
      result['isActive'] = isActiveMatch.group(1) == 'true';
    } else {
      result['isActive'] = true; // Default to active
    }
    
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
      
      // Match day field - can be unquoted or quoted
      final dayMatch = RegExp(r'day:\s*"?([^",}]+)"?').firstMatch(dayStr);
      if (dayMatch != null) {
        item['day'] = dayMatch.group(1)?.trim();
      }
      
      // Match title with double quotes (allows apostrophes inside)
      final titleMatch = RegExp(r'title:\s*"([^"]*)"').firstMatch(dayStr);
      if (titleMatch != null) {
        item['title'] = titleMatch.group(1);
      }
      
      // Parse activities array within the day
      final activitiesMatch = RegExp(r'activities:\s*\[(.*?)\]', dotAll: true).firstMatch(dayStr);
      if (activitiesMatch != null) {
        item['activities'] = _parseStringArray(activitiesMatch.group(1)!);
        // Join activities into description
        item['description'] = (item['activities'] as List).join('\n');
      }
      
      if (item.isNotEmpty) {
        items.add(item);
      }
    }
    
    return items;
  }
  
  /// Parse boarding location items
  static List<Map<String, dynamic>> _parseBoardingLocations(String boardingStr) {
    final items = <Map<String, dynamic>>[];
    
    // Find each boarding location object
    final locationPattern = RegExp(r'\{[^{}]*name:[^{}]*\}', dotAll: true);
    final locationMatches = locationPattern.allMatches(boardingStr);
    
    for (final match in locationMatches) {
      final locStr = match.group(0)!;
      final item = <String, dynamic>{};
      
      // Use double-quote patterns to allow apostrophes in values
      final nameMatch = RegExp(r'name:\s*"([^"]*)"').firstMatch(locStr);
      if (nameMatch != null) {
        item['name'] = nameMatch.group(1);
      }
      
      final landmarkMatch = RegExp(r'landmark:\s*"([^"]*)"').firstMatch(locStr);
      if (landmarkMatch != null) {
        item['landmark'] = landmarkMatch.group(1);
      }
      
      final timeMatch = RegExp(r'time:\s*"([^"]*)"').firstMatch(locStr);
      if (timeMatch != null) {
        item['time'] = timeMatch.group(1);
      }
      
      final mapLinkMatch = RegExp(r'mapLink:\s*"([^"]*)"').firstMatch(locStr);
      if (mapLinkMatch != null) {
        item['mapLink'] = mapLinkMatch.group(1);
      }
      
      if (item.isNotEmpty) {
        items.add(item);
      }
    }
    
    return items;
  }
  
  /// Parse a string array that may contain apostrophes in double-quoted strings
  static List<String> _parseStringArray(String arrayContent) {
    final items = <String>[];
    // Match double-quoted strings, handling escaped quotes
    // Pattern matches: "content" where content can include apostrophes
    // We iterate manually to handle escaped quotes properly
    int i = 0;
    while (i < arrayContent.length) {
      // Find opening double quote
      final startQuote = arrayContent.indexOf('"', i);
      if (startQuote == -1) break;
      
      // Find closing double quote (not escaped)
      int endQuote = startQuote + 1;
      while (endQuote < arrayContent.length) {
        if (arrayContent[endQuote] == '"') {
          // Check if this quote is escaped
          int backslashCount = 0;
          int checkPos = endQuote - 1;
          while (checkPos >= startQuote + 1 && arrayContent[checkPos] == '\\') {
            backslashCount++;
            checkPos--;
          }
          // If even number of backslashes, this quote is not escaped
          if (backslashCount % 2 == 0) {
            break;
          }
        }
        endQuote++;
      }
      
      if (endQuote < arrayContent.length) {
        var value = arrayContent.substring(startQuote + 1, endQuote);
        // Unescape common escape sequences
        value = value
            .replaceAll(r'\"', '"')
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\r', '\r')
            .replaceAll(r'\t', '\t')
            .replaceAll(r'\\', '\\');
        if (value.isNotEmpty) {
          items.add(value);
        }
        i = endQuote + 1;
      } else {
        break;
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
    
    // Deduplicate: keep only the last occurrence of each trip ID (matching JS behavior)
    final seenIds = <String>{};
    final deduped = <Map<String, dynamic>>[];
    for (int i = trips.length - 1; i >= 0; i--) {
      final id = (trips[i]['id'] ?? 'trip_${i + 1}').toString();
      if (!seenIds.contains(id)) {
        seenIds.add(id);
        deduped.insert(0, trips[i]);
      }
    }
    
    for (int i = 0; i < deduped.length; i++) {
      final trip = deduped[i];
      final tripId = (trip['id'] ?? 'trip_${i + 1}').toString();
      
      final quotedId = tripId.contains("-") ? '"$tripId"' : tripId;
      buffer.writeln('    $quotedId: {');
      buffer.writeln('        title: "${_escapeJs((trip['title'] ?? trip['name'] ?? '').toString())}",');
      buffer.writeln('        location: "${_escapeJs((trip['location'] ?? trip['destination'] ?? '').toString())}",');
      buffer.writeln('        badge: "${_escapeJs((trip['badge'] ?? 'Trek').toString())}",');
      final isFeatured = trip['featured'] == true;
      buffer.writeln('        featured: $isFeatured,');
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
      
      // Things to Carry
      final thingsToCarry = trip['thingsToCarry'] as List<dynamic>? ?? [];
      buffer.writeln('        thingsToCarry: [${thingsToCarry.map((t) => '"${_escapeJs(t.toString())}"').join(', ')}],');
      
      // Boarding Locations
      final boardingLocations = trip['boardingLocations'] as List<dynamic>? ?? [];
      buffer.writeln('        boardingLocations: [');
      for (final loc in boardingLocations) {
        if (loc is Map) {
          buffer.writeln('            {name: "${_escapeJs(loc['name']?.toString() ?? '')}", landmark: "${_escapeJs(loc['landmark']?.toString() ?? '')}", time: "${_escapeJs(loc['time']?.toString() ?? '')}", mapLink: "${_escapeJs(loc['mapLink']?.toString() ?? '')}"},');
        }
      }
      buffer.writeln('        ],');
      
      // Gallery Images
      final galleryImages = trip['galleryImages'] as List<dynamic>? ?? [];
      buffer.writeln('        galleryImages: [${galleryImages.map((img) => '"${_escapeJs(img.toString())}"').join(', ')}],');
      
      // Group size first (to match original file order)
      buffer.writeln('        groupSize: "${_escapeJs((trip['groupSize'] ?? '').toString())}",');
      
      // Active status
      final isActive = trip['isActive'] ?? true;
      buffer.writeln('        isActive: $isActive,');
      buffer.writeln('    },');
    }
    
    buffer.writeln('};');
    buffer.writeln();
    buffer.writeln('// ============================================');
    buffer.writeln('// GET TRIP DATA FUNCTION');
    buffer.writeln('// ============================================');
    buffer.writeln('// Returns trip data by ID, defaults to first trip if not found');
    buffer.writeln('function getTripData(tripId) {');
    buffer.writeln('    return tripsData[tripId] || tripsData[Object.keys(tripsData)[0]];');
    buffer.writeln('}');
    buffer.writeln();
    
    // Add common data sections
    buffer.write(_getCommonDataSections());
    
    return buffer.toString();
  }
  
  /// Get common data sections (pickup points, cancellation policy, guidelines, FAQs)
  static String _getCommonDataSections() {
    return '''
// ============================================
// COMMON DATA - PICKUP POINTS
// ============================================
const commonPickupPoints = [
    {
        name: "Majestic",
        landmark: "Metro Station / Shantala Silks",
        time: "8:30 PM - 10:00 PM",
        mapLink: "https://maps.google.com/?q=Majestic+Metro+Station+Bangalore"
    },
    {
        name: "Koramangala",
        landmark: "Kota Kochari, Opp Forum Mall",
        time: "9:00 PM - 10:30 PM",
        mapLink: "https://maps.google.com/?q=Forum+Mall+Koramangala+Bangalore"
    },
    {
        name: "Silk Board",
        landmark: "Silk Board Junction",
        time: "9:15 PM - 10:45 PM",
        mapLink: "https://maps.google.com/?q=Silk+Board+Junction+Bangalore"
    },
    {
        name: "Electronic City",
        landmark: "Infosys Gate / Toll Plaza",
        time: "9:45 PM - 11:15 PM",
        mapLink: "https://maps.google.com/?q=Electronic+City+Infosys+Bangalore"
    }
];

// ============================================
// COMMON DATA - CANCELLATION POLICY (PTU Style - Shows Fee)
// ============================================
const commonCancellationPolicy = [
    {
        days: "7+ days before trip",
        refund: "50%",
        color: "#22c55e"  // Green - least penalty
    },
    {
        days: "3-6 days before trip",
        refund: "70%",
        color: "#f59e0b"  // Orange - medium penalty
    },
    {
        days: "0-2 days before trip",
        refund: "100%",
        color: "#ef4444"  // Red - full penalty (no refund)
    }
];

// ============================================
// COMMON DATA - TRIP GUIDELINES (PTU Style)
// ============================================
const commonGuidelines = [
    {
        icon: "fa-ban",
        title: "No Alcohol or Smoking",
        desc: "Consumption of alcohol and smoking is strictly prohibited during the trip. Violation may result in immediate termination without refund."
    },
    {
        icon: "fa-utensils",
        title: "Dinner Before Boarding",
        desc: "Please have your dinner before boarding the vehicle. We won't stop for dinner breaks during night journeys."
    },
    {
        icon: "fa-bus",
        title: "Travel Arrangements",
        desc: "We use Tempo Travellers or Mini-buses with push-back seats. AC will be on from 7 AM to 7 PM only. Night travel is non-AC."
    },
    {
        icon: "fa-mountain",
        title: "Embrace the Outdoors",
        desc: "This is an adventure trip, not a luxury vacation. Expect basic facilities, unpredictable weather, and some physical activity."
    },
    {
        icon: "fa-seedling",
        title: "Food (Vegetarian/Non-Vegetarian)",
        desc: "All meals provided during the trip are vegetarian/Non-veg based on the situation."
    },
    {
        icon: "fa-leaf",
        title: "Leave No Trace",
        desc: "Respect nature. Don't litter, don't pluck plants, and carry back all your waste. Let's keep our trails clean."
    },
    {
        icon: "fa-suitcase",
        title: "Personal Belongings",
        desc: "Team Weekend Trekkers is not responsible for loss or damage to personal belongings. Keep valuables secure at all times."
    },
    {
        icon: "fa-clock",
        title: "Potential Delays",
        desc: "Travel times are estimates. Traffic, weather, and unforeseen circumstances may cause delays. Please be patient and cooperative."
    }
];

// ============================================
// COMMON DATA - FAQs (PTU Style)
// ============================================
const commonFAQs = [
    {
        q: "How do I book a trip?",
        a: "You can book directly through our website by selecting your preferred date and number of travelers, then completing the payment. Alternatively, you can WhatsApp us at 7019235581 for assistance."
    },
    {
        q: "Is there a WhatsApp group for the trip?",
        a: "Yes! Once your booking is confirmed, you'll be added to a WhatsApp group with fellow travelers and the trip coordinator 2-3 days before the trip."
    },
    {
        q: "Is it safe for solo travelers?",
        a: "Absolutely! Most of our travelers are solo. Our groups are friendly and you'll make great friends. We maintain a balanced male-female ratio on most trips."
    },
    {
        q: "Is it safe for women travelers?",
        a: "Yes, women's safety is our top priority. We have female travelers on almost every trip, and our coordinators ensure a safe and comfortable environment for everyone."
    },
    {
        q: "Are there any discounts available?",
        a: "We offer group discounts for 4+ people booking together. Students and repeat travelers may also get special offers. Contact us on WhatsApp for current deals."
    },
    {
        q: "What should I pack for the trip?",
        a: "Pack light! Essentials include: comfortable clothes, good walking shoes, rain jacket/poncho, water bottle, power bank, personal medicines, toiletries, and a small backpack."
    },
    {
        q: "What is the luggage limit?",
        a: "One backpack (40-50L) per person. Avoid large suitcases as they're difficult to carry on treks and take up space in the vehicle."
    },
    {
        q: "Do I need to be super fit for treks?",
        a: "Basic fitness is required. If you can walk 5-10 km and climb stairs without getting exhausted, you're good! Check the difficulty level on each trip page."
    },
    {
        q: "What if I need to cancel my booking?",
        a: "You can cancel through WhatsApp. Cancellation fees apply: 50% fee (7+ days before), 70% fee (3-6 days before), 100% fee (0-2 days before). Refunds are processed within 5-7 business days."
    },
    {
        q: "What if the trip gets cancelled due to weather?",
        a: "If we cancel due to bad weather or unforeseen circumstances, you'll get a full refund or option to reschedule to another date. Your safety comes first!"
    }
];
''';
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

  /// Parse the featured-trips.js file to extract featured trip IDs
  static List<String> parseFeaturedTripIds(String jsContent) {
    final match = RegExp(r'const\s+featuredTripIds\s*=\s*\[(.*?)\]', dotAll: true)
        .firstMatch(jsContent);
    if (match == null) return [];

    final arrayContent = match.group(1)!;
    final ids = <String>[];
    for (final m in RegExp(r'"([^"]+)"').allMatches(arrayContent)) {
      ids.add(m.group(1)!);
    }
    return ids;
  }

  /// Generate the featured-trips.js file content from trip data
  static String generateFeaturedTripsJs(List<Map<String, dynamic>> trips) {
    final featuredIds = trips
        .where((t) => t['featured'] == true)
        .map((t) => t['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final buffer = StringBuffer();
    buffer.writeln('// ============================================');
    buffer.writeln('// FEATURED TRIPS CONFIGURATION');
    buffer.writeln('// ============================================');
    buffer.writeln('// ');
    buffer.writeln('// These trips will be displayed on the homepage');
    buffer.writeln('// in the "Upcoming Adventures" section.');
    buffer.writeln('// ');
    buffer.writeln('// Edit using Trip Manager → ⭐ Featured Trips');
    buffer.writeln('// Last updated: ${DateTime.now().toString().substring(0, 16)}');
    buffer.writeln('// ============================================');
    buffer.writeln();
    buffer.writeln('const featuredTripIds = [');
    for (final id in featuredIds) {
      buffer.writeln('    "$id",');
    }
    buffer.writeln('];');
    buffer.writeln();
    buffer.writeln('// Function to get featured trips data');
    buffer.writeln('function getFeaturedTrips() {');
    buffer.writeln('    return featuredTripIds.map(id => {');
    buffer.writeln('        const trip = tripsData[id];');
    buffer.writeln('        if (trip) {');
    buffer.writeln('            return { id, ...trip };');
    buffer.writeln('        }');
    buffer.writeln('        return null;');
    buffer.writeln('    }).filter(t => t !== null);');
    buffer.writeln('}');
    return buffer.toString();
  }
}
