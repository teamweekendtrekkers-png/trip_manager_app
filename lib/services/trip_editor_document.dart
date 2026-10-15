import 'trip_date_utils.dart';
import 'trip_pricing.dart';

/// Restore the same field defaults as a fresh editor without modifying the
/// published record. Older trips may predate slugs and departure-time fields.
Map<String, dynamic> publishedTripEditorDocument(Map<String, dynamic> trip) => {
  ...TripPricing.forEditor(trip),
  'publicSlug': trip['publicSlug'] ?? trip['id'] ?? '',
  'departureTime': TripDateUtils.departureClock(trip),
  'title': trip['title'] ?? trip['name'] ?? '',
  'location': trip['location'] ?? trip['destination'] ?? '',
  'about': trip['about'] ?? trip['description'] ?? '',
  'price': TripPricing.forEditor(trip)['price']?.toString() ?? '₹0',
  'groupSize': trip['groupSize']?.toString() ?? '20',
  'badge': trip['badge']?.toString() ?? 'Trek',
};
