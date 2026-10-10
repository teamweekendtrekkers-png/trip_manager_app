import 'dart:convert';

/// Website display only. Payment IDs and checkout behavior remain in their existing settings.
class FooterConfig {
  static const defaultsJson = r'''
{
  "brandName": "Team Weekend Trekkers",
  "description": "A Travel community for the travellers, By the travellers. 🧗 Trips | Tours | Unique Experiences 🏕️",
  "quickLinksTitle": "Quick Links",
  "homeLabel": "Home",
  "tripsLabel": "All Trips",
  "aboutLabel": "About Us",
  "contactLabel": "Contact",
  "informationTitle": "Information",
  "informationLinks": [],
  "contactTitle": "Contact Us",
  "location": "Kalkere, Bangalore",
  "whatsAppNumber": "",
  "instagramUrl": "",
  "instagramLabel": "",
  "email": "",
  "showSocialLinks": true,
  "showUpi": true,
  "upiTitle": "Pay via UPI",
  "copyUpiLabel": "Copy UPI ID",
  "copyright": "© {year} {brand}. All rights reserved."
}
''';
  static Map<String, dynamic> defaults() =>
      jsonDecode(defaultsJson) as Map<String, dynamic>;

  static bool safeLink(String value) {
    if (RegExp(r'''[\s<>"'`\\\x00-\x1f]''').hasMatch(value)) {
      return false;
    }
    if (RegExp(
      r'^(?:index|trips|about|contact)\.html(?:#[A-Za-z][A-Za-z0-9_-]*)?$',
    ).hasMatch(value)) {
      return true;
    }
    if (!value.toLowerCase().startsWith('https://') ||
        RegExp(
          r'^https://[^/?#]+:\d+(?:[/?#]|$)',
          caseSensitive: false,
        ).hasMatch(value)) {
      return false;
    }
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasPort;
  }

  static bool safeInstagram(String value) =>
      safeLink(value) &&
      (Uri.tryParse(value)?.path.length ?? 0) > 1 &&
      [
        'instagram.com',
        'www.instagram.com',
      ].contains(Uri.tryParse(value)?.host);

  static void validate(Map<String, dynamic> data) {
    final template = defaults();
    if (data.keys.any((key) => !template.containsKey(key))) {
      throw const FormatException('Unsupported footer fields.');
    }
    const optional = [
      'whatsAppNumber',
      'instagramUrl',
      'instagramLabel',
      'email',
    ];
    for (final entry in template.entries) {
      final value = data[entry.key];
      if (entry.value is bool) {
        if (value is! bool) {
          throw FormatException('Footer ${entry.key} must be a boolean.');
        }
      } else if (entry.value is String) {
        if (value is! String ||
            value.length > 2000 ||
            (!optional.contains(entry.key) && value.trim().isEmpty)) {
          throw FormatException(
            'Footer ${entry.key} must be text (up to 2000 characters).',
          );
        }
      }
    }
    final whatsapp = data['whatsAppNumber'] as String;
    if (whatsapp.isNotEmpty && !RegExp(r'^[1-9]\d{7,14}$').hasMatch(whatsapp)) {
      throw const FormatException(
        'Footer WhatsApp needs 8–15 digits including country code, or leave blank to use the website number.',
      );
    }
    final instagram = data['instagramUrl'] as String;
    if (instagram.isNotEmpty && !safeInstagram(instagram)) {
      throw const FormatException(
        'Use a valid HTTPS Instagram link, or leave blank to use the website link.',
      );
    }
    final email = data['email'] as String;
    if (email.isNotEmpty &&
        !RegExp(r'^[^\s<>@]+@[^\s<>@]+\.[^\s<>@]+$').hasMatch(email)) {
      throw const FormatException(
        'Enter a valid footer email address, or leave blank.',
      );
    }
    final links = data['informationLinks'];
    if (links is! List || links.length > 8) {
      throw const FormatException(
        'Footer supports up to eight information links.',
      );
    }
    final ids = <String>{};
    for (final item in links) {
      if (item is! Map ||
          item.length != 4 ||
          !item.keys.every(['id', 'label', 'url', 'visible'].contains) ||
          item['id'] is! String ||
          !RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(item['id']) ||
          !ids.add(item['id']) ||
          item['label'] is! String ||
          (item['label'] as String).trim().isEmpty ||
          (item['label'] as String).length > 2000 ||
          item['url'] is! String ||
          (item['url'] as String).length > 2000 ||
          !safeLink(item['url']) ||
          item['visible'] is! bool) {
        throw const FormatException(
          'Each information link needs a unique ID, label, safe URL and visibility.',
        );
      }
    }
  }
}
