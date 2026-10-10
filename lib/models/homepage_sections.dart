import 'homepage_section_defaults.dart';

/// Strict admin-side checks: invalid or unknown data must never be dropped.
class HomepageSections {
  static bool safeGoogleMapsUrl(String value) {
    if (RegExp(r'[\s<>\\\x00-\x1f]').hasMatch(value)) return false;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort) {
      return false;
    }
    return (uri.host == 'maps.app.goo.gl' && uri.path.length > 1) ||
        ([
              'google.com',
              'www.google.com',
              'google.co.in',
              'www.google.co.in',
            ].contains(uri.host) &&
            uri.path.startsWith('/maps')) ||
        ['maps.google.com', 'maps.google.co.in'].contains(uri.host) ||
        (uri.host == 'goo.gl' && uri.path.startsWith('/maps/')) ||
        (uri.host == 'g.page' && uri.path.length > 1);
  }

  static void validate(Map<String, dynamic> sections) {
    final defaults = homepageSectionDefaults();
    void text(
      Object? value,
      String field, {
      bool optional = false,
      int max = 2000,
    }) {
      if (value is! String ||
          (!optional && value.trim().isEmpty) ||
          value.length > max) {
        throw FormatException(
          '$field must be ${optional ? "" : "non-empty "}text (up to $max characters).',
        );
      }
    }

    for (final name in defaults.keys) {
      final section = sections[name] as Map;
      if (section['enabled'] is! bool) {
        throw FormatException('$name visibility must be a boolean.');
      }
      for (final key in (defaults[name] as Map).keys) {
        if (key == 'items' ||
            key == 'enabled' ||
            key == 'autoPlay' ||
            key == 'intervalSeconds') {
          continue;
        }
        text(
          section[key],
          '$name.$key',
          optional: ['eyebrow', 'subtitle'].contains(key),
        );
      }
      if (name == 'reviews') {
        if (!safeGoogleMapsUrl(section['googleMapsUrl'] as String)) {
          throw const FormatException(
            'Use a valid HTTPS Google Maps or Google review link.',
          );
        }
        final rating = double.tryParse(section['rating'] as String);
        if (rating == null || !rating.isFinite || rating < 1 || rating > 5) {
          throw const FormatException('Google rating must be between 1 and 5.');
        }
        if (section['autoPlay'] is! bool ||
            section['intervalSeconds'] is! int ||
            section['intervalSeconds'] < 4 ||
            section['intervalSeconds'] > 30) {
          throw const FormatException(
            'Review slide interval must be 4–30 seconds.',
          );
        }
      }
      if (name == 'cta') continue;
      final items = section['items'];
      final limit = name == 'reviews' ? 30 : 8;
      if (items is! List || items.length > limit) {
        throw FormatException('$name supports up to $limit items.');
      }
      final template = (defaults[name]['items'] as List).first as Map;
      final seen = <String>{};
      for (final item in items) {
        if (item is! Map ||
            item.keys.any((key) => !template.containsKey(key)) ||
            template.keys.any((key) => !item.containsKey(key))) {
          throw FormatException('Unsupported or missing fields in $name item.');
        }
        if (item['id'] is! String ||
            !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(item['id']) ||
            !seen.add(item['id'] as String)) {
          throw FormatException('Each $name item needs a unique ID.');
        }
        if (item['visible'] is! bool) {
          throw FormatException('$name item visibility must be boolean.');
        }
        for (final key in template.keys) {
          if (key == 'visible' || key == 'rating') continue;
          text(
            item[key],
            '$name.${item['id']}.$key',
            optional:
                ['photo', 'googleMapsUrl', 'date', 'icon'].contains(key) ||
                (name == 'whyChooseUs' && key == 'value'),
            max: key == 'text' ? 10000 : 2000,
          );
        }
        if (template.containsKey('accent') &&
            !['blue', 'orange', 'green'].contains(item['accent'])) {
          throw FormatException(
            'Choose blue, orange or green for $name card colour.',
          );
        }
        if (name == 'reviews') {
          if (item['rating'] is! int ||
              item['rating'] < 1 ||
              item['rating'] > 5) {
            throw const FormatException('Review stars must be 1–5.');
          }
          if ((item['googleMapsUrl'] as String).isNotEmpty &&
              !safeGoogleMapsUrl(item['googleMapsUrl'] as String)) {
            throw const FormatException('Invalid review Google Maps link.');
          }
          // HTTPS photos only; no executable/data URLs or credentials.
          final photo = item['photo'] as String;
          final uri = Uri.tryParse(photo);
          if (photo.isNotEmpty &&
              (RegExp(r'''[\s"'()<>\\\x00-\x1f]''').hasMatch(photo) ||
                  uri == null ||
                  uri.scheme != 'https' ||
                  uri.host.isEmpty ||
                  uri.userInfo.isNotEmpty ||
                  !uri.path.startsWith('/'))) {
            throw const FormatException(
              'Reviewer photo must be a valid HTTPS URL, or empty.',
            );
          }
        }
      }
    }
  }
}
