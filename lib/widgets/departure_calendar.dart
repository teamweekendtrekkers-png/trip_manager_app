import 'package:flutter/material.dart';
import '../services/trip_date_utils.dart';
import '../services/departure_status.dart';

/// A date-first view over the same authored departures used by the website.
class DepartureCalendar extends StatefulWidget {
  const DepartureCalendar({
    super.key,
    required this.trips,
    required this.onStatus,
    this.referenceDate,
    this.enabled = true,
  });
  final List<Map<String, dynamic>> trips;
  final void Function(String tripId, String key, String status) onStatus;
  final DateTime? referenceDate;
  final bool enabled;
  @override
  State<DepartureCalendar> createState() => _DepartureCalendarState();
}

class _DepartureCalendarState extends State<DepartureCalendar> {
  late DateTime _month;
  DateTime? _selected;
  @override
  void initState() {
    super.initState();
    final today = TripDateUtils.indiaToday(widget.referenceDate);
    _month = DateTime.utc(today.year, today.month);
  }

  @override
  Widget build(BuildContext context) {
    final entries = <({Map<String, dynamic> trip, TripDateRange range})>[];
    for (final trip in widget.trips) {
      if (trip['isActive'] == false) continue;
      for (final label in trip['availableDates'] as List? ?? []) {
        final range = TripDateUtils.parse(label.toString());
        if (range != null &&
            !range.isExpired(widget.referenceDate) &&
            !entries.any(
              (item) =>
                  item.trip['id'] == trip['id'] && item.range.key == range.key,
            )) {
          entries.add((trip: trip, range: range));
        }
      }
    }
    entries.sort((a, b) => a.range.start.compareTo(b.range.start));
    final visible = entries
        .where(
          (item) =>
              item.range.start.year == _month.year &&
              item.range.start.month == _month.month,
        )
        .toList();
    final selected =
        visible.where((item) => item.range.start == _selected).isNotEmpty
        ? _selected
        : visible.firstOrNull?.range.start;
    final offset = _month.weekday - 1;
    final days = DateTime.utc(_month.year, _month.month + 1, 0).day;
    final localizations = MaterialLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: () => setState(() {
                    _month = DateTime.utc(_month.year, _month.month - 1);
                    _selected = null;
                  }),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    localizations.formatMonthYear(_month),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed: () => setState(() {
                    _month = DateTime.utc(_month.year, _month.month + 1);
                    _selected = null;
                  }),
                  icon: const Icon(Icons.chevron_right),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    final today = TripDateUtils.indiaToday(
                      widget.referenceDate,
                    );
                    _month = DateTime.utc(today.year, today.month);
                    _selected = null;
                  }),
                  child: const Text('Today'),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Select a highlighted departure day. Status edits stay in your draft until you publish.',
              ),
            ),
            Row(
              children: [
                for (final label in [
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                  'Sat',
                  'Sun',
                ])
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
            for (var row = 0; row < (offset + days + 6) ~/ 7; row++)
              Row(
                children: [
                  for (var column = 0; column < 7; column++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final day = row * 7 + column - offset + 1;
                          if (day < 1 || day > days) {
                            return const SizedBox(height: 52);
                          }
                          final date = DateTime.utc(
                                _month.year,
                                _month.month,
                                day,
                              ),
                              count = visible
                                  .where((item) => item.range.start == date)
                                  .length;
                          return Padding(
                            padding: const EdgeInsets.all(2),
                            child: Semantics(
                              selected: date == selected,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                  padding: EdgeInsets.zero,
                                  backgroundColor: date == selected
                                      ? Theme.of(context).colorScheme.primary
                                      : count > 0
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer
                                      : null,
                                  foregroundColor: date == selected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : null,
                                ),
                                onPressed: count == 0
                                    ? null
                                    : () => setState(() => _selected = date),
                                child: Column(
                                  children: [
                                    Text('$day'),
                                    if (count > 0)
                                      Text(
                                        '$count trips',
                                        style: const TextStyle(fontSize: 9),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No departures this month. Browse another month or use Bulk date edit to add dates.',
                ),
              ),
            for (final item in visible.where(
              (item) => item.range.start == selected,
            ))
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(
                  item.trip['title']?.toString() ?? item.trip['id'].toString(),
                ),
                subtitle: Text(
                  '${item.range.fullLabel}\n${_statusLabel(departureStatus(item.trip, item.range.key))}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  enabled: widget.enabled,
                  tooltip: 'Change departure status',
                  onSelected: (status) => widget.onStatus(
                    item.trip['id'].toString(),
                    item.range.key,
                    status,
                  ),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'available',
                      child: Text('Available to book'),
                    ),
                    PopupMenuItem(
                      value: 'confirmed',
                      child: Text('Confirmed departure'),
                    ),
                    PopupMenuItem(value: 'sold-out', child: Text('Sold out')),
                    PopupMenuItem(
                      value: 'closed',
                      child: Text('Bookings closed'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
    'sold-out' => 'Sold out',
    'closed' => 'Bookings closed',
    'confirmed' => 'Confirmed departure',
    _ => 'Available to book',
  };
}
