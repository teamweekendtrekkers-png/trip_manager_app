import '../services/reusable_library_store.dart';
import 'library_manager_dialog.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/carry_library.dart';
import 'inline_formatting.dart';

class CarryLibraryDialog extends StatefulWidget {
  const CarryLibraryDialog({
    super.key,
    required this.entries,
    required this.current,
    this.store,
  });
  final List<CarryLibraryItem> entries;
  final ReusableLibraryStore? store;
  final List<String> current;
  @override
  State<CarryLibraryDialog> createState() => _CarryLibraryDialogState();
}

class _CarryLibraryDialogState extends State<CarryLibraryDialog> {
  late final ReusableLibraryStore libraryStore =
      widget.store ?? ReusableLibraryStore.memory('carry');
  Future<void> manageLibrary() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => LibraryManagerDialog(
        store: libraryStore,
        base: carryRecords(widget.entries),
      ),
    );
    if (changed == true && mounted)
      setState(() {
        final available = resolveCarryLibrary(
          widget.entries,
          libraryStore,
        ).map((e) => e.id).toSet();
        selected.removeWhere((id) => !available.contains(id));
      });
  }

  var query = '';
  final selected = <String>{};
  @override
  Widget build(BuildContext context) {
    final entries = resolveCarryLibrary(widget.entries, libraryStore);
    final existing = includedCarryItems(widget.current);
    final shown = entries.where((e) => e.matches(query)).toList();
    final byId = {for (final entry in entries) entry.id: entry};
    final chosen = selected
        .where((id) => !existing.contains(id))
        .map((id) => byId[id])
        .whereType<CarryLibraryItem>()
        .toList();
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Reuse things to carry'),
      content: SizedBox(
        width: 620,
        height: math.min(
          MediaQuery.sizeOf(context).height * .62,
          math.max(
            260.0,
            (180 + shown.length * 100) *
                MediaQuery.textScalerOf(context).scale(16) /
                16,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose items from any trip or the standard checklist. Review them for this destination and weather.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('carry-library-search'),
              decoration: const InputDecoration(
                labelText: 'Search item or trip',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                key: const Key('carry-library-list'),
                itemCount: shown.length + 1,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  if (index == 0)
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              key: const Key('manage-carry-library'),
                              onPressed: manageLibrary,
                              icon: const Icon(Icons.edit_note),
                              label: const Text('Manage library'),
                            ),
                            TextButton(
                              key: const Key('carry-select-results'),
                              onPressed:
                                  shown.any(
                                    (e) =>
                                        !existing.contains(e.id) &&
                                        !selected.contains(e.id),
                                  )
                                  ? () => setState(
                                      () => selected.addAll(
                                        shown
                                            .where(
                                              (e) => !existing.contains(e.id),
                                            )
                                            .map((e) => e.id),
                                      ),
                                    )
                                  : null,
                              child: const Text('Select results'),
                            ),
                            TextButton(
                              onPressed: selected.isEmpty
                                  ? null
                                  : () => setState(selected.clear),
                              child: const Text('Clear selection'),
                            ),
                          ],
                        ),
                        if (shown.isEmpty)
                          const Text(
                            'No matching items. Try another item or trip name.',
                          ),
                      ],
                    );
                  final entry = shown[index - 1],
                      sources = entry.trips.toList()..sort();
                  final added = existing.contains(entry.id);
                  return CheckboxListTile(
                    key: ValueKey('carry-${entry.id}'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: FormattedText(entry.text),
                    subtitle: Text(
                      'From: ${sources.take(2).join(', ')}${sources.length > 2 ? ' +${sources.length - 2} more' : ''}${added ? '\nAlready included in this trip' : ''}',
                    ),
                    value: added || selected.contains(entry.id),
                    onChanged: added
                        ? null
                        : (value) => setState(() {
                            if (value == true) {
                              selected.add(entry.id);
                            } else {
                              selected.remove(entry.id);
                            }
                          }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('carry-library-add'),
          onPressed: chosen.isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  mergeCarryItems(widget.current, chosen.map((e) => e.text)),
                ),
          child: Text(
            'Add ${chosen.length} ${chosen.length == 1 ? 'item' : 'items'}',
          ),
        ),
      ],
    );
  }
}
