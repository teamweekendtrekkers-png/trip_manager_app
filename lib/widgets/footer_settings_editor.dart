import 'package:flutter/material.dart';

/// Edits only the website footer draft; never changes a payment ID or publishes directly.
class FooterSettingsEditor extends StatelessWidget {
  const FooterSettingsEditor({
    super.key,
    required this.footer,
    required this.onChanged,
    this.initiallyExpanded = false,
  });
  final Map<String, dynamic> footer;
  final VoidCallback onChanged;
  final bool initiallyExpanded;

  Widget text(
    Map values,
    String field,
    String label, {
    String prefix = 'footer',
    int lines = 1,
  }) => Padding(
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
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      key: const ValueKey('website-footer-editor'),
      title: const Text('Website Footer (all pages)'),
      initiallyExpanded: initiallyExpanded,
      subtitle: Text(
        footer['showUpi'] == true
            ? 'Footer UPI shown • checkout unchanged'
            : 'Footer UPI hidden • checkout unchanged',
      ),
      childrenPadding: const EdgeInsets.all(12),
      children: [
        SwitchListTile(
          key: const ValueKey('footer-showUpi'),
          title: const Text('Show Pay via UPI in footer'),
          subtitle: const Text(
            'Hides only the footer payment details. Checkout UPI and the payment ID are unchanged.',
          ),
          value: footer['showUpi'] as bool,
          onChanged: (value) {
            footer['showUpi'] = value;
            onChanged();
          },
        ),
        const Text(
          'To change the actual UPI ID, use Settings → Website Contact & Payment. Hiding the footer is display-only, not payment security.',
        ),
        const SizedBox(height: 12),
        text(footer, 'brandName', 'Brand / organization name'),
        text(footer, 'description', 'About the travel community', lines: 4),
        text(footer, 'contactTitle', 'Contact column heading'),
        text(footer, 'location', 'Location / address', lines: 3),
        text(
          footer,
          'whatsAppNumber',
          'Footer WhatsApp override (optional, country code + number)',
        ),
        const Text(
          'Leave overrides blank to use the current website WhatsApp and Instagram links. A footer override does not change booking or page-wide contact numbers.',
        ),
        const SizedBox(height: 12),
        text(footer, 'instagramUrl', 'Footer Instagram HTTPS link (optional)'),
        text(footer, 'instagramLabel', 'Instagram display label (optional)'),
        text(footer, 'email', 'Contact email (optional)'),
        SwitchListTile(
          key: const ValueKey('footer-showSocialLinks'),
          title: const Text('Show social icons'),
          value: footer['showSocialLinks'] as bool,
          onChanged: (value) {
            footer['showSocialLinks'] = value;
            onChanged();
          },
        ),
        text(footer, 'quickLinksTitle', 'Quick Links heading'),
        const Text(
          'Essential pages stay linked. You can edit the labels, but Home, All Trips, About Us and Contact cannot be removed.',
        ),
        const SizedBox(height: 12),
        text(footer, 'homeLabel', 'Home link label'),
        text(footer, 'tripsLabel', 'All Trips link label'),
        text(footer, 'aboutLabel', 'About Us link label'),
        text(footer, 'contactLabel', 'Contact link label'),
        text(footer, 'informationTitle', 'Extra information heading'),
        const Text(
          'Optional links may point to existing information/policy pages or HTTPS documents. No legal policies are generated automatically.',
        ),
        const SizedBox(height: 12),
        ...informationLinks(),
        text(footer, 'upiTitle', 'UPI column heading'),
        text(footer, 'copyUpiLabel', 'Existing Copy UPI button label'),
        text(
          footer,
          'copyright',
          'Copyright text ({year} and {brand} supported)',
          lines: 3,
        ),
        const Text(
          'Changes stay in your homepage draft until Publish homepage is confirmed.',
        ),
      ],
    ),
  );

  List<Widget> informationLinks() {
    final items = footer['informationLinks'] as List;
    return [
      for (var index = 0; index < items.length; index++)
        Card(
          key: ValueKey('footer-link-${items[index]['id']}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                text(
                  items[index] as Map,
                  'label',
                  'Information link label',
                  prefix: 'footer-link-${items[index]['id']}',
                ),
                text(
                  items[index] as Map,
                  'url',
                  'Existing page or HTTPS URL',
                  prefix: 'footer-link-${items[index]['id']}',
                ),
                SwitchListTile(
                  key: ValueKey('footer-link-${items[index]['id']}-visible'),
                  title: const Text('Show information link'),
                  value: items[index]['visible'] as bool,
                  onChanged: (value) {
                    items[index]['visible'] = value;
                    onChanged();
                  },
                ),
                Row(
                  children: [
                    IconButton(
                      key: ValueKey('footer-link-${items[index]['id']}-up'),
                      tooltip: 'Move up',
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: index == 0
                          ? null
                          : () {
                              final item = items.removeAt(index);
                              items.insert(index - 1, item);
                              onChanged();
                            },
                    ),
                    IconButton(
                      key: ValueKey('footer-link-${items[index]['id']}-down'),
                      tooltip: 'Move down',
                      icon: const Icon(Icons.arrow_downward),
                      onPressed: index == items.length - 1
                          ? null
                          : () {
                              final item = items.removeAt(index);
                              items.insert(index + 1, item);
                              onChanged();
                            },
                    ),
                    const Spacer(),
                    IconButton(
                      key: ValueKey('footer-link-${items[index]['id']}-remove'),
                      tooltip: 'Remove information link',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        items.removeAt(index);
                        onChanged();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      OutlinedButton.icon(
        key: const ValueKey('footer-add-link'),
        icon: const Icon(Icons.add),
        label: const Text('Add information link'),
        onPressed: items.length >= 8
            ? null
            : () {
                items.add({
                  'id': 'info-${DateTime.now().microsecondsSinceEpoch}',
                  'label': 'Information',
                  'url': 'contact.html',
                  'visible': true,
                });
                onChanged();
              },
      ),
      const SizedBox(height: 12),
    ];
  }
}
