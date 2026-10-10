import 'package:flutter/material.dart';
import '../models/trip_section_settings.dart';

class TripSectionSettingsEditor extends StatelessWidget {
  final List<String> expandedSections;
  final ValueChanged<List<String>> onChanged;

  const TripSectionSettingsEditor({
    super.key,
    required this.expandedSections,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Website section display',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose which sections start expanded. Visitors can always '
              'open or close them. Brochures still include the full content.',
            ),
            const SizedBox(height: 8),
            for (final section in TripSectionSettings.titles.entries)
              SwitchListTile(
                key: ValueKey('section-expanded-${section.key}'),
                contentPadding: EdgeInsets.zero,
                title: Text(section.value),
                subtitle: Text(
                  expandedSections.contains(section.key)
                      ? 'Starts expanded'
                      : 'Starts collapsed',
                ),
                value: expandedSections.contains(section.key),
                onChanged: (expanded) {
                  final next = expandedSections.toSet();
                  expanded ? next.add(section.key) : next.remove(section.key);
                  onChanged(
                    TripSectionSettings.titles.keys
                        .where(next.contains)
                        .toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
