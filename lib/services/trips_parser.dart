/// Parser for the trips-data.js JavaScript file
/// Handles object format: const tripsData = { tripId: {...}, tripId2: {...} }
class TripsParser {
  static const Set<String> _supportedSourceTripFields = {
    'title',
    'location',
    'badge',
    'featured',
    'price',
    'image',
    'distance',
    'elevation',
    'difficulty',
    'bestTime',
    'duration',
    'availableDates',
    'about',
    'highlights',
    'itinerary',
    'includes',
    'excludes',
    'thingsToCarry',
    'boardingLocations',
    'galleryImages',
    'groupSize',
    'isActive',
  };

  // These keys exist only in the app's editable representation. They are
  // aliases or derived values for fields in [_supportedSourceTripFields].
  static const Set<String> _supportedAppTripFields = {
    ..._supportedSourceTripFields,
    'id',
    'name',
    'destination',
    'description',
    'date',
    'priceNumeric',
    'inclusions',
    'exclusions',
    'discountedPrice',
    'pickupPoint',
  };

  /// Default pickup points used by the website when trip has no custom boardingLocations
  static List<Map<String, dynamic>> getDefaultPickupPoints() {
    return [
      {
        'name': 'Majestic',
        'landmark': 'Metro Station / Shantala Silks',
        'time': '8:30 PM - 10:00 PM',
        'mapLink':
            'https://maps.google.com/?q=Majestic+Metro+Station+Bangalore',
      },
      {
        'name': 'Koramangala',
        'landmark': 'Kota Kochari, Opp Forum Mall',
        'time': '9:00 PM - 10:30 PM',
        'mapLink':
            'https://maps.google.com/?q=Forum+Mall+Koramangala+Bangalore',
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
        'mapLink':
            'https://maps.google.com/?q=Electronic+City+Infosys+Bangalore',
      },
    ];
  }

  /// Parse the trips-data.js content into a list of trip maps
  static List<Map<String, dynamic>> parseTripsData(String jsContent) {
    final result = parseTripsDocument(jsContent);
    if (result.document == null) {
      // Retain the legacy behavior for the old, unsupported array layout. The
      // source-preserving publishing API intentionally accepts object layout
      // only, because it cannot safely rewrite an unknown schema.
      return _parseArrayFormat(jsContent);
    }
    return result.trips;
  }

  /// Inspect a website trips document without changing any source text.
  ///
  /// The returned document records the exact object span, allowing callers to
  /// replace only `const tripsData = { ... }` while retaining every byte before
  /// and after the object. Validation errors block [replaceTripsDataObject].
  static TripsDataDocumentResult parseTripsDocument(String jsContent) {
    final errors = <String>[];
    final declarations = _findConstInitializers(jsContent, 'tripsData', '{');
    if (declarations.isEmpty) {
      return const TripsDataDocumentResult(
        errors: ['Could not find a const tripsData object declaration.'],
      );
    }
    if (declarations.length > 1) {
      errors.add(
        'Found multiple const tripsData object declarations; publishing is unsafe.',
      );
    }

    final declaration = declarations.first;
    final objectEnd = _findMatchingDelimiter(
      jsContent,
      declaration.valueStart,
      '{',
      '}',
    );
    if (objectEnd == null) {
      return TripsDataDocumentResult(
        errors: [
          ...errors,
          'The const tripsData object is malformed or unterminated.',
        ],
      );
    }

    final entriesResult = _scanTripEntries(
      jsContent,
      declaration.valueStart,
      objectEnd,
    );
    errors.addAll(entriesResult.errors);

    final trips = <Map<String, dynamic>>[];
    final seenIds = <String>{};
    final duplicateIds = <String>{};
    final unsupportedFields = <String, Set<String>>{};

    for (final entry in entriesResult.entries) {
      if (!seenIds.add(entry.id)) {
        duplicateIds.add(entry.id);
      }

      final fieldResult = _scanObjectFields(
        jsContent,
        entry.objectStart,
        entry.objectEnd,
      );
      errors.addAll(fieldResult.errors.map((error) => '${entry.id}: $error'));
      final unsupported = fieldResult.fields
          .where((field) => !_supportedSourceTripFields.contains(field))
          .toSet();
      if (unsupported.isNotEmpty) {
        unsupportedFields[entry.id] = unsupported;
      }

      final tripContent = jsContent.substring(
        entry.objectStart,
        entry.objectEnd + 1,
      );
      try {
        final literal = _JsLiteralParser(tripContent).parseComplete();
        if (literal is! Map<String, dynamic>) {
          errors.add('Trip "${entry.id}" must be a JavaScript object literal.');
          trips.add({'id': entry.id});
          continue;
        }
        errors.addAll(_validateSourceTrip(entry.id, literal));
        trips.add(_toAppTrip(entry.id, literal));
      } on FormatException catch (error) {
        errors.add(
          'Trip "${entry.id}" has an unsupported value: ${error.message}',
        );
        trips.add({'id': entry.id});
      }
    }

    if (duplicateIds.isNotEmpty) {
      errors.add(
        'Duplicate trip IDs are not allowed: ${duplicateIds.toList()..sort()}.',
      );
    }
    for (final entry in unsupportedFields.entries) {
      final fields = entry.value.toList()..sort();
      errors.add(
        'Trip "${entry.key}" contains unsupported top-level fields: $fields.',
      );
    }

    final document = TripsDataDocument._(
      source: jsContent,
      objectStart: declaration.valueStart,
      objectEnd: objectEnd,
    );
    return TripsDataDocumentResult(
      document: document,
      trips: trips,
      errors: errors,
      duplicateIds: duplicateIds,
      unsupportedFields: unsupportedFields,
    );
  }

