import 'dart:convert';

class FieldChange {
  const FieldChange(this.path, this.before, this.after);
  final String path;
  final Object? before, after;
  String get label => path
      .split('.')
      .map((p) => p.replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m[0]}'))
      .join(' › ');
  static String describe(Object? value) => value == null
      ? 'Not set'
      : value is String
      ? value
      : const JsonEncoder.withIndent('  ').convert(value);
}

abstract final class WorkspaceChanges {
  static bool same(Object? a, Object? b) {
    if (a is Map && b is Map)
      return a.length == b.length &&
          a.keys.every((k) => b.containsKey(k) && same(a[k], b[k]));
    if (a is List && b is List)
      return a.length == b.length &&
          List.generate(a.length, (i) => i).every((i) => same(a[i], b[i]));
    return a == b;
  }

  static List<FieldChange> diff(
    Object? before,
    Object? after, [
    String prefix = '',
  ]) {
    if (same(before, after)) return [];
    if (before is Map && after is Map)
      return [
        for (final key in {...before.keys, ...after.keys})
          ...diff(
            before[key],
            after[key],
            prefix.isEmpty ? '$key' : '$prefix.$key',
          ),
      ];
    return [FieldChange(prefix.isEmpty ? 'Content' : prefix, before, after)];
  }

  static Map<String, List<FieldChange>> trips(
    List<Map<String, dynamic>> base,
    List<Map<String, dynamic>> local,
  ) {
    final old = {for (final trip in base) trip['id'].toString(): trip},
        current = {for (final trip in local) trip['id'].toString(): trip};
    return {
      for (final id in {...old.keys, ...current.keys})
        if (!same(old[id], current[id])) id: diff(old[id], current[id]),
    };
  }

  static bool reordered(
    List<Map<String, dynamic>> base,
    List<Map<String, dynamic>> local,
  ) {
    final common = base
        .map((t) => t['id'])
        .toSet()
        .intersection(local.map((t) => t['id']).toSet());
    return !same(
      base.where((t) => common.contains(t['id'])).map((t) => t['id']).toList(),
      local.where((t) => common.contains(t['id'])).map((t) => t['id']).toList(),
    );
  }

  static List<Map<String, dynamic>> select(
    List<Map<String, dynamic>> base,
    List<Map<String, dynamic>> local,
    Set<String> ids,
  ) {
    final changes = {for (final trip in local) trip['id'].toString(): trip};
    final existing = base.map((t) => t['id'].toString()).toSet();
    return [
      for (final trip in base)
        if (!ids.contains(trip['id'].toString()))
          trip
        else if (changes.containsKey(trip['id'].toString()))
          changes[trip['id'].toString()]!,
      for (final trip in local)
        if (!existing.contains(trip['id']) && ids.contains(trip['id'])) trip,
    ];
  }
}
