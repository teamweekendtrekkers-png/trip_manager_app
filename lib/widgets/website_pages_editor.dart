import 'package:flutter/material.dart';
import '../models/website_page_defaults.dart';

class WebsitePagesEditor extends StatelessWidget {
  const WebsitePagesEditor({super.key, required this.pages, required this.onChanged, this.initiallyExpanded = false});
  final Map<String, dynamic> pages;
  final VoidCallback onChanged;
  final bool initiallyExpanded;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Website pages',style:Theme.of(context).textTheme.titleLarge),
      const Text('Edit About, Contact, page banners and navigation. Statistics are shared with Information; brand and contact details are under Footer. Trip content stays in each trip editor.'),
      for(final group in ['About page','Contact page','Page banners','Navigation'])
        ExpansionTile(
          key: PageStorageKey('website-pages-$group'),
          title: Text(group),
          initiallyExpanded: initiallyExpanded && group == 'About page',
          children: [
            for(final field in websitePageFields.where((field)=>field['group']==group))
              Padding(
                padding: const EdgeInsets.only(bottom:12),
                child: TextFormField(
                  key: ValueKey('website-page-${field['key']}'),
                  initialValue: pages[field['key']] as String,
                  minLines: field['label']!.contains('paragraph') || field['key']!.endsWith('Text') || field['key'] == 'aboutPromises' ? 3 : 1,
                  maxLines: null,
                  maxLength: 4000,
                  decoration: InputDecoration(labelText:field['label'],border:const OutlineInputBorder()),
                  onChanged:(value){pages[field['key']!]=value;onChanged();},
                ),
              ),
          ],
        ),
    ],
  );
}
