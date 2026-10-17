import '../models/trip_card_settings.dart';
import 'trip_date_utils.dart';
import 'trip_pricing.dart';

/// Advisory checks only. Never edits or publishes trip data.
List<String> tripAttention(Map<String, dynamic> trip, {DateTime? now}) {
  if (trip['isActive'] == false) return const [];
  final price = TripPricing.selling(trip);
  return [
    if (TripDateUtils.getUpcomingDateRanges(trip, referenceDate: now).isEmpty)
      'Add upcoming dates',
    if (price == null || price <= 0) 'Check price',
    if (TripCardSettings.coverFor(trip).isEmpty) 'Add a cover photo',
  ];
}
