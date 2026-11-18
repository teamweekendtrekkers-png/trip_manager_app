import 'package:flutter/material.dart';
import '../services/reusable_library_store.dart';
import '../services/pickup_library.dart';
import 'inline_formatting.dart';

class LibraryManagerDialog extends StatefulWidget {
  const LibraryManagerDialog({
    super.key,
    required this.store,
    required this.base,
  });
  final ReusableLibraryStore store;
  final List<LibraryRecord> base;
  @override
  State<LibraryManagerDialog> createState() => _LibraryManagerDialogState();
}

class _LibraryManagerDialogState extends State<LibraryManagerDialog> {
  late LibraryChanges changes;
  bool hiddenOnly = false, busy = false;
  String query = '', error = '';
  int customCounter = 0;
  String get kind => widget.store.kind;
  @override
  void initState() {
    super.initState();
    changes = widget.store.load();
  }

  Future<void> edit(LibraryRecord? record) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _LibraryItemEditor(
        kind: kind,
        initial: record?.data,
        duplicate: (data) => changes
            .records(widget.base)
            .any(
              (other) =>
                  other.key != record?.key &&
                  libraryDataId(kind, other.data) == libraryDataId(kind, data),
            ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      final wasHidden =
          record != null &&
          changes.hidden.contains(libraryDataId(kind, record.data));
      final key =
          record?.key ??
          'custom:${DateTime.now().microsecondsSinceEpoch}:${customCounter++}';
      changes.values[key] = Map<String, dynamic>.from(result);
      if (wasHidden) changes.hidden.add(libraryDataId(kind, result));
    });
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await widget.store.save(changes);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(() {
          busy = false;
          error =
              'Could not save library changes on this device. Your changes are still here; try again.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = changes.records(widget.base);
    bool hidden(LibraryRecord r) =>
        changes.hidden.contains(libraryDataId(kind, r.data));
    final records = all
        .where(
          (r) =>
              hidden(r) == hiddenOnly &&
              '${r.data.values.join(' ')} ${r.sources.join(' ')}'
                  .toLowerCase()
                  .contains(query.trim().toLowerCase()),
        )
        .toList();
    final hiddenCount = all
        .where(hidden)
        .map((r) => libraryDataId(kind, r.data))
        .toSet()
        .length;
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text(
          kind == 'pickup' ? 'Manage pickup library' : 'Manage packing library',
        ),
        content: SizedBox(
          width: 620,
          height: MediaQuery.sizeOf(context).height * .62,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Saved on this device. Edits affect future copies only; existing trips stay unchanged.',
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('library-manager-search'),
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Search library',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => query = value),
              ),
              if (error.isNotEmpty)
                Text(
                  error,
                  key: const Key('library-manager-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Expanded(
                child: ListView.builder(
                  key: const Key('library-manager-list'),
                  itemCount: records.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0)
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            OutlinedButton.icon(
                              key: const Key('library-add-item'),
                              onPressed: busy ? null : () => edit(null),
                              icon: const Icon(Icons.add),
                              label: const Text('Add item'),
                            ),
                            FilterChip(
                              key: const Key('library-show-hidden'),
                              selected: hiddenOnly,
                              label: Text('Hidden ($hiddenCount)'),
                              onSelected: busy
                                  ? null
                                  : (value) =>
                                        setState(() => hiddenOnly = value),
                            ),
                            if (records.isEmpty)
                              Text(
                                hiddenOnly
                                    ? 'No hidden items match.'
                                    : 'No items match. Add an item or try another search.',
                              ),
                          ],
                        ),
                      );
                    final record = records[index - 1],
                        isHidden = hidden(record);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FormattedText(
                                (kind == 'pickup'
                                            ? record.data['name']
                                            : record.data['text'])
                                        ?.toString() ??
                                    '',
                              ),
                              const SizedBox(height: 4),
                              Text(
                                kind == 'pickup'
                                    ? [
                                            record.data['landmark'],
                                            record.data['time'],
                                          ]
                                          .where(
                                            (s) =>
                                                s?.toString().isNotEmpty ==
                                                true,
                                          )
                                          .join(' · ')
                                    : record.sources.take(2).join(', '),
                              ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  Tooltip(
                                    message: 'Edit library item',
                                    child: TextButton.icon(
                                      onPressed: busy
                                          ? null
                                          : () => edit(record),
                                      icon: const Icon(Icons.edit_outlined),
                                      label: const Text('Edit'),
                                    ),
                                  ),
                                  Tooltip(
                                    message: isHidden
                                        ? 'Restore library item'
                                        : 'Hide from reusable library',
                                    child: TextButton.icon(
                                      onPressed: busy
                                          ? null
                                          : () => setState(() {
                                              final id = libraryDataId(
                                                kind,
                                                record.data,
                                              );
                                              if (isHidden) {
                                                changes.hidden.remove(id);
                                              } else {
                                                changes.hidden.add(id);
                                              }
                                            }),
                                      icon: Icon(
                                        isHidden
                                            ? Icons.restore
                                            : Icons.remove_circle_outline,
                                      ),
                                      label: Text(
                                        isHidden ? 'Restore' : 'Hide',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('library-manager-save'),
            onPressed: busy ? null : save,
            child: Text(busy ? 'Saving…' : 'Save library'),
          ),
        ],
      ),
    );
  }
}

class _LibraryItemEditor extends StatefulWidget {
  const _LibraryItemEditor({
    required this.kind,
    required this.initial,
    required this.duplicate,
  });
  final String kind;
  final Map<String, dynamic>? initial;
  final bool Function(Map<String, dynamic>) duplicate;
  @override
  State<_LibraryItemEditor> createState() => _LibraryItemEditorState();
}

class _LibraryItemEditorState extends State<_LibraryItemEditor> {
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> fields;
  String error = '';
  @override
  void initState() {
    super.initState();
    fields = {
      for (final key
          in widget.kind == 'pickup'
              ? ['name', 'landmark', 'time', 'mapLink']
              : ['text'])
        key: TextEditingController(
          text: widget.initial?[key]?.toString() ?? '',
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(
      widget.initial == null ? 'Add library item' : 'Edit library item',
    ),
    content: SizedBox(
      width: 440,
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final field in fields.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  key: ValueKey('library-field-${field.key}'),
                  controller: field.value,
                  maxLines: field.key == 'text' ? 4 : 1,
                  contextMenuBuilder: field.key == 'text'
                      ? formattingContextMenu
                      : null,
                  decoration: InputDecoration(
                    labelText: {
                      'name': 'Pickup name',
                      'landmark': 'Landmark',
                      'time': 'Pickup time',
                      'mapLink': 'Maps link (optional)',
                      'text': 'Packing item',
                    }[field.key],
                  ),
                  validator: (value) {
                    if ((field.key == 'name' || field.key == 'text') &&
                        (value?.trim().isEmpty ?? true))
                      return 'Enter an item name or text.';
                    if (field.key == 'mapLink' &&
                        value!.trim().isNotEmpty &&
                        safePickupMapLink(value).isEmpty)
                      return 'Enter a valid HTTPS link, or leave it blank.';
                    return null;
                  },
                ),
              ),
            if (error.isNotEmpty)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('library-item-save'),
        onPressed: () {
          if (!form.currentState!.validate()) return;
          final data = {
            for (final e in fields.entries) e.key: e.value.text.trim(),
          };
          if (widget.duplicate(data)) {
            setState(
              () => error =
                  'This item is already in the library. Restore it from Hidden if needed.',
            );
            return;
          }
          Navigator.pop(context, data);
        },
        child: const Text('Save item'),
      ),
    ],
  );
}
