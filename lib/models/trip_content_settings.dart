import 'dart:convert';

abstract final class TripContentSettings {
  static const titles = {'glance': 'Trip at a glance', 'cancellation': 'Cancellation policy', 'guidelines': 'Trip guidelines', 'faqs': 'FAQs', 'highlights': 'What Makes It Special'};
  static Map<String,dynamic> highlightsDefault() => {'mode':'default','heading':'What Makes It Special','expanded':false,'useTripHighlights':true,'items':<dynamic>[]};
  static bool isCustomKey(Object? key) => key is String && RegExp(r'^custom_[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(key);
  static List<String> customKeys(Map sections) => sections.keys.whereType<String>().where(isCustomKey).toList();
  static List<String> editorKeys(Map sections) => [...titles.keys, ...customKeys(sections)];
  static Map<String,dynamic> customSection(String heading) => {'mode':'custom','heading':heading,'expanded':false,'items':<dynamic>[]};
  static String newKey(Map sections, String heading) {
    var slug = heading.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    if (slug.isEmpty) slug = 'section';
    if (slug.length > 48) slug = slug.substring(0,48);
    var key = 'custom_$slug', suffix = 2;
    while (sections.containsKey(key)) { key = 'custom_${slug}_${suffix++}'; }
    return key;
  }
  static Map<String,dynamic> moveSection(Map sections, String key, int direction) {
    final keys = customKeys(sections), index = keys.indexOf(key), next = index + direction;
    if (index < 0 || next < 0 || next >= keys.length) return copy(sections);
    keys.removeAt(index); keys.insert(next,key);
    return copy({for (final entry in sections.entries) if (!isCustomKey(entry.key)) entry.key:entry.value, for (final key in keys) key:sections[key]});
  }
  static const icons = ['clock', 'location', 'group', 'calendar', 'mountain', 'route', 'info', 'food', 'bus', 'shield', 'walking', 'stay'];
  static const fields = ['', 'duration', 'location', 'difficulty', 'distance', 'groupSize', 'bestTime', 'elevation', 'departureCity'];
  static Map<String, dynamic> copy(Map value) => Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
  static void validate(Map sections, {bool shared = false}) {
    if (customKeys(sections).length > 20) throw const FormatException('Use up to 20 extra sections per trip.');
    for (final entry in sections.entries) {
      final custom = isCustomKey(entry.key);
      if ((!titles.containsKey(entry.key) && !custom) || entry.value is! Map) throw const FormatException('Unsupported trip section.');
      if (custom && shared) throw const FormatException('Extra sections belong to an individual trip.');
      final s = entry.value as Map;
      if (custom && !['custom','hidden'].contains(s['mode'])) throw const FormatException('Choose whether to show or hide this extra section.');
      if (!['default', 'custom', 'hidden'].contains(s['mode'])) throw const FormatException('Choose a section display mode.');
      if (!shared && s['mode'] != 'custom') continue;
      if (s['mode'] == 'hidden') continue;
      if (s['heading'] is! String || (s['heading'] as String).trim().isEmpty || s['expanded'] is! bool || s['items'] is! List) throw const FormatException('Each section needs a heading and valid items.');
      if(entry.key=='highlights' && s['useTripHighlights'] != null && s['useTripHighlights'] is! bool) throw const FormatException('Choose whether to use existing trip highlights.');
      final items = s['items'] as List;
      if (custom && ((s['heading'] as String).length > 120 || items.length > 50)) throw const FormatException('Use a heading up to 120 characters and up to 50 items.');
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
          final required = entry.key == 'glance' ? ['label'] : entry.key == 'faqs' ? ['question', 'answer'] : entry.key == 'highlights' || custom ? ['description'] : ['title', 'description'];
          for (final field in required) {if (raw[field] is! String || (raw[field] as String).trim().isEmpty) throw FormatException('$field cannot be blank.');}
          if (custom && ((raw['title'] != null && (raw['title'] is! String || (raw['title'] as String).length > 160)) || (raw['description'] as String).length > 5000)) throw const FormatException('Use an item title up to 160 characters and description up to 5,000 characters.');
          if (entry.key == 'glance' && (!fields.contains(raw['field'] ?? '') || (raw['field'] == '' && (raw['value'] is! String || (raw['value'] as String).trim().isEmpty)))) throw const FormatException('Choose a linked trip field or enter a value.');
          if (entry.key != 'faqs' && entry.key != 'highlights' && !icons.contains(raw['icon'])) throw const FormatException('Choose a supported icon.');
        }
      }
    }
  }
}

