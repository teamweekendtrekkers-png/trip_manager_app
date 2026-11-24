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

enum _ReportView { overview, traffic, daily, checkout }

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late final BookingReviewService service;
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false;
  String? error;
  Map<String, dynamic>? report;
  int days = 30;
  _ReportView view = _ReportView.overview;
  DateTimeRange get period =>
      custom ??
      DateTimeRange(
        start: DateTime(today.year, today.month, today.day - days + 1),
        end: today,
      );
  String trip = '', device = '';
  DateTimeRange? custom;
  DateTime get today {
    final ist = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    return DateTime(ist.year, ist.month, ist.day);
  }

  String date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  @override
  void initState() {
    super.initState();
    service =
        widget.service ??
        BookingReviewService(
          GitHubService(settings: context.read<SettingsProvider>().settings),
        );
    if (service.signedIn)
      WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    service.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (!mounted || busy) return;
    setState(() {
      busy = true;
      error = null;
      report = null;
    });
    try {
      final range = period;
      final value = await service.analytics(
        start: date(range.start),
        end: date(range.end),
        trip: trip,
        device: device,
      );
      if (mounted) setState(() => report = value);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> signIn() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await service.signIn(email.text, password.text);
      password.clear();
      if (mounted) {
        setState(() => busy = false);
        await load();
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<Map<String, dynamic>> rows(String key) => ((report?[key] as List?) ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  int number(Object? v) => v is num ? v.toInt() : 0;
  String percent(int a, int b) =>
      b == 0 ? '—' : '${(100 * a / b).toStringAsFixed(1)}%';
  Widget section(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
  Widget metric(String label, String value) => SizedBox(
    width: 175,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            Text(label),
          ],
        ),
      ),
    ),
  );
  Widget biggestDrop(List<Map<String, dynamic>> funnel) {
    var gap = 0;
    var next = 0;
    for (var i = 1; i < funnel.length; i++) {
      final difference =
          number(funnel[i - 1]['count']) - number(funnel[i]['count']);
      if (difference > gap) {
        gap = difference;
        next = i;
      }
    }
    if (gap == 0) return const SizedBox.shrink();
    final previous = number(funnel[next - 1]['count']);
    return section('Largest drop-off', [
      Text('${funnel[next - 1]['label']} → ${funnel[next]['label']}'),
      Text(
        '$gap of $previous journeys did not reach the next step (${percent(gap, previous)}).',
      ),
    ]);
  }

  Widget dailyActivity(MaterialLocalizations dates) {
    final activity = rows('daily')
      ..sort((a, b) => b['day'].toString().compareTo(a['day'].toString()));
    final peak = activity.fold(0, (int max, row) {
      final sessions = number(row['sessions']);
      return sessions > max ? sessions : max;
    });
    return section('Daily activity', [
      const Text(
        'Sessions and payment detail submissions by date in IST. Dates without tracked activity are omitted.',
      ),
      if (activity.isEmpty) const Text('No activity in this period.'),
      for (final row in activity)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(switch (DateTime.tryParse(row['day'].toString())) {
                final day? => dates.formatMediumDate(day),
                null => row['day'].toString(),
              }),
              Text(
                '${row['sessions']} sessions · ${row['submissions']} submissions',
              ),
              const SizedBox(height: 5),
              LinearProgressIndicator(
                value: peak == 0 ? 0 : number(row['sessions']) / peak,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
                semanticsLabel: 'Sessions relative to the busiest day',
              ),
            ],
          ),
        ),
    ]);
  }

  Future<void> chooseRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: today.subtract(const Duration(days: 89)),
      lastDate: today,
      initialDateRange: period,
    );
    if (range != null && mounted) {
      setState(() => custom = range);
      await load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final funnel = rows('funnel');
    final first = funnel.isEmpty ? 0 : number(funnel.first['count']);
    final last = funnel.isEmpty ? 0 : number(funnel.last['count']);
    final range = period;
    final dateLabels = MaterialLocalizations.of(context);
    final options = <String>{
      trip,
      ...((report?['trip_options'] as List?) ?? []).whereType<String>(),
    }..remove('');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer journey'),
        actions: [
          if (service.signedIn)
            IconButton(
              tooltip: 'Refresh analytics',
              onPressed: busy ? null : load,
              icon: const Icon(Icons.refresh),
            ),
          if (service.signedIn)
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      await service.signOut();
                      if (mounted) setState(() => report = null);
                    },
              child: const Text('Sign out'),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                section('Could not load analytics', [
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : service.signedIn
                        ? load
                        : signIn,
                    child: const Text('Try again'),
                  ),
                ]),
              if (!service.signedIn) ...[
                const Text(
                  'Sign in with your booking administrator account to see aggregate analytics. Your password is not saved.',
                ),
                TextField(
                  controller: email,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Administrator email',
                  ),
                ),
                TextField(
                  controller: password,
                  enabled: !busy,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Password'),
                  onSubmitted: (_) {
                    if (!busy) signIn();
                  },
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy ? null : signIn,
                  child: const Text('Sign in to analytics'),
                ),
              ] else ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 185,
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('period-$days-${custom != null}'),
                        isExpanded: true,
                        initialValue: custom == null ? days : null,
                        hint: const Text('Custom range'),
                        decoration: const InputDecoration(labelText: 'Period'),
                        items: [
                          for (final n in [7, 30, 90])
                            DropdownMenuItem(
                              value: n,
                              child: Text('Last $n days'),
                            ),
                        ],
                        onChanged: busy
                            ? null
                            : (v) {
                                setState(() {
                                  days = v!;
                                  custom = null;
                                });
                                load();
                              },
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : chooseRange,
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        custom == null
                            ? 'Custom dates'
                            : '${date(custom!.start)} – ${date(custom!.end)}',
                      ),
                    ),
                    SizedBox(
                      width: 250,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('trip-$trip-${options.length}'),
                        initialValue: trip,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Trip'),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('All trips'),
                          ),
                          for (final id in options)
                            DropdownMenuItem(
                              value: id,
                              child: Text(
                                id.replaceAll('-', ' '),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: busy
                            ? null
                            : (v) {
                                setState(() => trip = v!);
                                load();
                              },
                      ),
                    ),
                    SizedBox(
                      width: 185,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('device-$device'),
                        isExpanded: true,
                        initialValue: device,
                        decoration: const InputDecoration(labelText: 'Device'),
                        items: [
                          for (final v in ['', 'mobile', 'tablet', 'desktop'])
                            DropdownMenuItem(
                              value: v,
                              child: Text(v.isEmpty ? 'All devices' : v),
                            ),
                        ],
                        onChanged: busy
                            ? null
                            : (v) {
                                setState(() => device = v!);
                                load();
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${dateLabels.formatShortDate(range.start)} – ${dateLabels.formatShortDate(range.end)} · IST',
                ),
                if (trip.isNotEmpty ||
                    device.isNotEmpty ||
                    custom != null ||
                    days != 30)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: busy
                          ? null
                          : () {
                              setState(() {
                                trip = '';
                                device = '';
                                custom = null;
                                days = 30;
                              });
                              load();
                            },
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: const Text('Reset filters'),
                    ),
                  ),
                if (report != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (item, label) in const [
                        (_ReportView.overview, 'Overview'),
                        (_ReportView.traffic, 'Traffic'),
                        (_ReportView.daily, 'By date'),
                        (_ReportView.checkout, 'Checkout & payments'),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: item == view,
                          onSelected: (_) => setState(() => view = item),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (view == _ReportView.overview) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        metric(
                          'Tracked sessions',
                          '${number(report!['sessions'])}',
                        ),
                        metric('Trip journeys', '$first'),
                        metric('Journey → submission', percent(last, first)),
                        metric(
                          'Direct checkout entries',
                          '${number(report!['direct_checkout'])}',
                        ),
                      ],
                    ),
                    if (first == 0 && !busy)
                      section('No tracked trip journeys yet', [
                        const Text(
                          'This is an empty report, not a booking error. New data appears when a visitor views a trip with browser analytics allowed. Try a wider period or clear the filters.',
                        ),
                      ]),
                    if (first > 0) biggestDrop(funnel),
                    if (first > 0)
                      section('Where visitors leave', [
                        const Text(
                          'Ordered funnel: the same session and trip must reach each step in sequence within this period. One session can explore multiple trips. Direct checkout links are counted separately.',
                        ),
                        const SizedBox(height: 12),
                        for (var i = 0; i < funnel.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${i + 1}. ${funnel[i]['label']}',
                                      ),
                                    ),
                                    Text(
                                      '${number(funnel[i]['count'])} · ${percent(number(funnel[i]['count']), first)}',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                  value: (number(funnel[i]['count']) / first)
                                      .clamp(0.0, 1.0)
                                      .toDouble(),
                                  minHeight: 10,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                if (i < funnel.length - 1)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      '${number(funnel[i]['count']) - number(funnel[i + 1]['count'])} have not reached the next step (${percent(number(funnel[i]['count']) - number(funnel[i + 1]['count']), number(funnel[i]['count']))})',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        const Text(
                          'Recent sessions may still be in progress. Leaving this funnel does not prove why someone stopped.',
                        ),
                      ]),
                    section('Trips attracting interest', [
                      for (final row in rows('trips'))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            row['trip_id'].toString().replaceAll('-', ' '),
                          ),
                          subtitle: Text(
                            '${row['views']} journeys · ${row['checkouts']} checkouts · ${row['submissions']} submissions',
                          ),
                          trailing: Text(
                            percent(
                              number(row['submissions']),
                              number(row['views']),
                            ),
                          ),
                        ),
                      if (rows('trips').isEmpty)
                        const Text('No trips in this period.'),
                    ]),
                  ],
                  if (view == _ReportView.traffic) ...[
                    section('Traffic sources', [
                      const Text(
                        'First source within the tracked session. Unknown campaigns are grouped; campaign names and full URLs are not stored.',
                      ),
                      for (final row in rows('sources'))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(row['source'].toString()),
                          subtitle: Text(
                            '${row['sessions']} sessions · ${row['submissions']} submitted payment details',
                          ),
                        ),
                    ]),
                    section('Mobile, tablet and desktop', [
                      const Text(
                        'This comparison includes all devices; the device filter applies to the funnel and other sections.',
                      ),
                      for (final row in rows('devices'))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(row['device'].toString()),
                          subtitle: Text(
                            '${row['sessions']} sessions · ${row['submissions']} submissions',
                          ),
                        ),
                    ]),
                  ],
                  if (view == _ReportView.daily) dailyActivity(dateLabels),
                  if (view == _ReportView.checkout) ...[
                    section('Checkout issues', [
                      for (final row in rows('errors'))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(switch (row['code']) {
                            'qr_failed' => 'QR image did not load',
                            'booking_submit_failed' =>
                              'Booking submission failed',
                            _ => 'Checkout could not continue',
                          }),
                          trailing: Text('${row['sessions']} sessions'),
                        ),
                      if (rows('errors').isEmpty)
                        const Text(
                          'No tracked checkout errors in this period.',
                        ),
                    ]),
                    section('Payment engagement', [
                      Text(
                        '${number((report!['engagement'] as Map?)?['upi_copied'])} sessions clicked Copy UPI ID · ${number((report!['engagement'] as Map?)?['qr_downloaded'])} clicked Download QR',
                      ),
                      Text(
                        '${number(report!['requests'])} sessions submitted an availability request.',
                      ),
                      const Text(
                        'These actions do not prove payment. Only an accepted payment report enters the submission step.',
                      ),
                    ]),
                    section('Team payment review', [
                      if (report!['review'] == null)
                        const Text(
                          'Select All devices to view team review totals. Customer bookings do not store analytics device or session identifiers.',
                        )
                      else ...[
                        const Text(
                          'Actual payment reports created in this date range, including visitors who opted out. Status reflects the latest review. These are separate totals, not an anonymous funnel step.',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(report!['review'] as Map)['submitted']} submitted · ${(report!['review'] as Map)['pending']} pending · ${(report!['review'] as Map)['verified']} verified · ${(report!['review'] as Map)['rejected']} rejected',
                        ),
                        Text(
                          'Average time to latest review: ${(report!['review'] as Map)['average_review_hours'] ?? '—'} hours. Payment verification does not confirm seat availability.',
                        ),
                      ],
                    ]),
                  ],
                  ExpansionTile(
                    title: const Text('How tracking works'),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [
                      Text(
                        'Anonymous totals include sessions where analytics was allowed. Browser blockers can reduce counts. Sessions last up to 24 hours. Tracking began ${report!['launched_at']?.toString().split('T').first ?? 'on an unknown date'}.',
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
