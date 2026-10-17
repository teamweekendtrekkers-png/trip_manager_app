import 'dart:convert';

enum BookingReviewFilter {
  all('All'), pending('Pending'), verified('Verified'),
  rejected('Rejected'), requests('Requests');
  const BookingReviewFilter(this.label);
  final String label;
}

Map? bookingPaymentReport(Map booking) {
  final text = booking['special_requests']?.toString() ?? '';
  if (!text.startsWith('[TWT_PAYMENT:')) return null;
  final end = text.indexOf(']\n');
  if (end < 0) return null;
  try {
    final value = jsonDecode(text.substring(13, end));
    return value is Map ? value : null;
  } catch (_) { return null; }
}

bool matchesBookingReview(Map booking, BookingReviewFilter filter) {
  if (filter == BookingReviewFilter.all) return true;
  final report = bookingPaymentReport(booking);
  if (filter == BookingReviewFilter.requests) return report == null;
  return report != null &&
      (booking['payment_review_status'] ?? 'pending') == filter.name;
}
