import 'package:flutter/material.dart';

enum TripEditorSection { all, basics, dates, photos, itinerary, website }

extension TripEditorSectionLabel on TripEditorSection {
  String get hint => switch (this) {
    TripEditorSection.all => 'Browse every field, or choose a section above.',
    TripEditorSection.basics => 'Trip name, destination, description and key details.',
    TripEditorSection.dates => 'Departure dates, prices and boarding locations.',
    TripEditorSection.photos => 'Cover image and the trip photo gallery.',
    TripEditorSection.itinerary => 'Daily plan, inclusions and traveller guidance.',
    TripEditorSection.website => 'Custom sections, visibility and booking options.',
  };

  String get label => switch (this) {
    TripEditorSection.all => 'All sections',
    TripEditorSection.basics => 'Basics',
    TripEditorSection.dates => 'Dates & price',
    TripEditorSection.photos => 'Photos',
    TripEditorSection.itinerary => 'Itinerary & guidance',
    TripEditorSection.website => 'Website sections',
  };
}

TripEditorSection editorSectionFor(String title) => switch (title) {
  'Basic Information' || 'About This Trip' || 'Trip Details' => TripEditorSection.basics,
  'Date & Pricing' || 'Departure Dates' || 'Boarding Locations' => TripEditorSection.dates,
  'Visibility' || 'Website URL & Booking Cutoff' || 'Website Display Fields' => TripEditorSection.website,
  _ => title.startsWith('Display Image') || title.startsWith('Gallery')
      ? TripEditorSection.photos : TripEditorSection.itinerary,
};

class TripEditorPanel extends StatelessWidget {
  const TripEditorPanel({super.key, required this.section, required this.child});
  final TripEditorSection section;
  final Widget child;
  @override Widget build(BuildContext context) => child;
}

List<Widget> visibleEditorChildren(TripEditorSection section, List<Widget> children) {
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
  const TripEditorSectionPicker({super.key, required this.value, required this.onChanged});
  final TripEditorSection value;
  final ValueChanged<TripEditorSection> onChanged;
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(children: [
      IconButton(
        key: const Key('editor-previous-section'),
        tooltip: 'Previous section',
        onPressed: value.index == 0 ? null : () => onChanged(TripEditorSection.values[value.index - 1]),
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(child: DropdownButtonFormField<TripEditorSection>(
      key: const Key('editor-section-picker'),
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: 'Editing section', border: const OutlineInputBorder(), isDense: true, helperText: value.hint, helperMaxLines: 3),
      items: [for (final section in TripEditorSection.values) DropdownMenuItem(value: section, child: Text(section.label))],
      onChanged: (section) { if (section != null) onChanged(section); },
      )),
      IconButton(
        key: const Key('editor-next-section'),
        tooltip: 'Next section',
        onPressed: value.index == TripEditorSection.values.length - 1 ? null : () => onChanged(TripEditorSection.values[value.index + 1]),
        icon: const Icon(Icons.chevron_right),
      ),
    ]),
  );
}