  static List<String> _validateSourceTrip(
    String tripId,
    Map<String, dynamic> source,
  ) {
    final errors = <String>[];
    const stringFields = {
      'title',
      'location',
      'badge',
      'price',
      'image',
      'distance',
      'elevation',
      'difficulty',
      'bestTime',
      'duration',
      'about',
      'groupSize',
    };
    const booleanFields = {'featured', 'isActive'};
    const stringListFields = {
      'availableDates',
      'highlights',
      'includes',
      'excludes',
      'thingsToCarry',
      'galleryImages',
    };

    for (final field in stringFields) {
      if (source.containsKey(field) && source[field] is! String) {
        errors.add('Trip "$tripId" field "$field" must be a string.');
      }
    }
    for (final field in booleanFields) {
      if (source.containsKey(field) && source[field] is! bool) {
        errors.add('Trip "$tripId" field "$field" must be true or false.');
      }
    }
    for (final field in stringListFields) {
      final value = source[field];
      if (value == null && !source.containsKey(field)) continue;
      if (value is! List || value.any((item) => item is! String)) {
        errors.add('Trip "$tripId" field "$field" must be a list of strings.');
      }
    }

    final itinerary = source['itinerary'];
    if (itinerary != null || source.containsKey('itinerary')) {
      if (itinerary is! List) {
        errors.add('Trip "$tripId" field "itinerary" must be a list.');
      } else {
        for (var index = 0; index < itinerary.length; index++) {
          final item = itinerary[index];
          if (item is! Map<String, dynamic>) {
            errors.add(
              'Trip "$tripId" itinerary item ${index + 1} must be an object.',
            );
            continue;
          }
          final unknown = item.keys.toSet().difference({
            'day',
            'title',
            'activities',
          });
          if (unknown.isNotEmpty) {
            final names = unknown.toList()..sort();
            errors.add(
              'Trip "$tripId" itinerary item ${index + 1} has unsupported fields: $names.',
            );
          }
          if (item['day'] is! String || item['title'] is! String) {
            errors.add(
              'Trip "$tripId" itinerary item ${index + 1} requires string day and title fields.',
            );
          }
          final activities = item['activities'];
          if (activities is! List ||
              activities.any((activity) => activity is! String)) {
            errors.add(
              'Trip "$tripId" itinerary item ${index + 1} activities must be a list of strings.',
            );
          }
        }
      }
    }

    final boarding = source['boardingLocations'];
    if (boarding != null || source.containsKey('boardingLocations')) {
      if (boarding is! List) {
        errors.add('Trip "$tripId" field "boardingLocations" must be a list.');
      } else {
        for (var index = 0; index < boarding.length; index++) {
          final item = boarding[index];
          if (item is! Map<String, dynamic>) {
            errors.add(
              'Trip "$tripId" boarding location ${index + 1} must be an object.',
            );
            continue;
          }
          final unknown = item.keys.toSet().difference({
            'name',
            'landmark',
            'time',
            'mapLink',
          });
          if (unknown.isNotEmpty) {
            final names = unknown.toList()..sort();
            errors.add(
              'Trip "$tripId" boarding location ${index + 1} has unsupported fields: $names.',
            );
          }
          for (final field in const ['name', 'landmark', 'time', 'mapLink']) {
            if (item[field] is! String) {
              errors.add(
                'Trip "$tripId" boarding location ${index + 1} field "$field" must be a string.',
              );
            }
          }
        }
      }
    }
    return errors;
  }

  static Map<String, dynamic> _toAppTrip(
    String tripId,
    Map<String, dynamic> source,
  ) {
    final result = <String, dynamic>{'id': tripId};
    const directlyRepresentedFields = {
      'title',
      'location',
      'badge',
      'price',
      'image',
      'distance',
      'elevation',
      'difficulty',
      'bestTime',
      'duration',
      'about',
      'highlights',
      'thingsToCarry',
      'galleryImages',
      'groupSize',
    };
    for (final field in directlyRepresentedFields) {
      if (source.containsKey(field)) result[field] = source[field];
    }

    if (source['title'] is String) result['name'] = source['title'];
    if (source['location'] is String) {
      result['destination'] = source['location'];
    }
    if (source['about'] is String) result['description'] = source['about'];

    final dates = source['availableDates'];
    if (dates is List) {
      result['availableDates'] = List<String>.from(dates.whereType<String>());
      if (result['availableDates'].isNotEmpty) {
        result['date'] = (result['availableDates'] as List<String>).first;
      }
    }

    final includes = source['includes'];
    if (includes is List) {
      result['inclusions'] = List<String>.from(includes.whereType<String>());
    }
    final excludes = source['excludes'];
    if (excludes is List) {
      result['exclusions'] = List<String>.from(excludes.whereType<String>());
    }

    final itinerary = source['itinerary'];
    if (itinerary is List) {
      result['itinerary'] = itinerary.whereType<Map<String, dynamic>>().map((
        item,
      ) {
        final copy = Map<String, dynamic>.from(item);
        final activities = copy['activities'];
        if (activities is List) copy['description'] = activities.join('\n');
        return copy;
      }).toList();
    }
    final boarding = source['boardingLocations'];
    if (boarding is List) {
      result['boardingLocations'] = boarding
          .whereType<Map<String, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList();
    }

    if (result['price'] != null) {
      final priceText = result['price'].toString().replaceAll(
        RegExp(r'[₹,\s]'),
        '',
      );
      result['priceNumeric'] = double.tryParse(priceText) ?? 0;
    }
    if (source['featured'] is bool) result['featured'] = source['featured'];
    if (source['isActive'] is bool) result['isActive'] = source['isActive'];
    return result;
  }

  /// Replace only the `tripsData` object in [source]. Prefix and suffix bytes,
  /// including comments, helper functions, and common data, are unchanged.
  static SourcePreservingWriteResult replaceTripsDataObject({
    required String source,
    required List<Map<String, dynamic>> trips,
  }) {
    final parsed = parseTripsDocument(source);
    if (!parsed.isValid || parsed.document == null) {
      return SourcePreservingWriteResult.failure(parsed.errors);
    }

    final inputErrors = _validateAppTrips(trips);
    if (inputErrors.isNotEmpty) {
      return SourcePreservingWriteResult.failure(inputErrors);
    }

    late final String generated;
    try {
      generated = generateTripsDataJs(trips);
    } on FormatException catch (error) {
      return SourcePreservingWriteResult.failure([
        'Internal error: generated trips data is invalid: ${error.message}',
      ]);
    }
    final generatedResult = parseTripsDocument(generated);
    final generatedDocument = generatedResult.document;
    if (!generatedResult.isValid || generatedDocument == null) {
      return SourcePreservingWriteResult.failure([
        'Internal error: generated trips data is invalid.',
        ...generatedResult.errors,
      ]);
    }
    final objectText = generated.substring(
      generatedDocument.objectStart,
      generatedDocument.objectEnd + 1,
    );
    final rewritten = parsed.document!.replaceValue(objectText);
    final reparsed = parseTripsDocument(rewritten);
    if (!reparsed.isValid || reparsed.document == null) {
      return SourcePreservingWriteResult.failure([
        'Internal error: rewritten trips document failed validation.',
        ...reparsed.errors,
      ]);
    }
    if (reparsed.document!.prefix != parsed.document!.prefix ||
        reparsed.document!.suffix != parsed.document!.suffix) {
      return const SourcePreservingWriteResult.failure([
        'Internal error: source outside the tripsData object changed.',
      ]);
    }
    return SourcePreservingWriteResult.success(rewritten);
  }

