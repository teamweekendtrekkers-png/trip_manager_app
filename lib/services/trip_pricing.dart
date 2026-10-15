import 'package:intl/intl.dart';

/// `price` remains the selling fare consumed by the existing website/checkout.
/// `originalPrice` is optional display metadata; it never increases that fare.
abstract final class TripPricing {
  static num? amount(Object? value) {
    final text = '${value ?? ''}'
        .replaceAll('₹', '')
        .replaceAll(',', '')
        .trim();
    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(text)) return null;
    final number = num.tryParse(text);
    return number != null && number.isFinite ? number : null;
  }

  static String money(num value) => NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: value % 1 == 0 ? 0 : 2,
  ).format(value);
  static bool lower(num? original, num? discount) =>
      original != null &&
      discount != null &&
      discount > 0 &&
      discount < original;
  static bool getLegacyDiscount(Map<String, dynamic> trip) =>
      lower(amount(trip['price']), amount(trip['discountedPrice']));
  static bool hasDiscount(Map<String, dynamic> trip) =>
      getLegacyDiscount(trip) ||
      lower(amount(trip['originalPrice']), amount(trip['price']));
  static num? original(Map<String, dynamic> trip) => getLegacyDiscount(trip)
      ? amount(trip['price'])
      : amount(trip['originalPrice']);
  static num? selling(Map<String, dynamic> trip) => getLegacyDiscount(trip)
      ? amount(trip['discountedPrice'])
      : amount(trip['price']);

  static Map<String, dynamic> forEditor(Map<String, dynamic> trip) {
    if (getLegacyDiscount(trip) ||
        !lower(amount(trip['originalPrice']), amount(trip['price'])))
      return {...trip};
    return {
      ...trip,
      'price': money(amount(trip['originalPrice'])!),
      'discountedPrice': amount(trip['price']),
    };
  }

  static Map<String, dynamic> forPublication(Map<String, dynamic> trip) {
    if (!getLegacyDiscount(trip))
      return {
        ...trip,
        if (amount(trip['price']) != null)
          'priceNumeric': amount(trip['price']),
      };
    return {
      ...trip,
      'price': money(amount(trip['discountedPrice'])!),
      'priceNumeric': amount(trip['discountedPrice']),
      'originalPrice': amount(trip['price']),
    }..remove('discountedPrice');
  }
}
