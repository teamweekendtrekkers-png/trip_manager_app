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
            'showWeekendFilter': 'Upcoming weekend / date filter',
          }.entries)
            SwitchListTile(
              key: ValueKey('homepage-discovery-${entry.key}'),
              contentPadding: EdgeInsets.zero,
              title: Text(entry.value),
              value: discovery[entry.key] as bool,
              onChanged: entry.key == 'enabled' || discovery['enabled'] == true
                  ? (value) => onChanged(entry.key, value)
                  : null,
            ),
        ],
      ),
    ),
  );
}
