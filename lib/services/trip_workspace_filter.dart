import 'trip_cover.dart';
import 'trip_date_utils.dart';

enum TripWorkspaceSort {
  website('Website order'),
  name('Trip name'),
  departure('Next departure');

  const TripWorkspaceSort(this.label);
  final String label;
}

List<Map<String, dynamic>> sortTripWorkspace(
  List<Map<String, dynamic>> trips,
  TripWorkspaceSort sort, {
  DateTime? referenceDate,
}) {
  if (sort == TripWorkspaceSort.website) return List.of(trips);
  final dates = <Map<String, dynamic>, DateTime?>{};
  if (sort == TripWorkspaceSort.departure) {
    for (final trip in trips) {
      final ranges = TripDateUtils.getUpcomingDateRanges(
        trip,
        referenceDate: referenceDate,
      );
      dates[trip] = ranges.isEmpty
          ? null
          : ranges
                .map((range) => range.start)
                .reduce((a, b) => a.isBefore(b) ? a : b);
    }
  }
  final indexed = trips.asMap().entries.toList();
  indexed.sort((a, b) {
    int comparison;
    if (sort == TripWorkspaceSort.name) {
      String name(Map trip) =>
          (trip['title'] ?? trip['name'] ?? '').toString().trim().toLowerCase();
      comparison = name(a.value).compareTo(name(b.value));
    } else {
      final first = dates[a.value], second = dates[b.value];
      comparison = first == null
          ? (second == null ? 0 : 1)
          : second == null
          ? -1
          : first.compareTo(second);
    }
    return comparison == 0 ? a.key.compareTo(b.key) : comparison;
  });
  return indexed.map((entry) => entry.value).toList();
}

/// Shared rules keep the filter counts and the visible results consistent.
bool matchesTripWorkspaceFilter(
  Map<String, dynamic> trip,
  String filter, {
  required bool hasDraft,
  DateTime? referenceDate,
}) {
  final active = trip['isActive'] != false;
  switch (filter) {
    case 'Active':
      return active;
    case 'Inactive':
      return !active;
    case 'Draft':
      return hasDraft;
    case 'Needs photo':
      return trip['image']?.toString().trim().isNotEmpty != true ||
          isPlaceholderTripCover(trip['image']);
    case 'Upcoming':
    case 'Needs dates':
      final upcoming = TripDateUtils.getUpcomingDateRanges(
        trip,
        referenceDate: referenceDate,
      ).isNotEmpty;
      return active && (filter == 'Upcoming' ? upcoming : !upcoming);
    default:
      return true;
  }
}
