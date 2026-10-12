import 'dart:convert';

abstract final class TripContentSettings {
  static const titles = {'glance': 'Trip at a glance', 'cancellation': 'Cancellation policy', 'guidelines': 'Trip guidelines', 'faqs': 'FAQs'};
  static const icons = ['clock', 'location', 'group', 'calendar', 'mountain', 'route', 'info', 'food', 'bus', 'shield', 'walking', 'stay'];
  static const fields = ['', 'duration', 'location', 'difficulty', 'distance', 'groupSize', 'bestTime', 'elevation', 'departureCity'];
  static Map<String, dynamic> copy(Map value) => Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
  static void validate(Map sections, {bool shared = false}) {
    for (final entry in sections.entries) {
      if (!titles.containsKey(entry.key) || entry.value is! Map) throw const FormatException('Unsupported trip section.');
      final s = entry.value as Map;
      if (!['default', 'custom', 'hidden'].contains(s['mode'])) throw const FormatException('Choose a section display mode.');
      if (!shared && s['mode'] != 'custom') continue;
      if (s['mode'] == 'hidden') continue;
      if (s['heading'] is! String || (s['heading'] as String).trim().isEmpty || s['expanded'] is! bool || s['items'] is! List) throw const FormatException('Each section needs a heading and valid items.');
      final items = s['items'] as List;
      if (entry.key == 'cancellation') {
        final rules = items.map((r) => Map<String, dynamic>.from(r as Map)).toList()..sort((a,b) => (a['minDays'] as num).compareTo(b['minDays'] as num));
        num next = 0;
        for (final r in rules) {
          final min = r['minDays'], max = r['maxDays'], percent = r['percent'];
          if (min is! int || min != next || (max != null && (max is! int || max < min)) || percent is! num || !percent.isFinite || percent < 0 || percent > 100) throw const FormatException('Cancellation ranges must cover every day without gaps or overlaps; fees must be 0–100%.');
          next = max == null ? double.infinity : max + 1;
        }
        if (next != double.infinity) throw const FormatException('The last cancellation range must have no upper limit.');
        for (final note in ['refundNote', 'changeNote']) {if (s[note] != null && s[note] is! String) throw const FormatException('Policy notes must be text.');}
      } else {
        for (final raw in items) {
          if (raw is! Map) throw const FormatException('Section items must be objects.');
          if(raw['enabled'] != null && raw['enabled'] is! bool) throw const FormatException('Item visibility must be true or false.');
          final required = entry.key == 'glance' ? ['label'] : entry.key == 'faqs' ? ['question', 'answer'] : ['title', 'description'];
          for (final field in required) {if (raw[field] is! String || (raw[field] as String).trim().isEmpty) throw FormatException('$field cannot be blank.');}
          if (entry.key == 'glance' && (!fields.contains(raw['field'] ?? '') || (raw['field'] == '' && (raw['value'] is! String || (raw['value'] as String).trim().isEmpty)))) throw const FormatException('Choose a linked trip field or enter a value.');
          if (entry.key != 'faqs' && !icons.contains(raw['icon'])) throw const FormatException('Choose a supported icon.');
        }
      }
    }
  }
}
