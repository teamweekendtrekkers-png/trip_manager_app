import 'dart:convert';

/// Apply only explicitly changed quick-edit fields to the current workspace.
/// Remote edits to other fields are retained; same-field conflicts are surfaced.
Map<String, dynamic> mergeQuickTripEdit(Map<String, dynamic> current, Map<String, dynamic> initial, Map<String, dynamic> edited) {
  if (current['id'] != initial['id'] || edited['id'] != initial['id']) throw StateError('This trip changed. Reopen quick edit.');
  final result = Map<String, dynamic>.from(jsonDecode(jsonEncode(current)) as Map);
  const fields = ['price', 'availableDates', 'date', 'isActive', 'featured'];
  for (final field in fields) {
    final before = jsonEncode(initial[field]), after = jsonEncode(edited[field]), live = jsonEncode(current[field]);
    if (before == after && initial.containsKey(field) == edited.containsKey(field)) continue;
    if (live != before && live != after) throw StateError('The trip’s $field changed while quick edit was open. Reopen quick edit to review it.');
    if (edited.containsKey(field)) { result[field] = edited[field]; } else { result.remove(field); }
  }
  return result;
}
