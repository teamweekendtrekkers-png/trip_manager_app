import 'dart:convert';
import '../services/trip_date_utils.dart';
import 'homepage_section_defaults.dart';
import 'homepage_sections.dart';
import 'footer_config.dart';

/// Website-only configuration. Trip records and local app settings stay separate.
class HomepageConfig {
  HomepageConfig._(this._data);
  final Map<String, dynamic> _data;

  static const defaults = <String, dynamic>{
    'version': 1,
    'discovery': {
      'enabled': true,
      'showSearch': true,
      'showExperienceFilter': true,
      'showWeekendFilter': true,
    },
    'presentation': {
      'preset': 'forest',
      'heroMobileImage': '',
      'heroFocalPoint': 'center',
      'heroMobileFocalPoint': 'center',
      'heroSlides': <String>[],
      'heroMotion': false,
    },
    'hero': {
      'backgroundImage': 'images/wix/hero1.jpg',
      'title': 'Explore. Travel. Experience.',
      'tagline': '🧗 Trips | Tours | Unique Experiences 🏕️',
      'description': 'A travel community for travellers, by travellers',
    },
    'upcomingBatches': {
      'enabled': true,
      'title': 'Upcoming Batches',
      'subtitle': 'Plan your next escape with our nearest available trip dates',
      'maxBatches': 3,
      'tripSelection': 'all',
      'tripIds': <String>[],
      'departureSelection': 'all',
      'departures': <Map<String, String>>[],
      'fields': {
        'price': true,
        'status': true,
        'weekday': true,
        'location': false,
        'duration': false,
        'difficulty': false,
        'image': false,
      },
    },
  };

  factory HomepageConfig.initial() =>
      HomepageConfig.parse(jsonEncode(defaults));

