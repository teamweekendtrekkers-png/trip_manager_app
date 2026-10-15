import 'package:flutter/material.dart';
import '../services/trip_pricing.dart';

class TripPrice extends StatelessWidget {
  const TripPrice({super.key, required this.trip, this.active = true});
  final Map<String, dynamic> trip;
  final bool active;

  static num? amount(Object? value) => TripPricing.amount(value);
  static bool hasDiscount(Map<String, dynamic> trip) =>
      TripPricing.hasDiscount(trip);
  static String money(num value) => TripPricing.money(value);

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: FontWeight.bold,
      color: active ? Colors.green : Colors.grey,
    );
    if (!hasDiscount(trip))
      return Text('${trip['price'] ?? '₹0'}', style: style);
    final original = money(TripPricing.original(trip)!);
    final discount = money(TripPricing.selling(trip)!);
    return Semantics(
      label: 'Original price $original. Discounted price $discount per person.',
      excludeSemantics: true,
      child: Wrap(
        spacing: 8,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            original,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          Text(discount, style: style),
        ],
      ),
    );
  }
}
