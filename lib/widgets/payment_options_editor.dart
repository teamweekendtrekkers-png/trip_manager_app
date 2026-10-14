import 'package:flutter/material.dart';
import '../services/trip_date_utils.dart';

class PaymentOptionsEditor extends StatelessWidget {
  const PaymentOptionsEditor({
    super.key,
    required this.payment,
    required this.trips,
    required this.onChanged,
    this.busy = false,
    this.referenceDate,
  });
  final Map<String, dynamic> payment;
  final List<Map<String, dynamic>> trips;
  final VoidCallback onChanged;
  final bool busy;
  final DateTime? referenceDate;
  @override
  Widget build(BuildContext context) {
    final selections = payment['directDepartures'] as List;
    final available = <String>{};
    final rows = <Widget>[];
    for (final trip in trips) {
      final ranges = TripDateUtils.getUpcomingDateRanges(
        trip,
        referenceDate: referenceDate,
      );
      if (ranges.isEmpty) continue;
      rows.add(
        ExpansionTile(
          key: ValueKey('payment-trip-${trip['id']}'),
          title: Text(trip['title']?.toString() ?? trip['id'].toString()),
          subtitle: Text('${ranges.length} bookable departures'),
          children: [
            for (final date in ranges)
              Builder(
                builder: (context) {
                  final id = trip['id'].toString(), key = '$id|${date.key}';
                  available.add(key);
                  final selected = selections.any(
                    (s) => s['tripId'] == id && s['dateKey'] == date.key,
                  );
                  return CheckboxListTile(
                    key: ValueKey('payment-departure-$key'),
                    title: Text(date.originalLabel),
                    value: selected,
                    onChanged: busy
                        ? null
                        : (value) {
                            selections.removeWhere(
                              (s) =>
                                  s['tripId'] == id && s['dateKey'] == date.key,
                            );
                            if (value == true)
                              selections.add({
                                'tripId': id,
                                'dateKey': date.key,
                              });
                            onChanged();
                          },
                  );
                },
              ),
          ],
        ),
      );
      for (final date in ranges) available.add('${trip['id']}|${date.key}');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: const Key('payment-mode'),
          initialValue: payment['mode'] as String,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Payment mode',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: 'confirmation',
              child: Text('Pay after confirmation'),
            ),
            DropdownMenuItem(value: 'direct', child: Text('Pay directly')),
            DropdownMenuItem(value: 'both', child: Text('Offer both options')),
          ],
          onChanged: busy
              ? null
              : (value) {
                  payment['mode'] = value;
                  onChanged();
                },
        ),
        const SizedBox(height: 12),
        const Text(
          'UPI payments remain manually verified. Direct payment never guarantees a seat. Departures without direct-payment approval keep the request-first flow.',
        ),
        if (payment['mode'] != 'confirmation') ...[
          ExpansionTile(
            key: const Key('payment-eligibility'),
            title: const Text('Approve direct-payment departures'),
            subtitle: Text(
              '${selections.length} selected · choose trips and dates',
            ),
            children: [
              if (rows.isEmpty)
                const ListTile(
                  title: Text(
                    'Load active trips with bookable dates before choosing departures.',
                  ),
                ),
              ...rows,
              for (final selected
                  in selections
                      .where(
                        (s) => !available.contains(
                          '${s['tripId']}|${s['dateKey']}',
                        ),
                      )
                      .toList())
                ListTile(
                  title: Text('${selected['tripId']} · ${selected['dateKey']}'),
                  subtitle: const Text(
                    'Missing, inactive or past its booking cutoff; direct payment stays unavailable.',
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove approval',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: busy
                        ? null
                        : () {
                            selections.remove(selected);
                            onChanged();
                          },
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
