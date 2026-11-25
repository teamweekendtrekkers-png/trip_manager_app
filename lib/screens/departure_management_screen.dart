import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/trip_pricing.dart';
import '../services/booking_review_filter.dart';
import 'booking_review_screen.dart';
import 'package:provider/provider.dart';
import '../providers/trips_provider.dart';
import '../services/trip_date_utils.dart';
import '../services/departure_status.dart';
import '../widgets/departure_tools.dart';
import '../widgets/departure_calendar.dart';
import 'manager_tools_screen.dart' show bulkDates;

class DepartureManagementScreen extends StatefulWidget {
  const DepartureManagementScreen({super.key, this.tripId});
  final String? tripId;
  @override
  State<DepartureManagementScreen> createState() =>
      _DepartureManagementScreenState();
}

class _DepartureManagementScreenState extends State<DepartureManagementScreen> {
  String _query = '';
  Future<void> _duplicate(
    BuildContext context,
    TripsProvider provider,
    String id,
    String label,
  ) async {
    final scope = provider.draftScope;
    final range = TripDateUtils.parse(label);
    if (range == null) return;
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2199, 12, 31),
      initialDateRange: DateTimeRange(
        start: DateTime(range.start.year, range.start.month, range.start.day),
        end: DateTime(range.end.year, range.end.month, range.end.day),
      ),
      helpText: 'Choose dates for the new departure',
    );
    if (selected == null || !context.mounted) return;
    if (scope != provider.draftScope || provider.isLoading) return;
    final current = provider.getTripById(id);
    if (current == null) return;
    final date = TripDateUtils.fromDates(selected.start, selected.end);
    if ((current['availableDates'] as List? ?? []).any(
      (label) => TripDateUtils.parse(label.toString())?.key == date.key,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That departure already exists.')),
      );
      return;
    }
    provider.applyBulkDates({id}, TripDateUtils.formatCanonical(date));
    await provider.flushDraft();
  }

  Future<void> _openDeparture(
    Map<String, dynamic> trip,
    Map<String, dynamic>? published,
    String label,
  ) async {
    final range = TripDateUtils.parse(label);
    if (range == null) return;
    final special = (trip['departurePricing'] as Map?)?[range.key] as Map?;
    final draftFare =
        TripPricing.amount(special?['price']) ?? TripPricing.selling(trip);
    final publishedSpecial =
        (published?['departurePricing'] as Map?)?[range.key] as Map?;
    final publishedFare =
        TripPricing.amount(publishedSpecial?['price']) ??
        (published == null ? null : TripPricing.selling(published));
    final stops = (trip['boardingLocations'] as List? ?? [])
        .whereType<Map>()
        .map((stop) => stop['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
    final publishedDates = (published?['availableDates'] as List? ?? []).map(
      (value) => value.toString(),
    );
    final liveDate = publishedDates
        .where((value) => TripDateUtils.parse(value)?.key == range.key)
        .firstOrNull;
    final slug = (published?['publicSlug'] ?? published?['id'])?.toString();
    final link = slug == null || liveDate == null
        ? null
        : Uri(
            scheme: 'https',
            host: 'www.teamweekendtrekkers.com',
            pathSegments: ['trips', slug, ''],
            queryParameters: {'date': liveDate},
            fragment: 'bookingCard',
          );
    final status = departureStatus(trip, range.key).replaceAll('-', ' ');
    final previousStatus = published != null && liveDate != null
        ? departureStatus(published, range.key).replaceAll('-', ' ')
        : null;
    String fare(num? price) =>
        price == null ? 'Fare unavailable' : TripPricing.money(price);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(label),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Draft: ${fare(draftFare)} per person · $status'),
              if (previousStatus != null)
                Text(
                  'Published: ${fare(publishedFare)} per person · $previousStatus',
                )
              else
                const Text('This departure is still a draft.'),
              if (special?['note'] != null) Text(special!['note'].toString()),
              const SizedBox(height: 8),
              Text(
                stops.isEmpty
                    ? 'No trip-specific pickup points'
                    : 'Pickup points: ${stops.join(', ')}',
              ),
              if (link != null) ...[
                const SizedBox(height: 8),
                SelectableText(link.toString()),
                TextButton.icon(
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy departure link'),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: link.toString()),
                    );
                    if (dialogContext.mounted)
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Departure link copied')),
                      );
                  },
                ),
              ],
              if (liveDate != null)
                TextButton.icon(
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Review bookings for this date'),
                  onPressed: () => Navigator.of(dialogContext).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BookingReviewScreen(
                        tripId: trip['id'].toString(),
                        departure: range.key.split('/').first,
                        initialFilter: BookingReviewFilter.all,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripsProvider>();
    final published = {for (final trip in provider.baseTrips) trip['id']: trip};
    return Scaffold(
      appBar: AppBar(title: const Text('Manage departures')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Confirm a departure only when it will run. Marking sold out closes new bookings. Changes stay in your draft until you publish.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: provider.isLoading
                    ? null
                    : () => bulkDates(context, provider),
                icon: const Icon(Icons.edit_calendar),
                label: const Text('Bulk date edit'),
              ),
              ExpansionTile(
                initiallyExpanded: true,
                title: const Text('Departure calendar'),
                subtitle: const Text('Browse by date and update availability'),
                children: [
                  DepartureCalendar(
                    trips: provider.trips,
                    enabled: !provider.isLoading,
                    onStatus: (id, key, status) async {
                      final index = provider.getTripIndexById(id);
                      if (index == null || provider.isLoading) return;
                      provider.updateTrip(
                        index,
                        setDepartureStatus(provider.trips[index], key, status),
                      );
                      await provider.flushDraft();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Find a trip to manage',
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Trip name or destination',
                ),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
              if (provider.isLoading) const LinearProgressIndicator(),
              if (provider.trips.isEmpty)
                const ListTile(
                  title: Text('Load trips before managing departures.'),
                ),
              if (provider.trips.isNotEmpty &&
                  !provider.trips.any(
                    (trip) => '${trip['title']} ${trip['location']}'
                        .toLowerCase()
                        .contains(_query),
                  ))
                const ListTile(
                  title: Text(
                    'No matching trips. Try another name or destination.',
                  ),
                ),
              for (final trip in provider.trips.where(
                (trip) =>
                    (widget.tripId == null || widget.tripId == trip['id']) &&
                    '${trip['title']} ${trip['location']}'
                        .toLowerCase()
                        .contains(_query),
              ))
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        title: Text(
                          trip['title']?.toString() ?? trip['id'].toString(),
                        ),
                        subtitle: Text(
                          trip['isActive'] == false
                              ? 'Inactive trip'
                              : '${TripDateUtils.getUpcomingDateRanges(trip).length} bookable departures',
                        ),
                      ),
                      for (final label
                          in (trip['availableDates'] as List? ?? [])
                              .whereType<String>())
                        ListTile(
                          title: Text(label),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openDeparture(
                            trip,
                            published[trip['id']],
                            label,
                          ),
                        ),
                      if ((trip['availableDates'] as List? ?? []).isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'New dates coming soon. Add dates from Trips or Bulk date edit.',
                          ),
                        )
                      else
                        AbsorbPointer(
                          absorbing: provider.isLoading,
                          child: DepartureTools(
                            dates: List<String>.from(trip['availableDates']),
                            closedKeys: List<String>.from(
                              trip['closedDepartures'] as List? ?? [],
                            ),
                            confirmedKeys: List<String>.from(
                              trip['confirmedDepartures'] as List? ?? [],
                            ),
                            soldOutKeys: List<String>.from(
                              trip['soldOutDepartures'] as List? ?? [],
                            ),
                            onStatus: (key, status) async {
                              final index = provider.getTripIndexById(
                                trip['id'].toString(),
                              );
                              if (index == null || provider.isLoading) return;
                              provider.updateTrip(
                                index,
                                setDepartureStatus(
                                  provider.trips[index],
                                  key,
                                  status,
                                ),
                              );
                              await provider.flushDraft();
                            },
                            onToggle: (key) async {
                              final id = trip['id'].toString(),
                                  index = provider.trips.indexWhere(
                                    (t) => t['id'] == id,
                                  );
                              if (index < 0 || provider.isLoading) return;
                              final draft = Map<String, dynamic>.from(
                                provider.trips[index],
                              );
                              final closed = List<String>.from(
                                draft['closedDepartures'] as List? ?? [],
                              );
                              if (!closed.remove(key)) {
                                closed.add(key);
                              } else {
                                draft['soldOutDepartures'] = List<String>.from(
                                  draft['soldOutDepartures'] as List? ?? [],
                                )..remove(key);
                              }
                              draft['closedDepartures'] = closed;
                              provider.updateTrip(index, draft);
                              await provider.flushDraft();
                            },
                            onDuplicate: (index) => _duplicate(
                              context,
                              provider,
                              trip['id'].toString(),
                              trip['availableDates'][index].toString(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
