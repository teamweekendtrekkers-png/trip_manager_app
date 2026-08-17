import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/trip_date_utils.dart';

/// A read-only preview of the next website batches.
///
/// [trips] may include edits that have not been published yet. Keeping this
/// screen independent of [TripsProvider] also makes that distinction explicit
/// and lets callers preview the exact in-memory snapshot they are editing.
class UpcomingBatchesScreen extends StatelessWidget {
  const UpcomingBatchesScreen({
    super.key,
    required this.trips,
    this.referenceDate,
  });

  final List<Map<String, dynamic>> trips;
  final DateTime? referenceDate;

  @override
  Widget build(BuildContext context) {
    final batches = TripDateUtils.buildUpcomingBatches(
      trips,
      referenceDate: referenceDate,
      limit: 3,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming Batches'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const _UnsavedDataNotice(),
            const SizedBox(height: 24),
            if (batches.isEmpty)
              const _EmptyBatchesView()
            else ...[
              Text(
                'Next ${batches.length} ${batches.length == 1 ? 'batch' : 'batches'}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final batch in batches) ...[
                _BatchCard(batch: batch),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _UnsavedDataNotice extends StatelessWidget {
  const _UnsavedDataNotice();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      label: 'Unsaved data preview',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.edit_calendar_outlined,
                color: colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unsaved data preview',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Includes your current in-app changes before they are published.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer,
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

class _EmptyBatchesView extends StatelessWidget {
  const _EmptyBatchesView();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      child: Column(
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 20),
          Text(
            'New dates coming soon',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'There are no active trips with current or upcoming dates.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({required this.batch});

  final UpcomingBatch batch;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      key: ValueKey('upcoming-batch-${batch.key}'),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          batch.dateLabel,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          batch.weekdayLabel,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onPrimaryContainer),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (var index = 0; index < batch.trips.length; index++) ...[
            _BatchTripRow(trip: batch.trips[index]),
            if (index != batch.trips.length - 1)
              const Divider(height: 1, indent: 16, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _BatchTripRow extends StatelessWidget {
  const _BatchTripRow({required this.trip});

  final UpcomingBatchTrip trip;

  @override
  Widget build(BuildContext context) {
    final location = trip.location?.trim();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.landscape_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trip.title, style: Theme.of(context).textTheme.titleSmall),
                if (location != null && location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    location,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatPrice(trip.price),
            key: ValueKey('upcoming-batch-price-${trip.id ?? trip.title}'),
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatPrice(dynamic price) {
    if (price == null) return 'Price unavailable';
    if (price is num) {
      return NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: price == price.roundToDouble() ? 0 : 2,
      ).format(price);
    }

    final text = price.toString().trim();
    return text.isEmpty ? 'Price unavailable' : text;
  }
}
