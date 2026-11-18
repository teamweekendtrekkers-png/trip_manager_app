import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/pickup_library.dart';
import '../services/trips_parser.dart';

class PickupLibraryDialog extends StatefulWidget {
  const PickupLibraryDialog({
    super.key,
    required this.entries,
    required this.current,
  });
  final List<PickupLibraryEntry> entries;
  final List<Map<String, dynamic>> current;
  @override
  State<PickupLibraryDialog> createState() => _PickupLibraryDialogState();
}

class _PickupLibraryDialogState extends State<PickupLibraryDialog> {
  final selected = <String>{};
  var query = '';
  var keepDefaults = true;
  List<Map<String, dynamic>> get base => widget.current.isNotEmpty
      ? widget.current
      : keepDefaults
      ? TripsParser.getDefaultPickupPoints()
      : [];

  @override
  Widget build(BuildContext context) {
    final existing = base.map(pickupIdentity).toSet();
    final shown = widget.entries
        .where((entry) => entry.matches(query))
        .toList();
    final byId = {for (final entry in widget.entries) entry.id: entry};
    final chosen = selected
        .where((id) => !existing.contains(id))
        .map((id) => byId[id])
        .whereType<PickupLibraryEntry>()
        .toList();
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Reuse pickup points'),
      content: SizedBox(
        width: 620,
        height: math.min(
          MediaQuery.sizeOf(context).height * .62,
          math.max(
            240.0,
            (140 + (widget.current.isEmpty ? 125 : 0) + shown.length * 130) *
                MediaQuery.textScalerOf(context).scale(16) /
                16,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose points from any trip in pickup order. Review times before publishing.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('pickup-library-search'),
              decoration: const InputDecoration(
                labelText: 'Search place, landmark or trip',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                key: const Key('pickup-library-list'),
                itemCount: shown.length + 1,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  if (index == 0)
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.current.isEmpty)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Keep default pickup points'),
                            subtitle: const Text(
                              'Selected points will be added to the four defaults. Turn off to choose a custom list.',
                            ),
                            value: keepDefaults,
                            onChanged: (value) =>
                                setState(() => keepDefaults = value ?? true),
                          ),

                        if (shown.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'No matching pickup points. Try another place or trip name.',
                            ),
                          ),
                      ],
                    );
                  final entry = shown[index - 1];
                  final alreadyAdded = existing.contains(entry.id);
                  final sources = entry.trips.toList()..sort();
                  return CheckboxListTile(
                    key: ValueKey('pickup-${entry.id}'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(entry.point['name'].toString()),
                    subtitle: Text(
                      [
                        if (entry.point['landmark'].toString().isNotEmpty)
                          entry.point['landmark'].toString(),
                        'Time: ${entry.point['time'].toString().isEmpty ? 'Not set — add for this trip' : entry.point['time']}',
                        if (safePickupMapLink(
                          entry.point['mapLink'],
                        ).isNotEmpty)
                          'Maps link included',
                        if (entry.point['mapLink']
                                .toString()
                                .trim()
                                .isNotEmpty &&
                            safePickupMapLink(entry.point['mapLink']).isEmpty)
                          'Invalid Maps link will be omitted. Add a correct link after copying.',
                        'Used by: ${sources.take(2).join(', ')}${sources.length > 2 ? ' +${sources.length - 2} more' : ''}',
                        if (alreadyAdded) 'Already included in this trip',
                      ].join('\n'),
                    ),
                    value: alreadyAdded || selected.contains(entry.id),
                    onChanged: alreadyAdded
                        ? null
                        : (value) => setState(() {
                            if (value == true) {
                              selected.add(entry.id);
                            } else {
                              selected.remove(entry.id);
                            }
                          }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('pickup-library-add'),
          onPressed: chosen.isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  mergePickupPoints(base, chosen.map((entry) => entry.point)),
                ),
          child: Text(
            'Add ${chosen.length} ${chosen.length == 1 ? 'point' : 'points'}',
          ),
        ),
      ],
    );
  }
}
