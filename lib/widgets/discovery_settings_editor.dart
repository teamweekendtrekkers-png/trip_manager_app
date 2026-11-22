import 'package:flutter/material.dart';

class DiscoverySettingsEditor extends StatelessWidget {
  const DiscoverySettingsEditor({
    super.key,
    required this.discovery,
    required this.onChanged,
  });
  final Map<String, dynamic> discovery;
  final void Function(String field, bool value) onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trip discovery', style: Theme.of(context).textTheme.titleLarge),
          const Text(
            'Help visitors find trips by destination, experience and departure date. Existing homepage trip and departure selections still apply.',
          ),
          for (final entry in const {
            'enabled': 'Show trip discovery controls',
            'showSearch': 'Destination / trip search',
            'showExperienceFilter': 'Experience categories',
            'showTripTypeFilter': 'Show trip type filters',
            'showWeekendFilter': 'Upcoming weekend / date filter',
            'hideComingSoonTrips': 'Hide Coming soon trips',
          }.entries)
            SwitchListTile(
              key: ValueKey('homepage-discovery-${entry.key}'),
              contentPadding: EdgeInsets.zero,
              title: Text(entry.value),
              subtitle: switch (entry.key) {
                'showTripTypeFilter' => const Text(
                  'Show the Trip type row on the All Trips page.',
                ),
                'hideComingSoonTrips' => const Text(
                  'Hide Coming soon and New dates coming soon cards from Explore Destinations, search and All Trips.',
                ),
                _ => null,
              },
              value: discovery[entry.key] == true,
              onChanged:
                  entry.key == 'enabled' ||
                      entry.key == 'showTripTypeFilter' ||
                      entry.key == 'hideComingSoonTrips' ||
                      discovery['enabled'] == true
                  ? (value) => onChanged(entry.key, value)
                  : null,
            ),
        ],
      ),
    ),
  );
}
