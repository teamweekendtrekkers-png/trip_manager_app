import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/widgets/trip_price.dart';
import 'package:trip_manager_app/services/trip_pricing.dart';
import 'package:trip_manager_app/services/trips_parser.dart';

void main() {
  test(
    'discount survives publication and reload while selling fare stays discounted',
    () {
      final input = <String, dynamic>{
        'id': 'offer',
        'title': 'Offer trip',
        'price': '₹6,599',
        'discountedPrice': 5999,
      };
      final source = TripsParser.generateTripsDataJs([input]);
      final loaded = TripsParser.parseTripsData(source).single;
      expect(loaded['price'], '₹5,999');
      expect(loaded['priceNumeric'], 5999);
      expect(loaded['originalPrice'], 6599);
      expect(TripPrice.hasDiscount(loaded), true);
      final editor = TripPricing.forEditor(loaded);
      expect(editor['price'], '₹6,599');
      expect(editor['discountedPrice'], 5999);
      final savedAgain = TripPricing.forPublication(editor);
      expect(savedAgain['price'], '₹5,999');
      expect(savedAgain['originalPrice'], 6599);
      expect(TripPricing.forPublication(loaded), loaded);
      expect(input['price'], '₹6,599');
    },
  );
  test('discount requires a valid lower positive amount', () {
    expect(
      TripPrice.hasDiscount({'price': '₹6,599', 'discountedPrice': 5999}),
      true,
    );
    for (final value in [null, '', 0, -1, 6599, 7000, 'NaN', 'wrong', '1e3']) {
      expect(
        TripPrice.hasDiscount({'price': '₹6,599', 'discountedPrice': value}),
        false,
      );
    }
    expect(
      TripPrice.hasDiscount({'price': 'Contact us', 'discountedPrice': 5999}),
      false,
    );
    expect(TripPrice.money(123456.5), '₹1,23,456.50');
  });

  testWidgets('original is struck through and discounted price is prominent', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TripPrice(
            trip: {'price': '₹6,599', 'discountedPrice': '₹5,999'},
          ),
        ),
      ),
    );
    final original = tester.widget<Text>(find.text('₹6,599'));
    final discounted = tester.widget<Text>(find.text('₹5,999'));
    expect(original.style!.decoration, TextDecoration.lineThrough);
    expect(discounted.style!.decoration, isNull);
    expect(discounted.style!.fontWeight, FontWeight.bold);
    expect(
      find.bySemanticsLabel(
        'Original price ₹6,599. Discounted price ₹5,999 per person.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'no discount keeps existing price unchanged and inactive prices stay grey',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TripPrice(trip: {'price': '₹4,499'}, active: false),
          ),
        ),
      );
      final price = tester.widget<Text>(find.text('₹4,499'));
      expect(price.style!.decoration, isNull);
      expect(price.style!.color, Colors.grey);
    },
  );

  testWidgets('price pair wraps in a narrow card without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 85,
            child: TripPrice(
              trip: {'price': '₹6,599', 'discountedPrice': 5999},
            ),
          ),
        ),
      ),
    );
    expect(find.text('₹6,599'), findsOneWidget);
    expect(find.text('₹5,999'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
