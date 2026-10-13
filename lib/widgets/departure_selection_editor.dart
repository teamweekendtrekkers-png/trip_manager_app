import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/homepage_config.dart';
import '../services/trip_date_utils.dart';

class DepartureSelectionEditor extends StatelessWidget {
  const DepartureSelectionEditor({
    super.key,
    required this.draft,
    required this.trips,
    required this.onChanged,
    this.referenceDate,
  });
  final Map<String, dynamic> draft;
  final List<Map<String, dynamic>> trips;
  final VoidCallback onChanged;
  final DateTime? referenceDate;
  @override
  Widget build(BuildContext context) {
    final options = draft['upcomingBatches'] as Map,
        ids = options['tripIds'] as List,
        selected = options['departures'] as List;
    final cfg = HomepageConfig.parse(
          jsonEncode({
            ...HomepageConfig.initial().toJson(),
            'upcomingBatches': draft['upcomingBatches'],
          }),
        ),
        eligible = cfg.selectedTrips(trips, referenceDate: referenceDate);
    final batches = options['enabled'] == false
        ? <UpcomingBatch>[]
        : TripDateUtils.buildUpcomingBatches(
            eligible,
            referenceDate: referenceDate,
            limit: 1000000,
          );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Upcoming Batches selection',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Only eligible dates from your selected trips and departures appear on the website. All selected dates can be browsed by swiping.',
            ),
            DropdownButtonFormField<String>(
              key: const Key('homepage-trip-selection'),
              isExpanded: true,
              initialValue: options['tripSelection'] as String,
              decoration: const InputDecoration(labelText: 'Which trips?'),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('All eligible trips'),
                ),
                DropdownMenuItem(
                  value: 'selected',
                  child: Text('Only selected trips'),
                ),
              ],
              onChanged: (v) {
                options['tripSelection'] = v;
                onChanged();
              },
            ),
            DropdownButtonFormField<String>(
              key: const Key('homepage-date-selection'),
              isExpanded: true,
              initialValue: options['departureSelection'] as String,
              decoration: const InputDecoration(
                labelText: 'Which departure dates?',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('All eligible dates from those trips'),
                ),
                DropdownMenuItem(
                  value: 'selected',
                  child: Text('Only selected departure dates'),
                ),
              ],
              onChanged: (v) {
                options['departureSelection'] = v;
                onChanged();
              },
            ),
            for (final trip in trips)
              ExpansionTile(
                key: ValueKey('selection-trip-${trip['id']}'),
                title: Text(trip['title']?.toString() ?? trip['id'].toString()),
                subtitle: Text(
                  trip['isActive'] == false
                      ? 'Inactive: hidden from website'
                      : options['tripSelection'] == 'selected' &&
                            !ids.contains(trip['id'])
                      ? 'Not selected for Upcoming Batches'
                      : 'Eligible trip',
                ),
                children: [
                  if (options['tripSelection'] == 'selected')
                    CheckboxListTile(
                      key: ValueKey('homepage-trip-${trip['id']}'),
                      title: const Text(
                        'Select this trip for Upcoming Batches',
                      ),
                      value: ids.contains(trip['id']),
                      onChanged: (v) {
                        ids.remove(trip['id']);
                        if (v == true) ids.add(trip['id']);
                        onChanged();
                      },
                    ),
                  if (options['departureSelection'] == 'selected')
                    for (final label in (trip['availableDates'] as List? ?? []))
                      Builder(
                        builder: (context) {
                          final range = TripDateUtils.parse(label.toString());
                          final eligibleDate =
                              TripDateUtils.getUpcomingDateRanges(
                                trip,
                                referenceDate: referenceDate,
                              ).any((r) => r.key == range?.key);
                          bool matches(Object? item) =>
                              item is Map &&
                              item['tripId'] == trip['id'] &&
                              TripDateUtils.parse(
                                    item['date'].toString(),
                                  )?.key ==
                                  range?.key;
                          return CheckboxListTile(
                            key: ValueKey(
                              'homepage-departure-${trip['id']}|${range?.key}',
                            ),
                            title: Text(label.toString()),
                            subtitle: Text(
                              eligibleDate
                                  ? 'Bookable departure'
                                  : 'Closed, inactive or invalid: will not appear',
                            ),
                            value: selected.any(matches),
                            onChanged: range == null
                                ? null
                                : (v) {
                                    selected.removeWhere(matches);
                                    if (v == true)
                                      selected.add({
                                        'tripId': trip['id'],
                                        'date': label,
                                      });
                                    onChanged();
                                  },
                          );
                        },
                      ),
                  if ((trip['availableDates'] as List? ?? []).isEmpty)
                    const ListTile(
                      title: Text(
                        'No departure dates. Add dates in Trips → Dates & price.',
                      ),
                    ),
                ],
              ),
            for (final id in ids.where(
              (id) => !trips.any((t) => t['id'] == id),
            ))
              ListTile(
                title: Text('Missing trip: $id'),
                trailing: IconButton(
                  tooltip: 'Remove missing selection',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    ids.remove(id);
                    onChanged();
                  },
                ),
              ),
            Column(
              key: const Key('homepage-selection-preview'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(),
                Text(
                  'Website selection preview · ${batches.fold<int>(0, (n, b) => n + b.trips.length)} departures',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (batches.isEmpty)
                  const Text(
                    'No bookable departures match these selections. Check visibility, trip choices, date choices and booking cutoffs.',
                  ),
                for (final batch in batches)
                  for (final trip in batch.trips)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.event),
                      title: Text(trip.title),
                      subtitle: Text(batch.dateLabel),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