  /// Parse array format as fallback
  static List<Map<String, dynamic>> _parseArrayFormat(String jsContent) {
    final trips = <Map<String, dynamic>>[];
    final startMatch = RegExp(
      r'const\s+tripsData\s*=\s*\[',
    ).firstMatch(jsContent);
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

  /// Generate trips-data.js content from trip maps (maintains object format)
  static String generateTripsDataJs(List<Map<String, dynamic>> trips) {
    final validationErrors = _validateAppTrips(trips);
    if (validationErrors.isNotEmpty) {
      throw FormatException(validationErrors.join('\n'));
    }

    final buffer = StringBuffer();
    buffer.writeln('// ============================================');
    buffer.writeln('// TEAM WEEKEND TREKKERS - TRIP DATABASE');
    buffer.writeln('// ============================================');
    buffer.writeln('// ');
    buffer.writeln(
      '// Last updated: ${DateTime.now().toString().substring(0, 16)}',
    );
    buffer.writeln('// Updated via Trip Manager Mobile App');
    buffer.writeln('// ============================================');
    buffer.writeln();
    buffer.writeln('const tripsData = {');

    for (int i = 0; i < trips.length; i++) {
      final trip = trips[i];
      final tripId = trip['id'].toString();

      final quotedId = RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(tripId)
          ? tripId
          : '"${_escapeJs(tripId)}"';
      buffer.writeln('    $quotedId: {');

      void writeStringField(String sourceField, List<String> appFields) {
        final appField = _firstPresentKey(trip, appFields);
        if (appField == null) return;
        buffer.writeln(
          '        $sourceField: "${_escapeJs(trip[appField].toString())}",',
        );
      }

      void writeStringListField(String sourceField, List<String> appFields) {
        final appField = _firstPresentKey(trip, appFields);
        if (appField == null) return;
        final values = trip[appField] as List<dynamic>;
        buffer.writeln(
          '        $sourceField: [${values.map((value) => '"${_escapeJs(value as String)}"').join(', ')}],',
        );
      }

      writeStringField('title', const ['title', 'name']);
      writeStringField('location', const ['location', 'destination']);
      writeStringField('badge', const ['badge']);
      if (trip.containsKey('featured')) {
        buffer.writeln('        featured: ${trip['featured']},');
      }
      writeStringField('price', const ['price']);
      writeStringField('image', const ['image']);
      writeStringField('distance', const ['distance']);
      writeStringField('elevation', const ['elevation']);
      writeStringField('difficulty', const ['difficulty']);
      writeStringField('bestTime', const ['bestTime']);
      writeStringField('duration', const ['duration']);
      writeStringListField('availableDates', const ['availableDates']);
      writeStringField('about', const ['about', 'description']);
      writeStringListField('highlights', const ['highlights']);

      if (trip.containsKey('itinerary')) {
        final itinerary = trip['itinerary'] as List<dynamic>;
        buffer.writeln('        itinerary: [');
        for (final rawDay in itinerary) {
          final day = rawDay as Map;
          final activities = day.containsKey('activities')
              ? day['activities'] as List<dynamic>
              : _activitiesFromDescription(day['description'] as String);
          buffer.writeln(
            '            {day: "${_escapeJs(day['day'].toString())}", title: "${_escapeJs(day['title'] as String)}", activities: [${activities.map((activity) => '"${_escapeJs(activity as String)}"').join(', ')}]},',
          );
        }
        buffer.writeln('        ],');
      }

      writeStringListField('includes', const ['inclusions', 'includes']);
      writeStringListField('excludes', const ['exclusions', 'excludes']);
      writeStringListField('thingsToCarry', const ['thingsToCarry']);

      if (trip.containsKey('boardingLocations')) {
        final boardingLocations = trip['boardingLocations'] as List<dynamic>;
        buffer.writeln('        boardingLocations: [');
        for (final rawLocation in boardingLocations) {
          final location = rawLocation as Map;
          buffer.writeln(
            '            {name: "${_escapeJs(location['name'] as String)}", landmark: "${_escapeJs(location['landmark'] as String)}", time: "${_escapeJs(location['time'] as String)}", mapLink: "${_escapeJs(location['mapLink'] as String)}"},',
          );
        }
        buffer.writeln('        ],');
      }

      writeStringListField('galleryImages', const ['galleryImages']);
      writeStringField('groupSize', const ['groupSize']);
      if (trip.containsKey('isActive')) {
        buffer.writeln('        isActive: ${trip['isActive']},');
      }
      buffer.writeln('    },');
    }

    buffer.writeln('};');
    buffer.writeln();
    buffer.writeln('// ============================================');
    buffer.writeln('// GET TRIP DATA FUNCTION');
    buffer.writeln('// ============================================');
    buffer.writeln(
      '// Returns trip data by ID, defaults to first trip if not found',
    );
    buffer.writeln('function getTripData(tripId) {');
    buffer.writeln(
      '    return tripsData[tripId] || tripsData[Object.keys(tripsData)[0]];',
    );
    buffer.writeln('}');
    buffer.writeln();

    // Add common data sections
    buffer.write(_getCommonDataSections());

    final generated = buffer.toString();
    final generatedResult = parseTripsDocument(generated);
    if (!generatedResult.isValid) {
      throw FormatException(
        'Generated trips document failed validation:\n'
        '${generatedResult.errors.join('\n')}',
      );
    }
    return generated;
  }

  static String? _firstPresentKey(
    Map<String, dynamic> trip,
    List<String> candidates,
  ) {
    for (final candidate in candidates) {
      if (trip.containsKey(candidate)) return candidate;
    }
    return null;
  }

  static List<dynamic> _activitiesFromDescription(String description) =>
      description.isEmpty ? <dynamic>[] : description.split('\n');

  static List<String> _validateAppTrips(List<Map<String, dynamic>> trips) {
    final errors = <String>[];
    final seenIds = <String>{};
    final duplicateIds = <String>{};

    const stringFields = {
      'title',
      'name',
      'location',
      'destination',
      'badge',
      'image',
      'distance',
      'elevation',
      'difficulty',
      'bestTime',
      'duration',
      'about',
      'description',
      'date',
      'pickupPoint',
    };
    const stringOrNumberFields = {'price', 'groupSize'};
    const numberFields = {'priceNumeric', 'discountedPrice'};
    const booleanFields = {'featured', 'isActive'};
    const stringListFields = {
      'availableDates',
      'highlights',
      'includes',
      'inclusions',
      'excludes',
      'exclusions',
      'thingsToCarry',
      'galleryImages',
    };

    for (var index = 0; index < trips.length; index++) {
      final trip = trips[index];
      final rawId = trip['id'];
      final id = rawId is String ? rawId : '';
      final label = id.isEmpty ? 'at position ${index + 1}' : '"$id"';
      if (rawId is! String) {
        errors.add(
          'Trip at position ${index + 1} field "id" must be a string.',
        );
      } else if (id.trim().isEmpty) {
        errors.add('Trip at position ${index + 1} has no ID.');
      } else if (!seenIds.add(id)) {
        duplicateIds.add(id);
      }

      final unsupported =
          trip.keys
              .where((key) => !_supportedAppTripFields.contains(key))
              .toList()
            ..sort();
      if (unsupported.isNotEmpty) {
        errors.add(
          'Trip "${id.isEmpty ? index + 1 : id}" contains unsupported app fields: $unsupported.',
        );
      }

      for (final field in stringFields) {
        if (trip.containsKey(field) && trip[field] is! String) {
          errors.add('Trip $label field "$field" must be a string.');
        }
      }
      for (final field in stringOrNumberFields) {
        final value = trip[field];
        if (trip.containsKey(field) && value is! String && value is! num) {
          errors.add('Trip $label field "$field" must be a string or number.');
        }
      }
      for (final field in numberFields) {
        if (trip.containsKey(field) && trip[field] is! num) {
          errors.add('Trip $label field "$field" must be a number.');
        }
      }
      for (final field in booleanFields) {
        if (trip.containsKey(field) && trip[field] is! bool) {
          errors.add('Trip $label field "$field" must be true or false.');
        }
      }
      for (final field in stringListFields) {
        if (!trip.containsKey(field)) continue;
        final value = trip[field];
        if (value is! List || value.any((item) => item is! String)) {
          errors.add('Trip $label field "$field" must be a list of strings.');
        }
      }

      if (trip.containsKey('itinerary')) {
        final itinerary = trip['itinerary'];
        if (itinerary is! List) {
          errors.add('Trip $label field "itinerary" must be a list.');
        } else {
          for (var itemIndex = 0; itemIndex < itinerary.length; itemIndex++) {
            final item = itinerary[itemIndex];
            final itemLabel = 'Trip $label itinerary item ${itemIndex + 1}';
            if (item is! Map) {
              errors.add('$itemLabel must be an object.');
              continue;
            }
            final nonStringKeys = item.keys
                .where((key) => key is! String)
                .toList();
            if (nonStringKeys.isNotEmpty) {
              errors.add('$itemLabel may contain only string field names.');
            }
            final unknown =
                item.keys
                    .whereType<String>()
                    .where(
                      (field) => !const {
                        'day',
                        'title',
                        'activities',
                        'description',
                      }.contains(field),
                    )
                    .toList()
                  ..sort();
            if (unknown.isNotEmpty) {
              errors.add('$itemLabel has unsupported fields: $unknown.');
            }
            final day = item['day'];
            if (!item.containsKey('day') || (day is! String && day is! num)) {
              errors.add('$itemLabel field "day" must be a string or number.');
            }
            if (!item.containsKey('title') || item['title'] is! String) {
              errors.add('$itemLabel field "title" must be a string.');
            }
            final hasActivities = item.containsKey('activities');
            final hasDescription = item.containsKey('description');
            if (!hasActivities && !hasDescription) {
              errors.add('$itemLabel requires "activities" or "description".');
            }
            if (hasActivities) {
              final activities = item['activities'];
              if (activities is! List ||
                  activities.any((activity) => activity is! String)) {
                errors.add(
                  '$itemLabel field "activities" must be a list of strings.',
                );
              }
            }
            if (hasDescription && item['description'] is! String) {
              errors.add('$itemLabel field "description" must be a string.');
            }
          }
        }
      }

      if (trip.containsKey('boardingLocations')) {
        final boarding = trip['boardingLocations'];
        if (boarding is! List) {
          errors.add('Trip $label field "boardingLocations" must be a list.');
        } else {
          for (var itemIndex = 0; itemIndex < boarding.length; itemIndex++) {
            final item = boarding[itemIndex];
            final itemLabel = 'Trip $label boarding location ${itemIndex + 1}';
            if (item is! Map) {
              errors.add('$itemLabel must be an object.');
              continue;
            }
            final nonStringKeys = item.keys
                .where((key) => key is! String)
                .toList();
            if (nonStringKeys.isNotEmpty) {
              errors.add('$itemLabel may contain only string field names.');
            }
            final unknown =
                item.keys
                    .whereType<String>()
                    .where(
                      (field) => !const {
                        'name',
                        'landmark',
                        'time',
                        'mapLink',
                      }.contains(field),
                    )
                    .toList()
                  ..sort();
            if (unknown.isNotEmpty) {
              errors.add('$itemLabel has unsupported fields: $unknown.');
            }
            for (final field in const ['name', 'landmark', 'time', 'mapLink']) {
              if (!item.containsKey(field) || item[field] is! String) {
                errors.add('$itemLabel field "$field" must be a string.');
              }
            }
          }
        }
      }
    }

    if (duplicateIds.isNotEmpty) {
      errors.add(
        'Duplicate trip IDs are not allowed: ${duplicateIds.toList()..sort()}.',
      );
    }
    return errors;
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
    final escaped = StringBuffer();
    for (final codeUnit in str.codeUnits) {
      switch (codeUnit) {
        case 0x5c:
          escaped.write(r'\\');
        case 0x22:
          escaped.write(r'\"');
        case 0x0a:
          escaped.write(r'\n');
        case 0x0d:
          escaped.write(r'\r');
        case 0x09:
          escaped.write(r'\t');
        case 0x2028:
          escaped.write(r'\u2028');
        case 0x2029:
          escaped.write(r'\u2029');
        default:
          if (codeUnit >= 0xd800 && codeUnit <= 0xdfff) {
            escaped
              ..write(r'\u')
              ..write(codeUnit.toRadixString(16).padLeft(4, '0').toUpperCase());
          } else {
            escaped.writeCharCode(codeUnit);
          }
      }
    }
    return escaped.toString();
  }

  /// Parse the featured-trips.js file to extract featured trip IDs
  static List<String> parseFeaturedTripIds(String jsContent) {
    return parseFeaturedTripsDocument(jsContent).ids;
  }

  /// Inspect `featured-trips.js` and retain the exact array source span.
  static FeaturedTripsDocumentResult parseFeaturedTripsDocument(
    String jsContent,
  ) {
    final errors = <String>[];
    final declarations = _findConstInitializers(
      jsContent,
      'featuredTripIds',
      '[',
    );
    if (declarations.isEmpty) {
      return const FeaturedTripsDocumentResult(
        errors: ['Could not find a const featuredTripIds array declaration.'],
      );
    }
    if (declarations.length > 1) {
      errors.add(
        'Found multiple const featuredTripIds declarations; publishing is unsafe.',
      );
    }

    final declaration = declarations.first;
    final arrayEnd = _findMatchingDelimiter(
      jsContent,
      declaration.valueStart,
      '[',
      ']',
    );
    if (arrayEnd == null) {
      return FeaturedTripsDocumentResult(
        errors: [
          ...errors,
          'The const featuredTripIds array is malformed or unterminated.',
        ],
      );
    }

    final idsResult = _scanStringArray(
      jsContent,
      declaration.valueStart,
      arrayEnd,
    );
    errors.addAll(idsResult.errors);
    final duplicateIds = <String>{};
    final seenIds = <String>{};
    for (final id in idsResult.values) {
      if (!seenIds.add(id)) duplicateIds.add(id);
    }
    if (duplicateIds.isNotEmpty) {
      errors.add(
        'Duplicate featured trip IDs are not allowed: ${duplicateIds.toList()..sort()}.',
      );
    }

    return FeaturedTripsDocumentResult(
      document: FeaturedTripsDocument._(
        source: jsContent,
        arrayStart: declaration.valueStart,
        arrayEnd: arrayEnd,
      ),
      ids: idsResult.values,
      errors: errors,
      duplicateIds: duplicateIds,
    );
  }

  /// Replace only the `featuredTripIds` array and preserve all surrounding
  /// source byte-for-byte.
  static SourcePreservingWriteResult replaceFeaturedTripIdsArray({
    required String source,
    required List<String> ids,
  }) {
    final parsed = parseFeaturedTripsDocument(source);
    if (!parsed.isValid || parsed.document == null) {
      return SourcePreservingWriteResult.failure(parsed.errors);
    }

    final errors = <String>[];
    final seenIds = <String>{};
    final duplicateIds = <String>{};
    for (var index = 0; index < ids.length; index++) {
      final id = ids[index];
      if (id.trim().isEmpty) {
        errors.add('Featured trip ID at position ${index + 1} is empty.');
      } else if (!seenIds.add(id)) {
        duplicateIds.add(id);
      }
    }
    if (duplicateIds.isNotEmpty) {
      errors.add(
        'Duplicate featured trip IDs are not allowed: ${duplicateIds.toList()..sort()}.',
      );
    }
    if (errors.isNotEmpty) {
      return SourcePreservingWriteResult.failure(errors);
    }

    final newline = source.contains('\r\n') ? '\r\n' : '\n';
    final buffer = StringBuffer('[');
    if (ids.isNotEmpty) {
      buffer.write(newline);
      for (final id in ids) {
        buffer.write('    "${_escapeJs(id)}",$newline');
      }
    } else {
      buffer.write(newline);
    }
    buffer.write(']');
    final rewritten = parsed.document!.replaceValue(buffer.toString());
    final reparsed = parseFeaturedTripsDocument(rewritten);
    if (!reparsed.isValid || reparsed.document == null) {
      return SourcePreservingWriteResult.failure([
        'Internal error: rewritten featured trips document failed validation.',
        ...reparsed.errors,
      ]);
    }
    if (reparsed.document!.prefix != parsed.document!.prefix ||
        reparsed.document!.suffix != parsed.document!.suffix) {
      return const SourcePreservingWriteResult.failure([
        'Internal error: source outside the featuredTripIds array changed.',
      ]);
    }
    if (!_sameStrings(reparsed.ids, ids)) {
      return const SourcePreservingWriteResult.failure([
        'Internal error: rewritten featured trip IDs changed value.',
      ]);
    }
    return SourcePreservingWriteResult.success(rewritten);
  }

  /// Generate the featured-trips.js file content from trip data
  static String generateFeaturedTripsJs(List<Map<String, dynamic>> trips) {
    final validationErrors = _validateAppTrips(trips);
    if (validationErrors.isNotEmpty) {
      throw FormatException(validationErrors.join('\n'));
    }
    final featuredIds = trips
        .where((t) => t['featured'] == true)
        .map((t) => t['id'] as String)
        .toList();

    final seenIds = <String>{};
    final duplicateIds = featuredIds.where((id) => !seenIds.add(id)).toSet();
    if (duplicateIds.isNotEmpty) {
      throw FormatException(
        'Duplicate featured trip IDs are not allowed: ${duplicateIds.toList()..sort()}.',
      );
    }

    final buffer = StringBuffer();
    buffer.writeln('// ============================================');
    buffer.writeln('// FEATURED TRIPS CONFIGURATION');
    buffer.writeln('// ============================================');
    buffer.writeln('// ');
    buffer.writeln('// These trips will be displayed on the homepage');
    buffer.writeln('// in the "Upcoming Adventures" section.');
    buffer.writeln('// ');
    buffer.writeln('// Edit using Trip Manager → ⭐ Featured Trips');
    buffer.writeln(
      '// Last updated: ${DateTime.now().toString().substring(0, 16)}',
    );
    buffer.writeln('// ============================================');
    buffer.writeln();
    buffer.writeln('const featuredTripIds = [');
    for (final id in featuredIds) {
      buffer.writeln('    "${_escapeJs(id)}",');
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
    final generated = buffer.toString();
    final parsed = parseFeaturedTripsDocument(generated);
    if (!parsed.isValid || !_sameStrings(parsed.ids, featuredIds)) {
      throw FormatException(
        'Generated featured trips document failed validation:\n'
        '${parsed.errors.join('\n')}',
      );
    }
    return generated;
  }

  static bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

/// Result of inspecting the source-preserving `tripsData` document.
class TripsDataDocumentResult {
  final TripsDataDocument? document;
  final List<Map<String, dynamic>> trips;
  final List<String> errors;
  final Set<String> duplicateIds;
  final Map<String, Set<String>> unsupportedFields;

  const TripsDataDocumentResult({
    this.document,
    this.trips = const [],
    this.errors = const [],
    this.duplicateIds = const {},
    this.unsupportedFields = const {},
  });

  bool get isValid => document != null && errors.isEmpty;
}

/// Exact source span for the `tripsData` object (including its braces).
class TripsDataDocument {
  final String source;
  final int objectStart;
  final int objectEnd;

  const TripsDataDocument._({
    required this.source,
    required this.objectStart,
    required this.objectEnd,
  });

  String get prefix => source.substring(0, objectStart);
  String get suffix => source.substring(objectEnd + 1);
  String get objectSource => source.substring(objectStart, objectEnd + 1);

  String replaceValue(String replacement) => '$prefix$replacement$suffix';
}

/// Result of inspecting the source-preserving `featuredTripIds` document.
class FeaturedTripsDocumentResult {
  final FeaturedTripsDocument? document;
  final List<String> ids;
  final List<String> errors;
  final Set<String> duplicateIds;

  const FeaturedTripsDocumentResult({
    this.document,
    this.ids = const [],
    this.errors = const [],
    this.duplicateIds = const {},
  });

  bool get isValid => document != null && errors.isEmpty;
}

/// Exact source span for the `featuredTripIds` array (including brackets).
class FeaturedTripsDocument {
  final String source;
  final int arrayStart;
  final int arrayEnd;

  const FeaturedTripsDocument._({
    required this.source,
    required this.arrayStart,
    required this.arrayEnd,
  });

  String get prefix => source.substring(0, arrayStart);
  String get suffix => source.substring(arrayEnd + 1);
  String get arraySource => source.substring(arrayStart, arrayEnd + 1);

  String replaceValue(String replacement) => '$prefix$replacement$suffix';
}

/// A publication-safe source rewrite. A failed result never contains content.
class SourcePreservingWriteResult {
  final bool success;
  final String? content;
  final List<String> errors;

  const SourcePreservingWriteResult.success(String value)
    : success = true,
      content = value,
      errors = const [];

  const SourcePreservingWriteResult.failure(List<String> failureErrors)
    : success = false,
      content = null,
      errors = failureErrors;

  String? get error => errors.isEmpty ? null : errors.join('\n');
}

class _ConstInitializer {
  final int valueStart;

  const _ConstInitializer(this.valueStart);
}

class _TripSourceEntry {
  final String id;
  final int objectStart;
  final int objectEnd;

  const _TripSourceEntry({
    required this.id,
    required this.objectStart,
    required this.objectEnd,
  });
}

class _TripEntriesScanResult {
  final List<_TripSourceEntry> entries;
  final List<String> errors;

  const _TripEntriesScanResult(this.entries, this.errors);
}

class _ObjectFieldsScanResult {
  final Set<String> fields;
  final List<String> errors;

  const _ObjectFieldsScanResult(this.fields, this.errors);
}

class _StringArrayScanResult {
  final List<String> values;
  final List<String> errors;

  const _StringArrayScanResult(this.values, this.errors);
}

class _ParsedToken {
  final String value;
  final int end;

  const _ParsedToken(this.value, this.end);
}

/// A deliberately small JavaScript-literal reader for the managed document.
///
/// The website data is made only from object/array/string/number/boolean/null
/// literals. Expressions, template strings and identifiers are rejected so a
/// future website schema cannot be accepted and then silently regenerated as
/// different data.
class _JsLiteralParser {
  final String source;
  var _cursor = 0;

  _JsLiteralParser(this.source);

  dynamic parseComplete() {
    final value = _parseValue();
    _skipSpaceAndComments();
    if (_cursor != source.length) {
      throw FormatException('unexpected token at offset $_cursor.');
    }
    return value;
  }

  dynamic _parseValue() {
    _skipSpaceAndComments();
    if (_cursor >= source.length) {
      throw const FormatException('expected a value, but reached the end.');
    }
    final char = source[_cursor];
    if (char == '{') return _parseObject();
    if (char == '[') return _parseArray();
    if (char == '"' || char == "'") {
      final token = _readStringLiteral(source, _cursor);
      if (token == null) {
        throw FormatException('unterminated string at offset $_cursor.');
      }
      _cursor = token.end;
      return token.value;
    }
    if (_consumeWord('true')) return true;
    if (_consumeWord('false')) return false;
    if (_consumeWord('null')) return null;
    if (char == '-' || _isDigit(source.codeUnitAt(_cursor))) {
      return _parseNumber();
    }
    throw FormatException(
      'only literal values are supported (offset $_cursor).',
    );
  }

  Map<String, dynamic> _parseObject() {
    _cursor++;
    final result = <String, dynamic>{};
    _skipSpaceAndComments();
    if (_consumeChar('}')) return result;

    while (true) {
      _skipSpaceAndComments();
      final key = _readPropertyKey(source, _cursor);
      if (key == null) {
        throw FormatException('invalid object key at offset $_cursor.');
      }
      if (result.containsKey(key.value)) {
        throw FormatException('duplicate object field "${key.value}".');
      }
      _cursor = key.end;
      _skipSpaceAndComments();
      if (!_consumeChar(':')) {
        throw FormatException(
          'object field "${key.value}" is missing a colon.',
        );
      }
      result[key.value] = _parseValue();
      _skipSpaceAndComments();
      if (_consumeChar('}')) return result;
      if (!_consumeChar(',')) {
        throw FormatException(
          'object field "${key.value}" is missing a comma.',
        );
      }
      _skipSpaceAndComments();
      if (_consumeChar('}')) return result;
    }
  }

  List<dynamic> _parseArray() {
    _cursor++;
    final result = <dynamic>[];
    _skipSpaceAndComments();
    if (_consumeChar(']')) return result;

    while (true) {
      result.add(_parseValue());
      _skipSpaceAndComments();
      if (_consumeChar(']')) return result;
      if (!_consumeChar(',')) {
        throw FormatException(
          'array item is missing a comma at offset $_cursor.',
        );
      }
      _skipSpaceAndComments();
      if (_consumeChar(']')) return result;
    }
  }

  num _parseNumber() {
    final remainder = source.substring(_cursor);
    final match = RegExp(
      r'^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?',
    ).firstMatch(remainder);
    if (match == null) {
      throw FormatException('invalid number at offset $_cursor.');
    }
    final token = match.group(0)!;
    _cursor += token.length;
    final integer = int.tryParse(token);
    return integer ?? double.parse(token);
  }

  bool _consumeWord(String word) {
    if (!source.startsWith(word, _cursor)) return false;
    final end = _cursor + word.length;
    if (end < source.length && _isIdentifierPart(source.codeUnitAt(end))) {
      return false;
    }
    _cursor = end;
    return true;
  }

  bool _consumeChar(String char) {
    if (_cursor >= source.length || source[_cursor] != char) return false;
    _cursor++;
    return true;
  }

  void _skipSpaceAndComments() {
    while (_cursor < source.length) {
      if (_isWhitespace(source.codeUnitAt(_cursor))) {
        _cursor++;
        continue;
      }
      if (source.startsWith('//', _cursor)) {
        final newline = source.indexOf('\n', _cursor + 2);
        _cursor = newline == -1 ? source.length : newline + 1;
        continue;
      }
      if (source.startsWith('/*', _cursor)) {
        final end = source.indexOf('*/', _cursor + 2);
        if (end == -1) {
          throw FormatException(
            'unterminated block comment at offset $_cursor.',
          );
        }
        _cursor = end + 2;
        continue;
      }
      return;
    }
  }
}

List<_ConstInitializer> _findConstInitializers(
  String source,
  String variableName,
  String openingDelimiter,
) {
  final results = <_ConstInitializer>[];
  var cursor = 0;
  while (cursor < source.length) {
    final ignoredEnd = _skipIgnored(source, cursor);
    if (ignoredEnd != cursor) {
      cursor = ignoredEnd;
      continue;
    }
    if (!_isIdentifierStart(source.codeUnitAt(cursor))) {
      cursor++;
      continue;
    }

    final wordStart = cursor;
    final wordEnd = _readIdentifierEnd(source, cursor);
    final word = source.substring(cursor, wordEnd);
    cursor = wordEnd;
    if (word != 'const' || !_isManagedDeclarationContext(source, wordStart)) {
      continue;
    }

    var candidate = _skipTrivia(source, cursor);
    if (candidate >= source.length ||
        !_isIdentifierStart(source.codeUnitAt(candidate))) {
      continue;
    }
    final nameEnd = _readIdentifierEnd(source, candidate);
    if (source.substring(candidate, nameEnd) != variableName) continue;

    candidate = _skipTrivia(source, nameEnd);
    if (candidate >= source.length || source[candidate] != '=') continue;
    candidate = _skipTrivia(source, candidate + 1);
    if (candidate < source.length && source[candidate] == openingDelimiter) {
      results.add(_ConstInitializer(candidate));
    }
  }
  return results;
}

bool _isManagedDeclarationContext(String source, int declarationStart) {
  // Both managed website files use a root declaration on its own line. This
  // deliberately narrow context is a publication safety boundary: it rejects
  // declaration-shaped text inside regular-expression literals (which cannot
  // contain a raw line terminator) without attempting to reimplement the full
  // context-sensitive JavaScript lexer. Leading whitespace and a block comment
  // on the declaration line remain supported.
  var lineStart = declarationStart;
  while (lineStart > 0 && !_isJavaScriptLineTerminator(source[lineStart - 1])) {
    lineStart--;
  }
  return _skipTrivia(source, lineStart) == declarationStart;
}

int? _findMatchingDelimiter(
  String source,
  int start,
  String openingDelimiter,
  String closingDelimiter,
) {
  if (start < 0 ||
      start >= source.length ||
      source[start] != openingDelimiter) {
    return null;
  }

  var depth = 0;
  var cursor = start;
  while (cursor < source.length) {
    final ignoredEnd = _skipIgnored(source, cursor);
    if (ignoredEnd != cursor) {
      cursor = ignoredEnd;
      continue;
    }
    final char = source[cursor];
    if (char == openingDelimiter) depth++;
    if (char == closingDelimiter) {
      depth--;
      if (depth == 0) return cursor;
      if (depth < 0) return null;
    }
    cursor++;
  }
  return null;
}

_TripEntriesScanResult _scanTripEntries(
  String source,
  int objectStart,
  int objectEnd,
) {
  final entries = <_TripSourceEntry>[];
  final errors = <String>[];
  var cursor = _skipTrivia(source, objectStart + 1);

  while (cursor < objectEnd) {
    final key = _readPropertyKey(source, cursor);
    if (key == null) {
      errors.add('Malformed trip key near source offset $cursor.');
      break;
    }
    cursor = _skipTrivia(source, key.end);
    if (cursor >= objectEnd || source[cursor] != ':') {
      errors.add('Trip "${key.value}" is missing a colon.');
      break;
    }
    cursor = _skipTrivia(source, cursor + 1);
    if (cursor >= objectEnd || source[cursor] != '{') {
      errors.add('Trip "${key.value}" must be a JavaScript object.');
      break;
    }
    final tripEnd = _findMatchingDelimiter(source, cursor, '{', '}');
    if (tripEnd == null || tripEnd > objectEnd) {
      errors.add('Trip "${key.value}" has a malformed or unterminated object.');
      break;
    }
    entries.add(
      _TripSourceEntry(id: key.value, objectStart: cursor, objectEnd: tripEnd),
    );

    cursor = _skipTrivia(source, tripEnd + 1);
    if (cursor == objectEnd) break;
    if (source[cursor] != ',') {
      errors.add('Trip "${key.value}" must be followed by a comma.');
      break;
    }
    cursor = _skipTrivia(source, cursor + 1);
    // A final trailing comma is valid JavaScript.
    if (cursor == objectEnd) break;
  }

  return _TripEntriesScanResult(entries, errors);
}

_ObjectFieldsScanResult _scanObjectFields(
  String source,
  int objectStart,
  int objectEnd,
) {
  final fields = <String>{};
  final errors = <String>[];
  var cursor = _skipTrivia(source, objectStart + 1);

  while (cursor < objectEnd) {
    final key = _readPropertyKey(source, cursor);
    if (key == null) {
      errors.add('Malformed field near source offset $cursor.');
      break;
    }
    if (!fields.add(key.value)) {
      errors.add('Duplicate top-level field "${key.value}".');
    }
    cursor = _skipTrivia(source, key.end);
    if (cursor >= objectEnd || source[cursor] != ':') {
      errors.add('Field "${key.value}" is missing a colon.');
      break;
    }
    cursor = _skipTrivia(source, cursor + 1);
    final valueEnd = _findTopLevelValueEnd(source, cursor, objectEnd);
    if (valueEnd == null || valueEnd == cursor) {
      errors.add('Field "${key.value}" has a malformed value.');
      break;
    }

    cursor = _skipTrivia(source, valueEnd);
    if (cursor == objectEnd) break;
    if (source[cursor] != ',') {
      errors.add('Field "${key.value}" must be followed by a comma.');
      break;
    }
    cursor = _skipTrivia(source, cursor + 1);
    if (cursor == objectEnd) break;
  }
  return _ObjectFieldsScanResult(fields, errors);
}

int? _findTopLevelValueEnd(String source, int start, int objectEnd) {
  final expectedClosers = <String>[];
  var cursor = start;
  while (cursor < objectEnd) {
    final ignoredEnd = _skipIgnored(source, cursor);
    if (ignoredEnd != cursor) {
      cursor = ignoredEnd;
      continue;
    }
    final char = source[cursor];
    if (char == '(') expectedClosers.add(')');
    if (char == '[') expectedClosers.add(']');
    if (char == '{') expectedClosers.add('}');
    if (char == ')' || char == ']' || char == '}') {
      if (expectedClosers.isEmpty || expectedClosers.last != char) return null;
      expectedClosers.removeLast();
    }
    if (char == ',' && expectedClosers.isEmpty) return cursor;
    cursor++;
  }
  return expectedClosers.isEmpty ? objectEnd : null;
}

_StringArrayScanResult _scanStringArray(
  String source,
  int arrayStart,
  int arrayEnd,
) {
  final values = <String>[];
  final errors = <String>[];
  var cursor = _skipTrivia(source, arrayStart + 1);
  while (cursor < arrayEnd) {
    final value = _readStringLiteral(source, cursor);
    if (value == null) {
      errors.add('featuredTripIds may contain only quoted string IDs.');
      break;
    }
    values.add(value.value);
    cursor = _skipTrivia(source, value.end);
    if (cursor == arrayEnd) break;
    if (source[cursor] != ',') {
      errors.add(
        'Featured trip ID "${value.value}" must be followed by a comma.',
      );
      break;
    }
    cursor = _skipTrivia(source, cursor + 1);
    if (cursor == arrayEnd) break;
  }
  return _StringArrayScanResult(values, errors);
}

_ParsedToken? _readPropertyKey(String source, int start) {
  final quoted = _readStringLiteral(source, start);
  if (quoted != null) return quoted;
  if (start >= source.length || !_isIdentifierStart(source.codeUnitAt(start))) {
    return null;
  }
  final end = _readIdentifierEnd(source, start);
  return _ParsedToken(source.substring(start, end), end);
}

_ParsedToken? _readStringLiteral(String source, int start) {
  if (start >= source.length ||
      (source[start] != '"' && source[start] != "'")) {
    return null;
  }
  final quote = source[start];
  final value = StringBuffer();
  var cursor = start + 1;
  while (cursor < source.length) {
    final char = source[cursor];
    if (char == quote) return _ParsedToken(value.toString(), cursor + 1);
    if (char != '\\') {
      if (_isJavaScriptLineTerminator(char)) return null;
      value.write(char);
      cursor++;
      continue;
    }
    if (cursor + 1 >= source.length) return null;
    final escaped = source[cursor + 1];
    const escapes = {
      'n': '\n',
      'r': '\r',
      't': '\t',
      'b': '\b',
      'f': '\f',
      'v': '\v',
    };
    if (_isJavaScriptLineTerminator(escaped)) {
      cursor +=
          escaped == '\r' &&
              cursor + 2 < source.length &&
              source[cursor + 2] == '\n'
          ? 3
          : 2;
      continue;
    }
    if (escaped == 'u') {
      if (cursor + 6 > source.length) return null;
      final digits = source.substring(cursor + 2, cursor + 6);
      if (digits.codeUnits.any((code) => !_isHexDigit(code))) return null;
      final code = int.parse(digits, radix: 16);
      value.writeCharCode(code);
      cursor += 6;
      continue;
    }
    if (escaped == 'x') {
      if (cursor + 4 > source.length) return null;
      final digits = source.substring(cursor + 2, cursor + 4);
      if (digits.codeUnits.any((code) => !_isHexDigit(code))) return null;
      final code = int.parse(digits, radix: 16);
      value.writeCharCode(code);
      cursor += 4;
      continue;
    }
    if (escaped == '0') {
      if (cursor + 2 < source.length &&
          _isDigit(source.codeUnitAt(cursor + 2))) {
        return null;
      }
      value.writeCharCode(0);
      cursor += 2;
      continue;
    }
    if (escaped.codeUnitAt(0) >= 0x31 && escaped.codeUnitAt(0) <= 0x39) {
      return null;
    }
    value.write(escapes[escaped] ?? escaped);
    cursor += 2;
  }
  return null;
}

int _skipTrivia(String source, int start) {
  var cursor = start;
  while (cursor < source.length) {
    final code = source.codeUnitAt(cursor);
    if (_isWhitespace(code)) {
      cursor++;
      continue;
    }
    if (source.startsWith('//', cursor)) {
      final newline = source.indexOf('\n', cursor + 2);
      cursor = newline == -1 ? source.length : newline + 1;
      continue;
    }
    if (source.startsWith('/*', cursor)) {
      final end = source.indexOf('*/', cursor + 2);
      cursor = end == -1 ? source.length : end + 2;
      continue;
    }
    break;
  }
  return cursor;
}

int _skipIgnored(String source, int start) {
  if (start >= source.length) return start;
  if (source.startsWith('//', start)) {
    final newline = source.indexOf('\n', start + 2);
    return newline == -1 ? source.length : newline + 1;
  }
  if (source.startsWith('/*', start)) {
    final end = source.indexOf('*/', start + 2);
    return end == -1 ? source.length : end + 2;
  }
  final quote = source[start];
  if (quote == '`') return _skipTemplateLiteral(source, start);
  if (quote != '"' && quote != "'") return start;

  var cursor = start + 1;
  while (cursor < source.length) {
    if (source[cursor] == '\\') {
      cursor +=
          cursor + 2 < source.length &&
              source[cursor + 1] == '\r' &&
              source[cursor + 2] == '\n'
          ? 3
          : 2;
      continue;
    }
    if (_isJavaScriptLineTerminator(source[cursor])) return source.length;
    if (source[cursor] == quote) return cursor + 1;
    cursor++;
  }
  return source.length;
}

int _skipTemplateLiteral(String source, int start) {
  var cursor = start + 1;
  while (cursor < source.length) {
    final character = source[cursor];
    if (character == '\\') {
      cursor +=
          cursor + 2 < source.length &&
              source[cursor + 1] == '\r' &&
              source[cursor + 2] == '\n'
          ? 3
          : 2;
      continue;
    }
    if (character == '`') return cursor + 1;
    if (character == r'$' &&
        cursor + 1 < source.length &&
        source[cursor + 1] == '{') {
      cursor = _skipTemplateExpression(source, cursor + 2);
      continue;
    }
    cursor++;
  }
  return source.length;
}

int _skipTemplateExpression(String source, int start) {
  var cursor = start;
  var braceDepth = 1;
  var canStartRegularExpression = true;
  var regularExpressionContextIsAmbiguous = false;
  var afterPropertyAccess = false;
  while (cursor < source.length) {
    final ignoredEnd = _skipIgnored(source, cursor);
    if (ignoredEnd != cursor) {
      final ignoredStart = source[cursor];
      cursor = ignoredEnd;
      if (ignoredStart != '/') {
        canStartRegularExpression = false;
        regularExpressionContextIsAmbiguous = false;
        afterPropertyAccess = false;
      }
      continue;
    }

    final character = source[cursor];
    if (character == '/' && canStartRegularExpression) {
      final regularExpressionEnd = _skipRegularExpressionLiteral(
        source,
        cursor,
      );
      if (regularExpressionEnd != null) {
        cursor = regularExpressionEnd;
        canStartRegularExpression = false;
        regularExpressionContextIsAmbiguous = false;
        afterPropertyAccess = false;
        continue;
      }
      if (!regularExpressionContextIsAmbiguous) return source.length;
      // `await` and `yield` are contextual keywords but are also valid
      // identifiers in classic scripts. If no complete regex literal follows,
      // this slash is division after an identifier.
      canStartRegularExpression = true;
      regularExpressionContextIsAmbiguous = false;
      afterPropertyAccess = false;
      cursor++;
      continue;
    }
    if (_isIdentifierStart(source.codeUnitAt(cursor))) {
      final wordStart = cursor;
      final end = _readIdentifierEnd(source, cursor);
      final word = source.substring(cursor, end);
      final isAmbiguousContextualKeyword =
          !afterPropertyAccess && (word == 'await' || word == 'yield');
      canStartRegularExpression =
          isAmbiguousContextualKeyword ||
          (!afterPropertyAccess &&
              (_keywordAllowsExpressionAfter(word) ||
                  (word == 'of' &&
                      _isForOfOperator(source, start, wordStart))));
      regularExpressionContextIsAmbiguous = isAmbiguousContextualKeyword;
      afterPropertyAccess = false;
      cursor = end;
      continue;
    }
    if (_isDigit(source.codeUnitAt(cursor))) {
      cursor++;
      while (cursor < source.length &&
          (_isIdentifierPart(source.codeUnitAt(cursor)) ||
              source[cursor] == '.')) {
        cursor++;
      }
      canStartRegularExpression = false;
      regularExpressionContextIsAmbiguous = false;
      afterPropertyAccess = false;
      continue;
    }
    if (character == '{') {
      braceDepth++;
      canStartRegularExpression = true;
      regularExpressionContextIsAmbiguous = false;
      afterPropertyAccess = false;
      cursor++;
      continue;
    }
    if (character == '}') {
      braceDepth--;
      cursor++;
      if (braceDepth == 0) return cursor;
      canStartRegularExpression = false;
      regularExpressionContextIsAmbiguous = false;
      afterPropertyAccess = false;
      continue;
    }
    if (character == ')' || character == ']') {
      canStartRegularExpression = false;
      regularExpressionContextIsAmbiguous = false;
      afterPropertyAccess = false;
    } else if (!_isWhitespace(source.codeUnitAt(cursor))) {
      if ((character == '+' || character == '-') &&
          cursor + 1 < source.length &&
          source[cursor + 1] == character) {
        // Prefix ++/-- permit an expression after the operator; postfix
        // ++/-- finish an expression, so a following slash is division.
        afterPropertyAccess = false;
        cursor += 2;
        continue;
      }
      afterPropertyAccess = character == '.';
      canStartRegularExpression = !afterPropertyAccess;
      regularExpressionContextIsAmbiguous = false;
    }
    cursor++;
  }
  return source.length;
}

int? _skipRegularExpressionLiteral(String source, int start) {
  var cursor = start + 1;
  var inCharacterClass = false;
  while (cursor < source.length) {
    final character = source[cursor];
    if (_isJavaScriptLineTerminator(character)) return null;
    if (character == '\\') {
      cursor += 2;
      continue;
    }
    if (character == '[') {
      inCharacterClass = true;
      cursor++;
      continue;
    }
    if (character == ']' && inCharacterClass) {
      inCharacterClass = false;
      cursor++;
      continue;
    }
    if (character == '/' && !inCharacterClass) {
      cursor++;
      while (cursor < source.length &&
          _isIdentifierPart(source.codeUnitAt(cursor))) {
        cursor++;
      }
      return cursor;
    }
    cursor++;
  }
  return null;
}

bool _keywordAllowsExpressionAfter(String word) => const <String>{
  'case',
  'delete',
  'do',
  'else',
  'extends',
  'in',
  'instanceof',
  'new',
  'return',
  'throw',
  'typeof',
  'void',
}.contains(word);

bool _isForOfOperator(String source, int expressionStart, int wordStart) {
  final prefix = source
      .substring(expressionStart, wordStart)
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/|//[^\r\n]*'), ' ');
  return RegExp(
    r'\bfor\s*(?:await\s*)?\(\s*'
    r'(?:(?:const|let|var)\b\s*)?'
    r'(?:'
    r'[$A-Za-z_][$\w]*(?:\s*(?:\.\s*[$A-Za-z_][$\w]*|\[[^\]]+\]))*'
    r'|\[[^\]]*\]|\{[^}]*\}'
    r')\s*$',
  ).hasMatch(prefix);
}

int _readIdentifierEnd(String source, int start) {
  var cursor = start + 1;
  while (cursor < source.length &&
      _isIdentifierPart(source.codeUnitAt(cursor))) {
    cursor++;
  }
  return cursor;
}

bool _isIdentifierStart(int code) =>
    code == 0x24 ||
    code == 0x5f ||
    (code >= 0x41 && code <= 0x5a) ||
    (code >= 0x61 && code <= 0x7a);

bool _isIdentifierPart(int code) =>
    _isIdentifierStart(code) || (code >= 0x30 && code <= 0x39);

bool _isDigit(int code) => code >= 0x30 && code <= 0x39;

bool _isHexDigit(int code) =>
    _isDigit(code) ||
    (code >= 0x41 && code <= 0x46) ||
    (code >= 0x61 && code <= 0x66);

bool _isJavaScriptLineTerminator(String character) =>
    character == '\n' ||
    character == '\r' ||
    character == '\u2028' ||
    character == '\u2029';

bool _isWhitespace(int code) =>
    code == 0x09 ||
    code == 0x0a ||
    code == 0x0b ||
    code == 0x0c ||
    code == 0x0d ||
    code == 0x20 ||
    code == 0xa0;
