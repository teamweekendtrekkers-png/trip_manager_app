import 'package:flutter/material.dart';

/// Edits the isolated homepage draft, never trip records or live Google data.
class HomepageSectionsEditor extends StatelessWidget {
  const HomepageSectionsEditor({
    super.key,
    required this.sections,
    required this.onChanged,
  });
  final Map<String, dynamic> sections;
  final VoidCallback onChanged;

  Widget _text(
    Map values,
    String field,
    String label,
    String prefix, {
    int lines = 1,
  }) => Padding(
    // Separate text scroll offsets from ExpansionTile's persisted boolean state.
    key: PageStorageKey('text-scroll-$prefix-$field'),
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: ValueKey('$prefix-$field'),
      initialValue: values[field] as String,
      minLines: 1,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) {
        values[field] = value;
        onChanged();
      },
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final entry in {
        'stats': 'Statistics',
        'whyUs': 'Why Travel With Us',
        'reviews': 'Google Reviews',
        'cta': 'Bottom Call to Action',
      }.entries)
        Card(
          child: ExpansionTile(
            key: ValueKey('homepage-section-${entry.key}'),
            title: Text(entry.value),
            subtitle: Text(
              sections[entry.key]['enabled'] == true
                  ? 'Visible on website'
                  : 'Hidden on website',
            ),
            childrenPadding: const EdgeInsets.all(12),
            children: _section(context, entry.key),
          ),
        ),
    ],
  );

  List<Widget> _section(BuildContext context, String name) {
    final section = sections[name] as Map;
    final prefix = 'section-$name';
    final widgets = <Widget>[
      SwitchListTile(
        key: ValueKey('$prefix-enabled'),
        title: const Text('Show section'),
        value: section['enabled'] as bool,
        onChanged: (value) {
          section['enabled'] = value;
          onChanged();
        },
      ),
      if (name != 'stats') _text(section, 'title', 'Section heading', prefix),
    ];
    if (name == 'cta') {
      widgets.addAll([
        _text(section, 'description', 'Supporting text', prefix, lines: 3),
        _text(section, 'primaryLabel', 'Browse trips button text', prefix),
        _text(section, 'secondaryLabel', 'WhatsApp button text', prefix),
        const Text('Existing trips and WhatsApp destinations are preserved.'),
      ]);
      return widgets;
    }
    if (name == 'reviews') {
      widgets.addAll([
        const Text(
          'Curated Google reviews, not an automatic feed. Paste genuine review text and optionally its Google Maps share link. Select which reviews appear with Show review; use arrows to change their order. New reviews start hidden: fill in their name and text before publishing. Keep ratings accurate.',
        ),
        const SizedBox(height: 12),
        _text(
          section,
          'googleMapsUrl',
          'Google Maps / all reviews link',
          prefix,
        ),
        _text(section, 'rating', 'Overall Google rating (1–5)', prefix),
        _text(section, 'buttonLabel', 'All reviews button text', prefix),
        SwitchListTile(
          key: ValueKey('$prefix-autoPlay'),
          title: const Text('Automatically slide reviews'),
          subtitle: const Text(
            'Pauses for interaction and reduced-motion preferences.',
          ),
          value: section['autoPlay'] as bool,
          onChanged: (value) {
            section['autoPlay'] = value;
            onChanged();
          },
        ),
        DropdownButtonFormField<int>(
          key: ValueKey('$prefix-intervalSeconds'),
          initialValue: section['intervalSeconds'] as int,
          decoration: const InputDecoration(
            labelText: 'Seconds between slides',
          ),
          items: [
            for (var seconds = 4; seconds <= 30; seconds++)
              DropdownMenuItem(value: seconds, child: Text('$seconds seconds')),
          ],
          onChanged: (value) {
            if (value != null) {
              section['intervalSeconds'] = value;
              onChanged();
            }
          },
        ),
        const SizedBox(height: 12),
      ]);
    }
    final items = section['items'] as List;
    for (var index = 0; index < items.length; index++) {
      final item = items[index] as Map;
      final id = item['id'] as String;
      final itemPrefix = '$prefix-$id';
      final itemIndex = index;
      widgets.add(
        Card(
          key: ValueKey(itemPrefix),
          child: ExpansionTile(
            key: PageStorageKey('details-$itemPrefix'),
            title: Text(
              '${index + 1}. ${item['name'] == '' ? 'New review' : item['name'] ?? item['title'] ?? item['label']}',
            ),
            subtitle: Text(item['visible'] == true ? 'Shown' : 'Hidden'),
            childrenPadding: const EdgeInsets.all(12),
            children: [
              SwitchListTile(
                key: ValueKey('$itemPrefix-visible'),
                title: Text(name == 'reviews' ? 'Show review' : 'Show item'),
                value: item['visible'] as bool,
                onChanged: (value) {
                  item['visible'] = value;
                  onChanged();
                },
              ),
              Row(
                children: [
                  IconButton(
                    key: ValueKey('$itemPrefix-up'),
                    tooltip: 'Move up',
                    icon: const Icon(Icons.arrow_upward),
                    onPressed: index == 0
                        ? null
                        : () {
                            final moved = items.removeAt(itemIndex);
                            items.insert(itemIndex - 1, moved);
                            onChanged();
                          },
                  ),
                  IconButton(
                    key: ValueKey('$itemPrefix-down'),
                    tooltip: 'Move down',
                    icon: const Icon(Icons.arrow_downward),
                    onPressed: index == items.length - 1
                        ? null
                        : () {
                            final moved = items.removeAt(itemIndex);
                            items.insert(itemIndex + 1, moved);
                            onChanged();
                          },
                  ),
                  const Spacer(),
                  IconButton(
                    key: ValueKey('$itemPrefix-remove'),
                    tooltip: 'Remove from draft',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      items.removeAt(itemIndex);
                      onChanged();
                    },
                  ),
                ],
              ),
              if (name == 'stats') ...[
                _text(item, 'value', 'Value (e.g. 683+)', itemPrefix),
                _text(item, 'label', 'Label', itemPrefix),
              ] else if (name == 'whyUs') ...[
                _text(item, 'icon', 'Emoji / icon text', itemPrefix),
                _text(item, 'title', 'Card heading', itemPrefix),
                _text(item, 'text', 'Description', itemPrefix, lines: 5),
              ] else ...[
                _text(item, 'name', 'Reviewer name', itemPrefix),
                _text(
                  item,
                  'date',
                  'Review date / date label (optional)',
                  itemPrefix,
                ),
                DropdownButtonFormField<int>(
                  key: ValueKey('$itemPrefix-rating'),
                  initialValue: item['rating'] as int,
                  decoration: const InputDecoration(labelText: 'Star rating'),
                  items: [
                    for (var rating = 1; rating <= 5; rating++)
                      DropdownMenuItem(
                        value: rating,
                        child: Text('$rating stars'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      item['rating'] = value;
                      onChanged();
                    }
                  },
                ),
                const SizedBox(height: 12),
                _text(item, 'text', 'Review text', itemPrefix, lines: 8),
                _text(
                  item,
                  'photo',
                  'Reviewer photo HTTPS URL (optional)',
                  itemPrefix,
                ),
                _text(
                  item,
                  'googleMapsUrl',
                  'Specific Google review link (optional)',
                  itemPrefix,
                ),
                const Text(
                  'If no individual link is supplied, View on Google opens the section’s Google Maps link. No photo uses the reviewer’s initial.',
                ),
              ],
            ],
          ),
        ),
      );
    }
    widgets.add(
      OutlinedButton.icon(
        key: ValueKey('$prefix-add'),
        icon: const Icon(Icons.add),
        label: Text(name == 'reviews' ? 'Add review' : 'Add item'),
        onPressed: items.length >= (name == 'reviews' ? 30 : 8)
            ? null
            : () {
                final item = <String, dynamic>{
                  'id': 'custom-${DateTime.now().microsecondsSinceEpoch}',
                  'visible': true,
                };
                if (name == 'stats') {
                  item.addAll({'value': '0+', 'label': 'New statistic'});
                } else if (name == 'whyUs') {
                  item.addAll({
                    'icon': '🏕️',
                    'title': 'New reason',
                    'text': 'Add your description.',
                  });
                } else {
                  item.addAll({
                    'name': '',
                    'date': '',
                    'rating': 5,
                    'text': '',
                    'photo': '',
                    'googleMapsUrl': '',
                    'visible': false,
                  });
                }
                items.add(item);
                onChanged();
              },
      ),
    );
    if (name == 'reviews') {
      widgets.add(
        Text(
          '${items.where((item) => item['visible'] == true).length} reviews selected for the website. Swipe/slide order matches this list.',
          key: const Key('homepage-review-selection-summary'),
        ),
      );
    }
    return widgets;
  }
}
