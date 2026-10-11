import '../services/trip_date_utils.dart';
import 'homepage_config.dart';

/// Optional website card metadata. Legacy trips retain their original fields.
abstract final class TripCardSettings {
  static const experiences = <String, String>{
    'trek': 'Treks',
    'beach': 'Beaches',
    'heritage': 'Heritage',
    'getaway': 'Relaxed getaways',
    'adventure': 'Adventure',
    'other': 'Other experiences',
  };

  static const optionalFields = <String>{
    'cardImage',
    'cardFocalPoint',
    'imageFocalPoint',
    'cardSummary',
    'departureCity',
    'experience',
  };

  static String coverFor(Map<String, dynamic> trip) {
    final cover = trip['cardImage'];
    if (cover is String &&
        cover.isNotEmpty &&
        HomepageConfig.safeImage(cover)) {
      return cover;
    }
    return trip['image'] is String ? (trip['image'] as String).trim() : '';
  }

  static String experienceFor(Map<String, dynamic> trip) =>
      experiences.containsKey(trip['experience'])
      ? trip['experience'] as String
      : 'other';

  static String? fieldError(String field, Object? value) {
    if (value is! String) return '$field must be text.';
    final text = value.trim();
    switch (field) {
      case 'cardFocalPoint':
      case 'imageFocalPoint':
        if (!['center', 'top', 'bottom', 'left', 'right'].contains(value)) {
          return 'Choose a supported photo focus.';
        }
      case 'cardImage':
        if (value.isNotEmpty && !HomepageConfig.safeImage(value)) {
          return 'Use an images/... path or a safe HTTPS image URL.';
        }
      case 'cardSummary':
        if (text.length > 160) {
          return 'Card summary must be at most 160 characters.';
        }
      case 'departureCity':
        if (text.length > 80) {
          return 'Departure city must be at most 80 characters.';
        }
      case 'experience':
        if (!experiences.containsKey(value)) {
          return 'Choose a supported experience.';
        }
    }
    return null;
  }

  static List<String> validationErrors(Map<String, dynamic> trip) => [
    for (final field in optionalFields)
      if (trip.containsKey(field))
        if (fieldError(field, trip[field]) case final String error)
          '$field: $error',
  ];

  /// Advisory only: never alters packing text, dates, prices, or publication.
  static List<String> qualityWarnings(
    Map<String, dynamic> trip, {
    DateTime? referenceDate,
  }) {
    final title = '${trip['title'] ?? trip['name'] ?? ''}'.trim();
    final packing = trip['thingsToCarry'];
    return [
      if (coverFor(trip).isEmpty)
        'Add a clear card photo. An empty cover uses the display image.',
      if (title.length > 80)
        'This title is long for a mobile card. Consider a shorter, descriptive name.',
      if (trip['isActive'] != false &&
          TripDateUtils.getUpcomingDateRanges(
            trip,
            referenceDate: referenceDate,
          ).isEmpty)
        'No current or upcoming dates. Visitors will see “New dates coming soon.”',
      if (packing is List &&
          packing.length == 1 &&
          packing.single is String &&
          (packing.single as String).length > 180)
        'The packing checklist is one long item. Use Things to Carry in this editor to add separate checklist items.',
    ];
  }
}
