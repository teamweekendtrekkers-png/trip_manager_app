import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/github_service.dart';
import '../services/booking_review_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, this.service});
  final BookingReviewService? service;
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late final BookingReviewService service;
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false;
  String? error;
  Map<String, dynamic>? report;
  int days = 30;
  String trip = '', device = '';
  DateTimeRange? custom;
  DateTime get today {
    final ist = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateTime(ist.year, ist.month, ist.day);
  }
  String date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  @override
  void initState() {
    super.initState();
    service = widget.service ?? BookingReviewService(GitHubService(settings: context.read<SettingsProvider>().settings));
    if (service.signedIn) WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }
  @override
  void dispose() { email.dispose(); password.dispose(); service.dispose(); super.dispose(); }
  Future<void> load() async {
    setState(() { busy = true; error = null; report = null; });
    try {
      final value = await service.analytics(start: date(custom?.start ?? today.subtract(Duration(days: days - 1))), end: date(custom?.end ?? today), trip: trip, device: device);
      if (mounted) setState(() => report = value);
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> signIn() async {
    setState(() { busy = true; error = null; });
    try {
      await service.signIn(email.text, password.text);
      password.clear();
      if (mounted) await load();
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }
  List<Map<String, dynamic>> rows(String key) => ((report?[key] as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  int number(Object? v) => v is num ? v.toInt() : 0;
  String percent(int a, int b) => b == 0 ? '—' : '${(100 * a / b).toStringAsFixed(1)}%';
  Widget section(String title, List<Widget> children) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 12), ...children])));
  Widget metric(String label, String value) => SizedBox(width: 175, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: Theme.of(context).textTheme.headlineMedium), Text(label)]))));
  Future<void> chooseRange() async {
    final range = await showDateRangePicker(context: context, firstDate: today.subtract(const Duration(days: 89)), lastDate: today, initialDateRange: custom ?? DateTimeRange(start: today.subtract(Duration(days: days - 1)), end: today));
    if (range != null && mounted) { setState(() => custom = range); await load(); }
  }
  @override
  Widget build(BuildContext context) {
    final funnel = rows('funnel');
    final first = funnel.isEmpty ? 0 : number(funnel.first['count']);
    final last = funnel.isEmpty ? 0 : number(funnel.last['count']);
    final options = <String>{trip, ...((report?['trip_options'] as List?) ?? []).whereType<String>()}..remove('');
    return Scaffold(
      appBar: AppBar(title: const Text('Customer journey'), actions: [
        if (service.signedIn) IconButton(tooltip: 'Refresh analytics', onPressed: busy ? null : load, icon: const Icon(Icons.refresh)),
        if (service.signedIn) TextButton(onPressed: busy ? null : () async { await service.signOut(); if (mounted) setState(() => report = null); }, child: const Text('Sign out')),
      ]),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1050), child: ListView(padding: const EdgeInsets.all(16), children: [
        if (busy) const LinearProgressIndicator(),
        if (error != null) section('Could not load analytics', [Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)), TextButton(onPressed: busy ? null : service.signedIn ? load : signIn, child: const Text('Try again'))]),
        if (!service.signedIn) ...[
          const Text('Sign in with your booking administrator account to see aggregate analytics. Your password is not saved.'),
          TextField(controller: email, enabled: !busy, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Administrator email')),
          TextField(controller: password, enabled: !busy, obscureText: true, enableSuggestions: false, autocorrect: false, decoration: const InputDecoration(labelText: 'Password'), onSubmitted: (_) { if (!busy) signIn(); }),
          const SizedBox(height: 16), FilledButton(onPressed: busy ? null : signIn, child: const Text('Sign in to analytics')),
        ] else ...[
          Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 185, child: DropdownButtonFormField<int>(initialValue: days, decoration: const InputDecoration(labelText: 'Period'), items: [for (final n in [7, 30, 90]) DropdownMenuItem(value: n, child: Text('Last $n days'))], onChanged: busy ? null : (v) { setState(() { days = v!; custom = null; }); load(); })),
            OutlinedButton.icon(onPressed: busy ? null : chooseRange, icon: const Icon(Icons.date_range), label: Text(custom == null ? 'Custom dates' : '${date(custom!.start)} – ${date(custom!.end)}')),
            SizedBox(width: 250, child: DropdownButtonFormField<String>(key: ValueKey('trip-$trip-${options.length}'), initialValue: trip, isExpanded: true, decoration: const InputDecoration(labelText: 'Trip'), items: [const DropdownMenuItem(value: '', child: Text('All trips')), for (final id in options) DropdownMenuItem(value: id, child: Text(id.replaceAll('-', ' '), overflow: TextOverflow.ellipsis))], onChanged: busy ? null : (v) { setState(() => trip = v!); load(); })),
            SizedBox(width: 185, child: DropdownButtonFormField<String>(initialValue: device, decoration: const InputDecoration(labelText: 'Device'), items: [for (final v in ['', 'mobile', 'tablet', 'desktop']) DropdownMenuItem(value: v, child: Text(v.isEmpty ? 'All devices' : v))], onChanged: busy ? null : (v) { setState(() => device = v!); load(); })),
          ]),
          const SizedBox(height: 12),
          const Text('Dates use India time (IST). Anonymous analytics covers consenting sessions only. Browser blockers and privacy preferences can reduce counts. A session lasts up to 24 hours. This is directional data, not a visitor census.'),
          if (report != null) ...[
            Text('Tracking enabled: ${report!['launched_at']?.toString().split('T').first ?? '—'} · No historical backfill'),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [metric('Tracked sessions', '${number(report!['sessions'])}'), metric('Trip journeys', '$first'), metric('Journey → submission', percent(last, first)), metric('Direct checkout entries', '${number(report!['direct_checkout'])}')]),
            if (first == 0 && !busy) section('No tracked trip journeys yet', [const Text('This is an empty report, not a booking error. New data appears when a visitor allows analytics and views a trip. Try a wider period or clear the filters.')]),
            section('Where visitors leave', [
              const Text('Ordered funnel: the same session and trip must reach each step in sequence within this period. One session can explore multiple trips. Direct checkout links are counted separately.'),
              const SizedBox(height: 12),
              for (var i = 0; i < funnel.length; i++) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [Expanded(child: Text('${i + 1}. ${funnel[i]['label']}')), Text('${number(funnel[i]['count'])} · ${percent(number(funnel[i]['count']), first)}')]),
                const SizedBox(height: 6), LinearProgressIndicator(value: first == 0 ? 0 : number(funnel[i]['count']) / first, minHeight: 10, borderRadius: BorderRadius.circular(5)),
                if (i < funnel.length - 1) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${number(funnel[i]['count']) - number(funnel[i + 1]['count'])} have not reached the next step (${percent(number(funnel[i]['count']) - number(funnel[i + 1]['count']), number(funnel[i]['count']))})')),
              ])),
              const Text('Recent sessions may still be in progress. Leaving this funnel does not prove why someone stopped.'),
            ]),
            section('Trips attracting interest', [for (final row in rows('trips')) ListTile(contentPadding: EdgeInsets.zero, title: Text(row['trip_id'].toString().replaceAll('-', ' ')), subtitle: Text('${row['views']} journeys · ${row['checkouts']} checkouts · ${row['submissions']} submissions'), trailing: Text(percent(number(row['submissions']), number(row['views'])))), if (rows('trips').isEmpty) const Text('No trips in this period.')]),
            section('Traffic sources', [const Text('First source within the tracked session. Unknown campaigns are grouped; campaign names and full URLs are not stored.'), for (final row in rows('sources')) ListTile(contentPadding: EdgeInsets.zero, title: Text(row['source'].toString()), subtitle: Text('${row['sessions']} sessions · ${row['submissions']} submitted payment details'))]),
            section('Mobile, tablet and desktop', [const Text('This comparison includes all devices; the device filter applies to the funnel and other sections.'), for (final row in rows('devices')) ListTile(contentPadding: EdgeInsets.zero, title: Text(row['device'].toString()), subtitle: Text('${row['sessions']} sessions · ${row['submissions']} submissions'))]),
            section('Daily activity', [const Text('Compare sessions and submissions across the selected dates. Days with no events are omitted.'), for (final row in rows('daily')) ListTile(contentPadding: EdgeInsets.zero, title: Text(row['day'].toString()), subtitle: Text('${row['sessions']} sessions · ${row['submissions']} submissions')), if (rows('daily').isEmpty) const Text('No activity yet.')]),
            section('Checkout issues', [for (final row in rows('errors')) ListTile(contentPadding: EdgeInsets.zero, title: Text(switch (row['code']) { 'qr_failed' => 'QR image did not load', 'booking_submit_failed' => 'Booking submission failed', _ => 'Checkout could not continue' }), trailing: Text('${row['sessions']} sessions')), if (rows('errors').isEmpty) const Text('No tracked checkout errors in this period.')]),
            section('Payment engagement', [
              Text('${number((report!['engagement'] as Map?)?['upi_copied'])} sessions clicked Copy UPI ID · ${number((report!['engagement'] as Map?)?['qr_downloaded'])} clicked Download QR'),
              Text('${number(report!['requests'])} sessions submitted an availability request.'),
              const Text('These actions do not prove payment. Only an accepted payment report enters the submission step.'),
            ]),
            section('Team payment review', [
              if (report!['review'] == null) const Text('Select All devices to view team review totals. Customer bookings do not store analytics device or session identifiers.') else ...[
                const Text('Actual payment reports created in this date range, including visitors who declined analytics. Status reflects the latest review. These are separate totals, not an anonymous funnel step.'), const SizedBox(height: 8),
                Text('${(report!['review'] as Map)['submitted']} submitted · ${(report!['review'] as Map)['pending']} pending · ${(report!['review'] as Map)['verified']} verified · ${(report!['review'] as Map)['rejected']} rejected'),
                Text('Average time to latest review: ${(report!['review'] as Map)['average_review_hours'] ?? '—'} hours. Payment verification does not confirm seat availability.'),
              ],
            ]),
          ],
        ],
      ]))),
    );
  }
}
