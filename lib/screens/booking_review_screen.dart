import '../services/booking_review_filter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/github_service.dart';
import '../services/booking_review_service.dart';

class BookingReviewScreen extends StatefulWidget {
  const BookingReviewScreen({super.key, this.service, this.initialFilter = BookingReviewFilter.all});
  final BookingReviewFilter initialFilter;
  final BookingReviewService? service;
  @override
  State<BookingReviewScreen> createState() => _BookingReviewScreenState();
}

class _BookingReviewScreenState extends State<BookingReviewScreen> {
  late final BookingReviewService service;
  final email = TextEditingController(), password = TextEditingController(), search = TextEditingController();
  List<Map<String, dynamic>> bookings = [];
  String? error;
  bool busy = false;
  int offset = 0;
  BookingReviewFilter filter = BookingReviewFilter.all;
  List<Map<String, dynamic>> get visibleBookings => bookings.where((booking) => matchesBookingReview(booking, filter)).toList();
  @override
  void initState() {
    super.initState();
    filter = widget.initialFilter;
    service = widget.service ?? BookingReviewService(GitHubService(settings: context.read<SettingsProvider>().settings));
  }
  @override
  void dispose() { email.dispose(); password.dispose(); search.dispose(); service.dispose(); super.dispose(); }
  Future<void> _load({int? pageOffset}) async {
    setState(() { busy = true; error = null; });
    try {
      final next = pageOffset ?? offset;
      final rows = await service.load(search: search.text, offset: next);
      if (mounted) setState(() { bookings = rows; offset = next; });
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> _signIn() async {
    setState(() { busy = true; error = null; });
    try {
      await service.signIn(email.text, password.text);
      password.clear();
      if (mounted) await _load(pageOffset: 0);
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Map? _payment(Map booking) => bookingPaymentReport(booking);
  Future<void> _review(Map<String, dynamic> booking, String status) async {
    final note = TextEditingController();
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(status == 'verified' ? 'Mark payment verified?' : status == 'rejected' ? 'Mark payment rejected?' : 'Return payment to pending?'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${booking['booking_reference']} · ${booking['full_name']}'),
        const Text('Verify the actual credit in your bank or UPI account. This records payment review only; trip availability and booking confirmation stay separate.'),
        TextField(controller: note, maxLength: 500, decoration: const InputDecoration(labelText: 'Review note (optional)')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save review'))],
    ));
    final text = note.text; note.dispose();
    if (yes != true || !mounted) return;
    setState(() { busy = true; error = null; });
    try { await service.review(booking, status, text); if (mounted) await _load(); }
    catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bookings & payment review'), actions: [
      if (service.signedIn) TextButton(onPressed: busy ? null : () async {
        setState(() => busy = true); await service.signOut();
        if (mounted) setState(() { bookings = []; busy = false; });
      }, child: const Text('Sign out')),
    ]),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 850), child: ListView(
      padding: const EdgeInsets.all(20), children: [
        if (busy) const LinearProgressIndicator(),
        if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (!service.signedIn) ...[
          const Text('Sign in with your Supabase booking administrator account. Website editing permissions are separate from customer-data access. Your password is not saved.'),
          TextField(controller: email, enabled: !busy, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Administrator email')),
          TextField(controller: password, enabled: !busy, obscureText: true, enableSuggestions: false, autocorrect: false, decoration: const InputDecoration(labelText: 'Password'), onSubmitted: (_) { if (!busy) _signIn(); }),
          const SizedBox(height: 16),
          FilledButton(onPressed: busy ? null : _signIn, child: const Text('Sign in')),
          const SizedBox(height: 16),
          const Text('Initial setup: deploy the booking-review database migration and grant your account trip_manager_admin access in Supabase. See BOOKING_REVIEW_SETUP.md.'),
        ] else ...[
          TextField(controller: search, enabled: !busy, decoration: InputDecoration(labelText: 'Find booking, customer, phone or transaction ID', suffixIcon: IconButton(tooltip: 'Search bookings', onPressed: busy ? null : () => _load(pageOffset: 0), icon: const Icon(Icons.search))), onSubmitted: (_) => _load(pageOffset: 0)),
          TextButton.icon(onPressed: busy ? null : () => _load(), icon: const Icon(Icons.refresh), label: const Text('Refresh bookings')),
          const SizedBox(height: 8),
          const Text('Search covers all bookings. Status filters apply to this page (up to 50 bookings).'),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final option in BookingReviewFilter.values)
              ChoiceChip(label: Text(option.label), selected: filter == option,
                onSelected: busy ? null : (_) => setState(() => filter = option)),
          ]),
          Text('${visibleBookings.length} of ${bookings.length} bookings on this page', key: const Key('booking-results-count')),
          if (search.text.isNotEmpty || filter != BookingReviewFilter.all)
            TextButton.icon(
              key: const Key('clear-booking-filters'),
              onPressed: busy ? null : () {
                setState(() { filter = BookingReviewFilter.all; search.clear(); });
                _load(pageOffset: 0);
              }, icon: const Icon(Icons.filter_alt_off), label: const Text('Clear search & filters')),
          if (visibleBookings.isEmpty && !busy) ListTile(title: const Text('No bookings found'),
            subtitle: Text(bookings.isEmpty ? 'Try a different search.' : 'Choose All or try another page.')),
          for (final booking in visibleBookings) Builder(builder: (_) {
            final report = _payment(booking);
            return Card(child: ExpansionTile(title: Text('${booking['booking_reference']} · ${booking['full_name']}'),
              subtitle: Text('${booking['trip_name']} · ${booking['departure_label']}\n${report == null ? 'Availability request' : 'Payment: ${booking['payment_review_status'] ?? 'pending'}'}'),
              children: [Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SelectableText('Phone: ${booking['phone']}\nEmail: ${booking['email']}\nTravellers: ${booking['travellers']}\nTrip total: ₹${booking['total_amount']}'),
                if (report != null) ...[
                  SelectableText('Amount reported: ₹${report['amount']}\nTransaction ID: ${report['transactionId']}\n${report['type'] == 'half' ? '50% advance' : 'Full payment'}'),
                  if (booking['payment_review_note']?.toString().isNotEmpty == true) Text('Review note: ${booking['payment_review_note']}'),
                  Wrap(spacing: 8, children: [
                    FilledButton(onPressed: busy ? null : () => _review(booking, 'verified'), child: const Text('Mark verified')),
                    OutlinedButton(onPressed: busy ? null : () => _review(booking, 'rejected'), child: const Text('Reject payment')),
                    TextButton(onPressed: busy ? null : () => _review(booking, 'pending'), child: const Text('Return to pending')),
                  ]),
                ],
              ]))],
            ));
          }),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            TextButton(onPressed: busy || offset == 0 ? null : () => _load(pageOffset: offset - 50), child: const Text('Previous')),
            Text('Page ${offset ~/ 50 + 1}'),
            TextButton(onPressed: busy || bookings.length < 50 ? null : () => _load(pageOffset: offset + 50), child: const Text('Next')),
          ]),
        ],
      ],
    ))),
  );
}
