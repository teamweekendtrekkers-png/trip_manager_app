/// Optional per-trip website display preferences. Missing means all collapsed.
class TripSectionSettings {
  const TripSectionSettings._();

  static const titles = <String, String>{
    'about': 'About This Trip',
    'highlights': 'What Makes It Special',
    'includes': "What's Included & Excluded",
    'thingsToCarry': 'Things to Carry',
  };

  static List<String> expandedFor(Map<String, dynamic> trip) {
    final value = trip['expandedSections'];
    if (value is! List) return <String>[];
    return titles.keys.where(value.contains).toList();
  }

  static String? validationError(Object? value) {
    if (value is! List || value.any((key) => !titles.containsKey(key))) {
      return 'expandedSections must be a list containing only about, highlights, includes, or thingsToCarry.';
    }
    if (value.toSet().length != value.length) {
      return 'expandedSections must not contain duplicates.';
    }
    return null;
  }
}
