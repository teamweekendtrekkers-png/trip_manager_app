import 'package:flutter/material.dart';

import '../models/homepage_config.dart';

class StoryHighlightsEditor extends StatelessWidget {
  const StoryHighlightsEditor({
    super.key,
    required this.value,
    required this.onChanged,
    required this.uploadPhoto,
    required this.choosePhoto,
    required this.previewPhoto,
  });

  final Map<String, dynamic> value;
  final ValueChanged<Map<String, dynamic>> onChanged;

  final Future<String?> Function() uploadPhoto;
  final Future<String?> Function(BuildContext) choosePhoto;
  final Widget Function(String) previewPhoto;

  Future<void> _edit(
    BuildContext context,
    List<Map<String, dynamic>> items, [
    int? index,
  ]) async {
    final item = index == null ? const <String, dynamic>{} : items[index];
    final form = GlobalKey<FormState>();
    var name = item['name'] as String? ?? '';
    var image = item['image'] as String? ?? '';
    var url = item['url'] as String? ?? '';
    var busy = false;
    String? error;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) {
          Future<void> pick(Future<String?> Function() choose) async {
            update(() {
              busy = true;
              error = null;
            });
            try {
              final path = await choose();
              if (path != null && dialogContext.mounted)
                update(() => image = path);
            } catch (failure) {
              if (dialogContext.mounted)
                update(() => error = failure.toString());
            } finally {
              if (dialogContext.mounted) update(() => busy = false);
            }
          }

          return AlertDialog(
            title: Text(index == null ? 'Add story' : 'Edit story'),
            content: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: name,
                      maxLength: 32,
                      decoration: const InputDecoration(
                        labelText: 'Story name',
                      ),
                      onChanged: (text) => name = text.trim(),
                      validator: (_) => name.isEmpty ? 'Enter a name' : null,
                    ),
                    if (HomepageConfig.safeImage(image))
                      ClipOval(
                        child: SizedBox.square(
                          dimension: 72,
                          child: previewPhoto(image),
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => pick(uploadPhoto),
                          icon: const Icon(Icons.upload),
                          label: const Text('Upload photo'),
                        ),
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () => pick(() => choosePhoto(dialogContext)),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Choose from photo library'),
                        ),
                      ],
                    ),
                    if (busy) const LinearProgressIndicator(),
                    if (error != null) Text(error!),
                    TextFormField(
                      key: ValueKey(image),
                      enabled: !busy,
                      initialValue: image,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Cover image',
                        hintText: 'images/… or HTTPS image link',
                      ),
                      onChanged: (text) => image = text.trim(),
                      validator: (_) => HomepageConfig.safeImage(image)
                          ? null
                          : 'Enter a valid image path or HTTPS link',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: url,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Instagram Highlight link',
                        hintText: 'instagram.com/stories/highlights/…',
                      ),
                      onChanged: (text) => url = text.trim(),
                      validator: (_) =>
                          HomepageConfig.isValidStory(
                            'Story',
                            'images/logo.jpg',
                            url,
                          )
                          ? null
                          : 'Paste the full Instagram Highlight link',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () {
                        if (form.currentState?.validate() ?? false) {
                          Navigator.pop(dialogContext, {
                            'name': name,
                            'image': image,
                            'url': url,
                          });
                        }
                      },
                child: const Text('Save story'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !context.mounted) return;
    if (index == null) {
      items.add(result);
    } else {
      items[index] = result;
    }
    onChanged({...value, 'items': items});
  }

  @override
  Widget build(BuildContext context) {
    final items = (value['items'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('Show story highlights'),
          subtitle: const Text(
            'Show the story circles just below the homepage header.',
          ),
          value: value['enabled'] == true,
          onChanged: (enabled) => onChanged({...value, 'enabled': enabled}),
        ),
        for (var index = 0; index < items.length; index++)
          ListTile(
            leading: const Icon(Icons.photo_outlined),
            title: Text(items[index]['name'] as String),
            onTap: () => _edit(context, items, index),
            trailing: PopupMenuButton<String>(
              tooltip: 'Story options',
              onSelected: (action) {
                if (action == 'edit') {
                  _edit(context, items, index);
                  return;
                }
                final story = items.removeAt(index);
                if (action == 'up') items.insert(index - 1, story);
                if (action == 'down') items.insert(index + 1, story);
                onChanged({...value, 'items': items});
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (index > 0)
                  const PopupMenuItem(value: 'up', child: Text('Move up')),
                if (index + 1 < items.length)
                  const PopupMenuItem(value: 'down', child: Text('Move down')),
                const PopupMenuItem(value: 'remove', child: Text('Remove')),
              ],
            ),
          ),
        OutlinedButton.icon(
          onPressed: items.length < 12 ? () => _edit(context, items) : null,
          icon: const Icon(Icons.add),
          label: const Text('Add story'),
        ),
      ],
    );
  }
}