  factory HomepageConfig.parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
      throw const FormatException(
        'Unsupported homepage configuration version.',
      );
    }
    Map<String, dynamic> fill(
      Map<String, dynamic> template,
      Map value,
      String path,
    ) {
      final unknown = value.keys.where((key) => !template.containsKey(key));
      if (unknown.isNotEmpty) {
        throw FormatException(
          'Unsupported fields in $path: ${unknown.join(', ')}',
        );
      }
      return {
        for (final entry in template.entries)
          entry.key: entry.value is Map<String, dynamic>
              ? fill(
                  entry.value as Map<String, dynamic>,
                  value[entry.key] is Map
                      ? value[entry.key] as Map
                      : value.containsKey(entry.key)
                      ? throw FormatException(
                          '$path.${entry.key} must be an object.',
                        )
                      : {},
                  '$path.${entry.key}',
                )
              : value.containsKey(entry.key)
              ? value[entry.key]
              : entry.value,
      };
    }

    final data = fill(
      {
        ...defaults,
        'sections': homepageSectionDefaults(),
        'footer': FooterConfig.defaults(),
      },
      decoded,
      'homepage',
    );
    final rawSections = decoded['sections'];
    if (rawSections is Map &&
        rawSections['whyUs'] is Map &&
        rawSections['whyUs']['enabled'] == false) {
      for (final name in ['howItWorks', 'whyChooseUs']) {
        if (!rawSections.containsKey(name)) {
          data['sections'][name]['enabled'] = false;
        }
      }
    }
    HomepageSections.validate(data['sections'] as Map<String, dynamic>);
    FooterConfig.validate(data['footer'] as Map<String, dynamic>);
    if ((data['discovery'] as Map).values.any((value) => value is! bool)) {
      throw const FormatException('Discovery settings must be booleans.');
    }
    final presentation = data['presentation'] as Map<String, dynamic>;
    if (!['forest', 'ocean', 'earth'].contains(presentation['preset']) ||
        !['center', 'top', 'bottom', 'left', 'right'].contains(presentation['heroFocalPoint']) ||
        !['center', 'top', 'bottom', 'left', 'right'].contains(presentation['heroMobileFocalPoint']) ||
        presentation['heroMotion'] is! bool ||
        presentation['heroMobileImage'] is! String ||
        (presentation['heroMobileImage'] != '' && !safeImage(presentation['heroMobileImage'] as String)) ||
        presentation['heroSlides'] is! List ||
        (presentation['heroSlides'] as List).length > 2 ||
        (presentation['heroSlides'] as List).any((image) => image is! String || !safeImage(image))) {
      throw const FormatException('Choose an approved appearance, safe images and at most two additional hero photos.');
    }
    final hero = data['hero'] as Map<String, dynamic>;
    final batches = data['upcomingBatches'] as Map<String, dynamic>;
    for (final entry in {
      ...hero,
      'batch title': batches['title'],
      'batch subtitle': batches['subtitle'],
    }.entries) {
      if (entry.value is! String ||
          (entry.value as String).trim().isEmpty ||
          (entry.value as String).length > 2000) {
        throw FormatException(
          '${entry.key} must be non-empty text (up to 2000 characters).',
        );
      }
    }
    if (!safeImage(hero['backgroundImage'] as String)) {
      throw const FormatException(
        'Use an images/... path or a valid HTTPS image URL.',
      );
    }
    if (batches['enabled'] is! bool ||
        batches['maxBatches'] is! int ||
        (batches['maxBatches'] as int) < 1 ||
        (batches['maxBatches'] as int) > 12) {
      throw const FormatException(
        'Batch count must be between 1 and 12; visibility must be a boolean.',
      );
    }
    for (final key in ['tripSelection', 'departureSelection']) {
      if (!['all', 'selected'].contains(batches[key])) {
        throw FormatException('Invalid $key.');
      }
    }
    final ids = batches['tripIds'];
    if (ids is! List || ids.any((id) => id is! String || id.trim().isEmpty)) {
      throw const FormatException('Selected trip IDs must be a string list.');
    }
    batches['tripIds'] = ids.toSet().toList();
    final departures = batches['departures'];
    if (departures is! List) {
      throw const FormatException('Departures must be a list.');
    }
    final seen = <String>{};
    final normalized = <Map<String, String>>[];
    for (final item in departures) {
      if (item is! Map ||
          item.keys.any((key) => !['tripId', 'date'].contains(key)) ||
          item['tripId'] is! String ||
          (item['tripId'] as String).trim().isEmpty ||
          item['date'] is! String) {
        throw const FormatException(
          'Each departure needs a tripId and a valid date.',
        );
      }
      final range = TripDateUtils.parse(item['date'] as String);
      if (range == null) {
        throw FormatException('Invalid selected departure: ${item['date']}');
      }
      if (seen.add('${item['tripId']}|${range.key}')) {
        normalized.add({
          'tripId': item['tripId'] as String,
          'date': TripDateUtils.formatCanonical(range),
        });
      }
    }
    batches['departures'] = normalized;
    if ((batches['fields'] as Map).values.any((value) => value is! bool)) {
      throw const FormatException('Detail visibility values must be booleans.');
    }
    return HomepageConfig._(
      Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map),
    );
  }

  static bool safeImage(String value) {
    if (RegExp(r'''[\s"'()<>\\\x00-\x1f]''').hasMatch(value)) return false;
    final uri = Uri.tryParse(value);
    if (uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        uri.path.startsWith('/')) {
      return true;
    }
    return RegExp(r'^images/[A-Za-z0-9_./-]+$').hasMatch(value) &&
        !value.split('/').any((part) => part == '..' || part == '.');
  }

  Map<String, dynamic> toJson() =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(_data)) as Map);
  String encode() => '${const JsonEncoder.withIndent('  ').convert(_data)}\n';

  List<Map<String, dynamic>> selectedTrips(
    List<Map<String, dynamic>> trips, {
    DateTime? referenceDate,
  }) {
    final options = _data['upcomingBatches'] as Map;
    return [
      for (final trip in trips)
        if (options['tripSelection'] == 'all' ||
            (options['tripIds'] as List).contains(trip['id']))
          {
            ...trip,
            'availableDates': [
              for (final range in TripDateUtils.getUpcomingDateRanges(
                trip,
                referenceDate: referenceDate,
              ))
                if (options['departureSelection'] == 'all' ||
                    (options['departures'] as List).any(
                      (item) =>
                          item['tripId'] == trip['id'] &&
                          TripDateUtils.parse(item['date'] as String)?.key ==
                              range.key,
                    ))
                  TripDateUtils.formatCanonical(range),
            ],
          },
    ];
  }

  List<UpcomingBatch> buildBatches(
    List<Map<String, dynamic>> trips, {
    DateTime? referenceDate,
  }) {
    final options = _data['upcomingBatches'] as Map;
    if (options['enabled'] == false) return [];
    return TripDateUtils.buildUpcomingBatches(
      selectedTrips(trips, referenceDate: referenceDate),
      referenceDate: referenceDate,
      limit: options['maxBatches'] as int,
    );
  }
}
