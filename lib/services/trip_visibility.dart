import '../models/homepage_config.dart';
import 'trip_date_utils.dart';

abstract final class TripVisibility {
  static String upcoming(
    Map<String, dynamic> trip,
    HomepageConfig? config, {
    DateTime? referenceDate,
  }) {
    if (trip['isActive'] == false) return 'Upcoming Batches: inactive';
    if (config == null) return 'Upcoming Batches: check Website content';
    final options = config.toJson()['upcomingBatches'] as Map;
    if (options['enabled'] != true) return 'Upcoming Batches: section hidden';
    if (options['tripSelection'] == 'selected' &&
        !(options['tripIds'] as List).contains(trip['id']))
      return 'Upcoming Batches: not selected';
    final chosen = config.selectedTrips([trip], referenceDate: referenceDate);
    if (chosen.isEmpty ||
        TripDateUtils.getUpcomingDateRanges(
          chosen.first,
          referenceDate: referenceDate,
        ).isEmpty)
      return 'Upcoming Batches: no selected bookable dates';
    return 'Upcoming Batches: selected';
  }
}
