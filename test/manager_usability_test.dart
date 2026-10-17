import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/screens/booking_review_screen.dart';
import 'package:trip_manager_app/services/booking_review_filter.dart';
import 'package:trip_manager_app/services/booking_review_service.dart';
import 'package:trip_manager_app/services/github_service.dart';
import 'package:trip_manager_app/services/trip_attention.dart';
import 'package:trip_manager_app/widgets/manager_setup_checklist.dart';
import 'package:trip_manager_app/widgets/publishing_progress.dart';

Map<String, dynamic> payment(String status) => {
  'booking_reference': 'TEST-$status', 'full_name': 'Test Customer',
  'trip_name': 'Test Trip', 'departure_label': 'Jan 1, 2099',
  'special_requests': '[TWT_PAYMENT:{"amount":100,"transactionId":"TEST123","type":"full"}]\n',
  'payment_review_status': status,
};

class ReviewFixture extends BookingReviewService {
  ReviewFixture() : super(GitHubService(settings: AppSettings()));
  final offsets = <int>[];
  @override bool get signedIn => true;
  @override Future<List<Map<String, dynamic>>> load({String search = '', int offset = 0}) async {
    offsets.add(offset);
    return [payment('pending'), for (var i = 0; i < 49; i++) payment('verified')];
  }
}

void main() {
  test('attention checks active trips without modifying data', () {
    final trip = <String, dynamic>{'isActive': true, 'price': '', 'image': '', 'availableDates': <String>[]};
    expect(tripAttention(trip, now: DateTime(2030)), ['Add upcoming dates', 'Check price', 'Add a cover photo']);
    expect(trip['price'], '');
    expect(trip['availableDates'], isEmpty);
    expect(tripAttention({...trip, 'isActive': false}, now: DateTime(2030)), isEmpty);
    expect(tripAttention({...trip, 'price': '₹1,000', 'availableDates': ['Jan 1-2, 2099'], 'cardImage': 'images/trips/test.jpg'}, now: DateTime(2030)), isEmpty);
    expect(tripAttention({...trip, 'price': '₹0'}, now: DateTime(2030)), contains('Check price'));
  });

  test('payment filters keep availability requests out of pending payments', () {
    final request = <String, dynamic>{'special_requests': 'Window seat', 'payment_review_status': 'pending'};
    expect(matchesBookingReview(request, BookingReviewFilter.requests), isTrue);
    expect(matchesBookingReview(request, BookingReviewFilter.pending), isFalse);
    for (final filter in [BookingReviewFilter.pending, BookingReviewFilter.verified, BookingReviewFilter.rejected]) {
      expect(matchesBookingReview(payment(filter.name), filter), isTrue);
      expect(matchesBookingReview(payment(filter.name), BookingReviewFilter.requests), isFalse);
    }
    expect(bookingPaymentReport({'special_requests':'[TWT_PAYMENT:invalid]\n'}), isNull);
    expect(matchesBookingReview(payment('verified'), BookingReviewFilter.pending), isFalse);
  });

  testWidgets('setup checklist explains and opens each next step on a phone', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var action = '';
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: ManagerSetupChecklist(
      configured: false, hasTrips: false, hasPublished: false,
      onConnection: () => action = 'connect', onTrips: () => action = 'trips',
      onPayments: () => action = 'payments', onPublish: () => action = 'publish',
    )))));
    await tester.pumpAndSettle();
    for (final step in {'1. Save connection details':'connect', '2. Load and edit trips':'trips',
      '3. Check UPI and coupons':'payments', '4. Review and publish':'publish'}.entries) {
      await tester.ensureVisible(find.text(step.key));
      await tester.tap(find.text(step.key));
      expect(action, step.value);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('publishing progress does not mark Live before deployment', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PublishingProgress(live: false, running: true))));
    final liveChip = tester.widget<Chip>(find.ancestor(of: find.text('Live'), matching: find.byType(Chip)));
    expect((liveChip.avatar as Icon).icon, Icons.radio_button_unchecked);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PublishingProgress(live: true, running: false))));
    final completed = tester.widget<Chip>(find.ancestor(of: find.text('Live'), matching: find.byType(Chip)));
    expect((completed.avatar as Icon).icon, Icons.check_circle_outline);
  });

  testWidgets('booking filter preserves server pagination and clear resets to page one', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = ReviewFixture();
    await tester.pumpWidget(MaterialApp(home: BookingReviewScreen(service: service)));
    await tester.tap(find.text('Refresh bookings'));
    await tester.pumpAndSettle();
    expect(find.text('50 of 50 bookings on this page'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Pending'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 50 bookings on this page'), findsOneWidget);
    expect(service.offsets, [0]);
    await tester.ensureVisible(find.text('Next'));
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Next')).onPressed, isNotNull);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(service.offsets, [0, 50]);
    expect(find.text('Page 2'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('clear-booking-filters')));
    await tester.tap(find.byKey(const Key('clear-booking-filters')));
    await tester.pumpAndSettle();
    expect(service.offsets, [0, 50, 0]);
    expect(find.text('50 of 50 bookings on this page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
