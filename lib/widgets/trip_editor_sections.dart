import 'package:flutter/material.dart';

enum TripEditorSection {
  all,
  basics,
  dates,
  pickup,
  photos,
  itinerary,
  guidance,
  website,
}

extension TripEditorSectionLabel on TripEditorSection {
  String get hint => switch (this) {
    TripEditorSection.all => 'Browse every field, or choose a section above.',
    TripEditorSection.basics =>
      'Trip name, destination, description and key details.',
    TripEditorSection.dates => 'Departure dates, availability and prices.',
    TripEditorSection.pickup =>
      'Boarding locations, meeting times and map links.',
    TripEditorSection.photos => 'Cover image and the trip photo gallery.',
    TripEditorSection.itinerary =>
      'Day-by-day plans, activities and trip highlights.',
    TripEditorSection.guidance =>
      'Inclusions, exclusions and the packing list.',
    TripEditorSection.website =>
      'Custom sections, visibility and booking options.',
  };

  String get label => switch (this) {
    TripEditorSection.all => 'All sections',
    TripEditorSection.basics => 'Basics',
    TripEditorSection.dates => 'Dates & price',
    TripEditorSection.pickup => 'Pickup points',
    TripEditorSection.photos => 'Photos & video',
    TripEditorSection.itinerary => 'Itinerary & highlights',
    TripEditorSection.guidance => 'Packing & inclusions',
    TripEditorSection.website => 'Website sections',
  };
}

TripEditorSection editorSectionFor(String title) => switch (title) {
  'Basic Information' ||
  'About This Trip' ||
  'Trip Details' => TripEditorSection.basics,
  'Date & Pricing' || 'Departure Dates' => TripEditorSection.dates,
  'Boarding Locations' ||
  'Pickup points' ||
  'Pickup summary' => TripEditorSection.pickup,
  'Inclusions' ||
  'Exclusions' ||
  'Things to Carry' => TripEditorSection.guidance,
  'Trip video' => TripEditorSection.photos,
  'Visibility' ||
  'Website URL & Booking Cutoff' ||
  'Website Display Fields' => TripEditorSection.website,
  _ =>
    title.startsWith('Display Image') || title.startsWith('Gallery')
        ? TripEditorSection.photos
        : TripEditorSection.itinerary,
};

class TripEditorPanel extends StatelessWidget {
  const TripEditorPanel({
    super.key,
    required this.section,
    required this.child,
  });
  final TripEditorSection section;
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

List<Widget> visibleEditorChildren(
  TripEditorSection section,
  List<Widget> children,
) {
  if (section == TripEditorSection.all) return children;
  final result = <Widget>[];
  for (final child in children) {
    if (child is TripEditorPanel) {
      if (child.section == section) {
        result.add(child);
        result.add(const SizedBox(height: 16));
      }
    } else if (child is! SizedBox) {
      result.add(child);
    }
  }
  return result;
}

class TripEditorSectionPicker extends StatelessWidget {
  const TripEditorSectionPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final TripEditorSection value;
  final ValueChanged<TripEditorSection> onChanged;
  @override
  Widget build(BuildContext context) {
    final guided = value != TripEditorSection.all;
    final steps = TripEditorSection.values.length - 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (guided) ...[
            Semantics(
              label: 'Step ${value.index} of $steps',
              child: LinearProgressIndicator(value: value.index / steps),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              IconButton(
                key: const Key('editor-previous-section'),
                tooltip: 'Previous section',
                onPressed: value.index <= 1
                    ? null
                    : () =>
                          onChanged(TripEditorSection.values[value.index - 1]),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: DropdownButtonFormField<TripEditorSection>(
                  key: const Key('editor-section-picker'),
                  value: value,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: guided
                        ? 'Step ${value.index} of $steps'
                        : 'Editing section',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: [
                    for (final section in TripEditorSection.values)
                      DropdownMenuItem(
                        value: section,
                        child: Text(section.label),
                      ),
                  ],
                  onChanged: (section) {
                    if (section != null) onChanged(section);
                  },
                ),
              ),
              IconButton(
                key: const Key('editor-next-section'),
                tooltip: 'Next section',
                onPressed: value.index == steps
                    ? null
                    : () =>
                          onChanged(TripEditorSection.values[value.index + 1]),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
