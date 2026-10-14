import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/draft_store.dart';
import '../services/workspace_changes.dart';

Map<String, dynamic> copyDocument(Map value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

/// Maps merge field by field; lists are intentionally atomic, so two different
/// reorderings never silently overwrite each other.
Map<String, dynamic> recoverDocument(Map base, Map local, Map remote) {
  const absent = Object();
  Object? merge(Object? b, Object? l, Object? r, String field) {
    if (WorkspaceChanges.same(l, b)) return r;
    if (WorkspaceChanges.same(r, b) || WorkspaceChanges.same(l, r)) return l;
    if (b is Map && l is Map && r is Map) {
      final result = <String, dynamic>{};
      for (final key in {...b.keys, ...l.keys, ...r.keys}) {
        final value = merge(
          b.containsKey(key) ? b[key] : absent,
          l.containsKey(key) ? l[key] : absent,
          r.containsKey(key) ? r[key] : absent,
          '$field.$key',
        );
        if (!identical(value, absent)) result[key.toString()] = value;
      }
      return result;
    }
    throw StateError(
      'Saved draft conflicts with the website at $field. Your local copy is retained.',
    );
  }

  return Map<String, dynamic>.from(
    merge(base, local, remote, 'content') as Map,
  );
}

mixin LocalDraft<T extends StatefulWidget> on State<T> {
  String get localScope;
  String get localSlot;
  Map<String, dynamic>? get currentDocument;
  void applyDocument(Map<String, dynamic> value);
  bool get draftBusy => false;
  Map<String, dynamic>? get discardDraftBase => _localBase;
  String get discardDraftExplanation =>
      'Remove this editor draft and return to the version loaded when you opened this editor. The live website will not change.';
  Future<void> afterDraftDeleted() async {}
  Map<String, dynamic>? _localBase,
      _lastDocument,
      _blockedDraft,
      _savedDocument;
  Timer? _saveTimer;
  AppLifecycleListener? _lifecycle;
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onInactive: () {
        if (mounted) unawaited(saveLocalDraft(checkpoint: false));
      },
    );
  }

  bool _applying = false;
  void _apply(Map<String, dynamic> value) {
    _applying = true;
    try {
      applyDocument(value);
    } finally {
      _applying = false;
    }
  }

  String? localDraftError;
  DateTime? localSavedAt;
  final List<Map<String, dynamic>> _undoDocuments = [];
  bool get hasLocalEdits =>
      _localBase != null && !WorkspaceChanges.same(_localBase, currentDocument);
  void startLocalDraft(Map<String, dynamic> remote) {
    _localBase = copyDocument(remote);
    _savedDocument = null;
    final record = DraftStore.read(localScope, localSlot);
    if (record != null) {
      try {
        final data = record['data'] as Map;
        _apply(
          recoverDocument(data['base'] as Map, data['draft'] as Map, remote),
        );
        if (data['saved'] is Map) {
          _savedDocument = recoverDocument(
            data['base'] as Map,
            data['saved'] as Map,
            remote,
          );
        }
        localSavedAt = DateTime.tryParse(record['savedAt'].toString());
      } catch (e) {
        localDraftError = e.toString();
        _blockedDraft = Map<String, dynamic>.from(
          (record['data'] as Map)['draft'] as Map,
        );
      }
    }
    _savedDocument ??= currentDocument == null
        ? null
        : copyDocument(currentDocument!);
    _lastDocument = currentDocument == null
        ? null
        : copyDocument(currentDocument!);
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (_applying || _localBase == null || draftBusy || currentDocument == null)
      return;
    if (_lastDocument != null &&
        !WorkspaceChanges.same(_lastDocument, currentDocument)) {
      _undoDocuments.add(copyDocument(_lastDocument!));
      if (_undoDocuments.length > 20) _undoDocuments.removeAt(0);
      _lastDocument = copyDocument(currentDocument!);
    }
    if (_blockedDraft == null) {
      _saveTimer?.cancel();
      _saveTimer = Timer(
        const Duration(milliseconds: 500),
        () => saveLocalDraft(checkpoint: false),
      );
    }
  }

  Future<void> saveLocalDraft({bool checkpoint = true}) async {
    _saveTimer?.cancel();
    if (currentDocument == null ||
        _localBase == null ||
        !DraftStore.available ||
        _blockedDraft != null)
      return;
    final document = copyDocument(currentDocument!);
    try {
      if (hasLocalEdits) {
        await DraftStore.write(localScope, localSlot, {
          'base': _localBase,
          'draft': document,
          'saved': checkpoint ? document : _savedDocument,
        });
      } else {
        await DraftStore.remove(localScope, localSlot);
      }
      if (checkpoint) _savedDocument = document;
      if (mounted)
        super.setState(() {
          localSavedAt = DateTime.now();
          localDraftError = null;
        });
    } catch (e) {
      if (mounted)
        super.setState(
          () => localDraftError = 'Could not save local draft: $e',
        );
    }
  }

  Future<void> publishedLocalDraft(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
  ) async {
    _saveTimer?.cancel();
    _localBase = copyDocument(after);
    _lastDocument = copyDocument(after);
    _savedDocument = copyDocument(after);
    _undoDocuments.clear();
    _blockedDraft = null;
    if (!DraftStore.available) return;
    try {
      await DraftStore.remember(
        localScope,
        localSlot,
        before,
        'Before publication',
      );
      await DraftStore.remember(
        localScope,
        localSlot,
        after,
        'Published version',
      );
      await DraftStore.remove(localScope, localSlot);
    } catch (e) {
      localDraftError =
          'Published successfully, but local history could not be saved: $e';
    }
  }

  Future<void> acceptLocalDraft() async {
    _saveTimer?.cancel();
    _localBase = currentDocument == null
        ? null
        : copyDocument(currentDocument!);
    _lastDocument = _localBase == null ? null : copyDocument(_localBase!);
    _savedDocument = _lastDocument == null
        ? null
        : copyDocument(_lastDocument!);
    _blockedDraft = null;
    await DraftStore.remove(localScope, localSlot);
  }

  Future<void> discardEditorChanges({
    bool deleteDraft = false,
    bool confirm = true,
  }) async {
    final target = deleteDraft ? discardDraftBase : _savedDocument;
    if (target == null || draftBusy) return;
    final confirmed =
        !confirm ||
        await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(
                  deleteDraft
                      ? 'Delete saved local draft?'
                      : 'Discard changes?',
                ),
                content: Text(
                  deleteDraft
                      ? discardDraftExplanation
                      : 'Undo edits since you last tapped Save local draft or opened this editor. Automatic recovery saves do not reset this point. The live website will not change.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Keep editing'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(
                      deleteDraft ? 'Delete saved draft' : 'Discard changes',
                    ),
                  ),
                ],
              ),
            ) ==
            true;
    if (confirmed != true || !mounted) return;
    _saveTimer?.cancel();
    try {
      if (deleteDraft) {
        if (!WorkspaceChanges.same(target, discardDraftBase)) {
          throw StateError(
            'The loaded version changed. Review it before deleting this draft.',
          );
        }
        await afterDraftDeleted();
        await DraftStore.remove(localScope, localSlot);
      } else if (_localBase != null && DraftStore.available) {
        await DraftStore.write(localScope, localSlot, {
          'base': _localBase,
          'draft': target,
          'saved': target,
        });
      }
      if (!mounted) return;
      super.setState(() {
        _apply(copyDocument(target));
        _lastDocument = copyDocument(currentDocument!);
        _savedDocument = copyDocument(currentDocument!);
        _undoDocuments.clear();
        _blockedDraft = null;
        localDraftError = null;
        if (deleteDraft) {
          localSavedAt = null;
          _localBase = copyDocument(currentDocument!);
        }
      });
    } catch (_) {
      if (mounted)
        super.setState(
          () => localDraftError =
              'Could not discard the draft. Your edits are retained; try again.',
        );
    }
  }

  Future<bool> leaveLocalDraft() async {
    if (!hasLocalEdits) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keep your edits?'),
        content: const Text(
          'Saving a draft keeps it on this device. It does not publish to the website.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'keep'),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save draft & leave'),
          ),
        ],
      ),
    );
    if (choice == 'discard') {
      await discardEditorChanges(confirm: false);
      return localDraftError == null && _blockedDraft == null;
    }
    if (choice == 'save') {
      await saveLocalDraft();
      return localDraftError == null && _blockedDraft == null;
    }
    return false;
  }

  Widget localDraftBar() => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            localDraftError ??
                DraftStore.error ??
                (localSavedAt == null
                    ? 'Drafts save automatically on this device'
                    : 'Local draft saved ${localSavedAt!.toLocal().toString().split('.').first}'),
            style: TextStyle(
              color: localDraftError == null
                  ? null
                  : Theme.of(context).colorScheme.error,
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: draftBusy ? null : saveLocalDraft,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save local draft'),
              ),
              if (hasLocalEdits)
                TextButton.icon(
                  onPressed:
                      draftBusy ||
                          _savedDocument == null ||
                          WorkspaceChanges.same(_savedDocument, currentDocument)
                      ? null
                      : () => discardEditorChanges(),
                  icon: const Icon(Icons.undo_outlined),
                  label: const Text('Discard changes'),
                ),
              if (hasLocalEdits || _blockedDraft != null)
                TextButton.icon(
                  onPressed:
                      draftBusy || (!hasLocalEdits && _blockedDraft == null)
                      ? null
                      : () => discardEditorChanges(deleteDraft: true),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete saved draft'),
                ),
              TextButton.icon(
                onPressed: _undoDocuments.isEmpty || draftBusy
                    ? null
                    : () {
                        final previous = _undoDocuments.removeLast();
                        super.setState(() => _apply(previous));
                        _lastDocument = copyDocument(previous);
                        saveLocalDraft(checkpoint: false);
                      },
                icon: const Icon(Icons.undo),
                label: const Text('Undo'),
              ),
              TextButton.icon(
                onPressed: draftBusy ? null : () => _history(),
                icon: const Icon(Icons.history),
                label: const Text('Saved versions'),
              ),
              if (_blockedDraft != null)
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Saved draft needs review'),
                      content: SingleChildScrollView(
                        child: SelectableText(
                          const JsonEncoder.withIndent(
                            '  ',
                          ).convert(_blockedDraft),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _apply(_blockedDraft!);
                              _blockedDraft = null;
                              localDraftError = null;
                            });
                            Navigator.pop(ctx);
                            saveLocalDraft();
                          },
                          child: const Text('Restore as draft'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('Review saved draft'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
  Future<void> _history() async {
    final records = [
      ...DraftStore.history(localScope, localSlot),
      if (localSlot.startsWith('trip:'))
        ...DraftStore.tripVersions(localScope, localSlot.substring(5)),
    ];
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saved versions'),
        content: SizedBox(
          width: 540,
          child: ListView(
            shrinkWrap: true,
            children: [
              if (records.isEmpty)
                const Text('Versions appear after publication.'),
              for (final record in records)
                ListTile(
                  title: Text(record['label'].toString()),
                  subtitle: Text(record['time'].toString()),
                  trailing: const Icon(Icons.restore),
                  onTap: () => Navigator.pop(
                    ctx,
                    Map<String, dynamic>.from(record['data'] as Map),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (value != null && mounted) {
      setState(() => _apply(value));
      await saveLocalDraft(checkpoint: false);
    }
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _saveTimer?.cancel();
    if (hasLocalEdits &&
        _blockedDraft == null &&
        currentDocument != null &&
        _localBase != null) {
      unawaited(
        DraftStore.write(localScope, localSlot, {
          'base': _localBase,
          'draft': copyDocument(currentDocument!),
          'saved': _savedDocument,
        }).catchError((Object _) {}),
      );
    }
    super.dispose();
  }
}
