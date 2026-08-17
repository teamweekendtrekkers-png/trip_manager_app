/// Result of a three-way merge between the data loaded by the app, the local
/// edits, and the latest data on GitHub.
class TripMergeResult {
  final List<Map<String, dynamic>> trips;
  final List<String> conflicts;

  const TripMergeResult({required this.trips, this.conflicts = const []});

  bool get success => conflicts.isEmpty;
}

/// Field-aware three-way merger used before publishing trip data.
///
/// The merge deliberately works by trip ID and field. This lets a remote price
/// edit coexist with a local date edit, while edit/edit and delete/edit races
/// are surfaced for an administrator to resolve.
class TripMergeService {
  const TripMergeService._();

  static TripMergeResult merge({
    required List<Map<String, dynamic>> base,
    required List<Map<String, dynamic>> local,
    required List<Map<String, dynamic>> remote,
    Set<String> intentionalDeletedIds = const {},
  }) {
    final conflicts = <String>[];
    final baseById = _index(base, 'loaded data', conflicts);
    final localById = _index(local, 'local data', conflicts);
    final remoteById = _index(remote, 'remote data', conflicts);

    if (conflicts.isNotEmpty) {
      return TripMergeResult(trips: local, conflicts: conflicts);
    }

    for (final id in baseById.keys) {
      if (!localById.containsKey(id) && !intentionalDeletedIds.contains(id)) {
        conflicts.add(
          'Trip "$id" disappeared locally without an intentional delete.',
        );
      }
    }

    final mergedById = <String, Map<String, dynamic>>{};
    final allIds = <String>{
      ...baseById.keys,
      ...localById.keys,
      ...remoteById.keys,
    };

    for (final id in allIds) {
      final baseTrip = baseById[id];
      final localTrip = localById[id];
      final remoteTrip = remoteById[id];

      if (baseTrip == null) {
        if (localTrip != null && remoteTrip != null) {
          if (_deepEquals(localTrip, remoteTrip)) {
            mergedById[id] = _copyMap(localTrip);
          } else {
            conflicts.add(
              'Trip "$id" was added differently locally and remotely.',
            );
          }
        } else if (localTrip != null) {
          mergedById[id] = _copyMap(localTrip);
        } else if (remoteTrip != null) {
          mergedById[id] = _copyMap(remoteTrip);
        }
        continue;
      }

      if (localTrip == null) {
        if (remoteTrip != null && !_deepEquals(remoteTrip, baseTrip)) {
          conflicts.add('Trip "$id" was deleted locally but edited remotely.');
        }
        continue;
      }

      if (remoteTrip == null) {
        if (!_deepEquals(localTrip, baseTrip)) {
          conflicts.add('Trip "$id" was edited locally but deleted remotely.');
        }
        continue;
      }

      final merged = <String, dynamic>{};
      final fields = <String>{
        ...baseTrip.keys,
        ...localTrip.keys,
        ...remoteTrip.keys,
      };

      for (final field in fields) {
        final baseField = _fieldState(baseTrip, field);
        final localField = _fieldState(localTrip, field);
        final remoteField = _fieldState(remoteTrip, field);
        final localChanged = !_fieldEquals(localField, baseField);
        final remoteChanged = !_fieldEquals(remoteField, baseField);

        if (localChanged &&
            remoteChanged &&
            !_fieldEquals(localField, remoteField)) {
          conflicts.add(
            'Trip "$id" field "$field" changed both locally and remotely.',
          );
          continue;
        }

        final selected = localChanged ? localField : remoteField;
        if (selected.present) {
          merged[field] = _copyValue(selected.value);
        }
      }

      mergedById[id] = merged;
    }

    // Cross-tier source positions are not meaningful: both the website and
    // the app derive featured-active, active, and inactive tiers before
    // display. Merge each tier independently so an active-trip reorder can be
    // combined with a featured-trip reorder without manufacturing a cycle
    // from their interleaved backing-list positions.
    final tierOrders = <int, List<String>>{};
    for (final priority in const <int>[2, 1, 0]) {
      final tierIds = <String>{
        for (final entry in mergedById.entries)
          if (_tripPriority(entry.value) == priority) entry.key,
      };
      if (tierIds.isEmpty) {
        tierOrders[priority] = const <String>[];
        continue;
      }
      final stableTierIds = <String>{
        for (final id in tierIds)
          if (baseById.containsKey(id) &&
              _tripPriority(baseById[id]!) == priority)
            id,
      };
      tierOrders[priority] = _mergeOrder(
        base: base,
        local: local,
        remote: remote,
        retainedIds: tierIds,
        stableIds: stableTierIds,
        targetPriority: priority,
        conflicts: conflicts,
      );
    }

    if (conflicts.isNotEmpty) {
      return TripMergeResult(trips: local, conflicts: conflicts);
    }

    // Retain the backing document's interleaving. Only the IDs occupying a
    // tier's slots change when that tier is reordered. A status change alters
    // the moved trip's original slot, deletions remove a slot, and additions
    // append one. This keeps a field-only merge byte-order stable instead of
    // rewriting the backing list into three concatenated display tiers.
    final slotPriorities = <int>[
      for (final trip in base)
        if (mergedById.containsKey(trip['id']?.toString() ?? ''))
          _tripPriority(mergedById[trip['id']!.toString()]!),
    ];
    final appendedIds = <String>[];
    final appendedSeen = <String>{};
    void collectAppended(List<Map<String, dynamic>> source) {
      for (final trip in source) {
        final id = trip['id']?.toString() ?? '';
        if (id.isNotEmpty &&
            !baseById.containsKey(id) &&
            mergedById.containsKey(id) &&
            appendedSeen.add(id)) {
          appendedIds.add(id);
        }
      }
    }

    // Match the deterministic addition precedence used by the order merger.
    collectAppended(remote);
    collectAppended(local);
    for (final id in mergedById.keys) {
      if (!baseById.containsKey(id) && appendedSeen.add(id)) {
        appendedIds.add(id);
      }
    }
    slotPriorities.addAll(
      appendedIds.map((id) => _tripPriority(mergedById[id]!)),
    );

    final tierCursors = <int, int>{2: 0, 1: 0, 0: 0};
    final order = <String>[];
    for (final priority in slotPriorities) {
      final tierOrder = tierOrders[priority]!;
      final cursor = tierCursors[priority]!;
      order.add(tierOrder[cursor]);
      tierCursors[priority] = cursor + 1;
    }

    return TripMergeResult(trips: [for (final id in order) mergedById[id]!]);
  }

  static Map<String, Map<String, dynamic>> _index(
    List<Map<String, dynamic>> trips,
    String label,
    List<String> conflicts,
  ) {
    final result = <String, Map<String, dynamic>>{};
    for (final trip in trips) {
      final id = trip['id']?.toString() ?? '';
      if (id.isEmpty) {
        conflicts.add('A trip in $label has no ID.');
      } else if (result.containsKey(id)) {
        conflicts.add('Duplicate trip ID "$id" in $label.');
      } else {
        result[id] = trip;
      }
    }
    return result;
  }

  static int _tripPriority(Map<String, dynamic> trip) {
    if (trip['isActive'] == false) return 0;
    return trip['featured'] == true ? 2 : 1;
  }

  static List<String> _mergeOrder({
    required List<Map<String, dynamic>> base,
    required List<Map<String, dynamic>> local,
    required List<Map<String, dynamic>> remote,
    required Set<String> retainedIds,
    required Set<String> stableIds,
    required int targetPriority,
    required List<String> conflicts,
  }) {
    List<String> ids(List<Map<String, dynamic>> trips) => trips
        .map((trip) => trip['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty && retainedIds.contains(id))
        .toList();

    final baseIds = ids(base);
    final localIds = ids(local);
    final remoteIds = ids(remote);
    final baseById = {for (final trip in base) trip['id'].toString(): trip};
    final localById = {for (final trip in local) trip['id'].toString(): trip};
    final remoteById = {for (final trip in remote) trip['id'].toString(): trip};

    // A status change can bring trips from several former tiers into the same
    // destination tier. Their former cross-tier backing positions were never
    // a shared order, so merge each origin independently. Keep the destination
    // tier's existing members together with explicitly positioned new IDs,
    // then weave entrant groups through their original origin-tier slot
    // skeleton. New IDs are deterministically appended when no destination
    // members exist to provide meaningful insertion anchors.
    const newTripOrigin = 3;
    final hasDestinationOrigin = retainedIds.any((id) {
      final trip = baseById[id];
      return trip != null && _tripPriority(trip) == targetPriority;
    });
    int originFor(String id) {
      final trip = baseById[id];
      if (trip != null) return _tripPriority(trip);
      return hasDestinationOrigin ? targetPriority : newTripOrigin;
    }

    final idsByOrigin = <int, Set<String>>{};
    for (final id in retainedIds) {
      idsByOrigin.putIfAbsent(originFor(id), () => <String>{}).add(id);
    }
    if (idsByOrigin.length > 1) {
      final ordersByOrigin = <int, List<String>>{};
      for (final entry in idsByOrigin.entries) {
        ordersByOrigin[entry.key] = _mergeOrder(
          base: base,
          local: local,
          remote: remote,
          retainedIds: entry.value,
          stableIds: stableIds.intersection(entry.value),
          targetPriority: targetPriority,
          conflicts: conflicts,
        );
      }

      // This is the deterministic fallback if neither side supplies a
      // compatible cross-origin insertion anchor. Preserve the destination
      // group first, then weave entrant groups through their base origin-slot
      // skeleton. It intentionally contains no invented cross-origin order.
      final fallback = <String>[];
      final destinationOrder = ordersByOrigin[targetPriority];
      if (destinationOrder != null) fallback.addAll(destinationOrder);

      final originCursors = <int, int>{};
      for (final id in baseIds) {
        final origin = originFor(id);
        if (origin == targetPriority) continue;
        final originOrder = ordersByOrigin[origin]!;
        final cursor = originCursors[origin] ?? 0;
        fallback.add(originOrder[cursor]);
        originCursors[origin] = cursor + 1;
      }

      final unanchoredNewTripOrder = ordersByOrigin[newTripOrigin];
      if (unanchoredNewTripOrder != null) {
        fallback.addAll(unanchoredNewTripOrder);
      }

      // Origin orders are hard constraints: they contain the true three-way
      // reorders for pairs that already shared a tier. Cross-origin adjacent
      // pairs in a source are insertion anchors. Add each anchor only when it
      // remains compatible with the hard orders and earlier independent
      // anchors. This retains exact one-sided tier moves, combines entrants
      // introduced on opposite sides, and safely drops stale anchors when the
      // other side reordered their destination/origin underneath them.
      final outgoing = <String, Set<String>>{
        for (final id in retainedIds) id: <String>{},
      };
      final incomingCounts = <String, int>{for (final id in retainedIds) id: 0};
      void addEdge(String before, String after) {
        if (before == after || !outgoing[before]!.add(after)) return;
        incomingCounts[after] = incomingCounts[after]! + 1;
      }

      for (final order in ordersByOrigin.values) {
        for (var index = 1; index < order.length; index++) {
          addEdge(order[index - 1], order[index]);
        }
      }

      bool reaches(String start, String target) {
        final pending = <String>[start];
        final visited = <String>{};
        while (pending.isNotEmpty) {
          final current = pending.removeLast();
          if (current == target) return true;
          if (visited.add(current)) pending.addAll(outgoing[current]!);
        }
        return false;
      }

      Set<int> reorderedBaseOrigins(List<Map<String, dynamic>> source) {
        final result = <int>{};
        final sourceById = {
          for (final trip in source) trip['id']?.toString() ?? '': trip,
        };
        final sourceIndexes = _indexes(
          source.map((trip) => trip['id']?.toString() ?? '').toList(),
        );
        for (final origin in idsByOrigin.keys) {
          final originIds = baseIds
              .where((id) => originFor(id) == origin)
              .toList();
          for (var leftIndex = 0; leftIndex < originIds.length; leftIndex++) {
            for (
              var rightIndex = leftIndex + 1;
              rightIndex < originIds.length;
              rightIndex++
            ) {
              final left = originIds[leftIndex];
              final right = originIds[rightIndex];
              final leftTrip = sourceById[left];
              final rightTrip = sourceById[right];
              if (leftTrip != null &&
                  rightTrip != null &&
                  _tripPriority(leftTrip) == _tripPriority(rightTrip) &&
                  sourceIndexes[left]! > sourceIndexes[right]!) {
                result.add(origin);
              }
            }
          }
        }
        return result;
      }

      List<(String, String)> insertionAnchors(
        List<Map<String, dynamic>> source, {
        required bool destinationAnchorsRemainValid,
      }) {
        final result = <(String, String)>[];
        final sourceOrder = source
            .where(
              (trip) =>
                  retainedIds.contains(trip['id']?.toString() ?? '') &&
                  _tripPriority(trip) == targetPriority,
            )
            .map((trip) => trip['id'].toString())
            .toList();
        final sourceIdsByOrigin = <int, List<String>>{};
        for (final id in sourceOrder) {
          sourceIdsByOrigin
              .putIfAbsent(originFor(id), () => <String>[])
              .add(id);
        }
        final projectedCursors = <int, int>{};
        final projectedOrder = <String>[];
        for (final id in sourceOrder) {
          final origin = originFor(id);
          final sourceOriginIds = sourceIdsByOrigin[origin]!;
          final mergedOriginOrder = ordersByOrigin[origin]!;
          final exposesWholeOrigin =
              sourceOriginIds.toSet().length == mergedOriginOrder.length &&
              sourceOriginIds.toSet().containsAll(mergedOriginOrder);
          if (!exposesWholeOrigin) {
            projectedOrder.add(id);
            continue;
          }
          final cursor = projectedCursors[origin] ?? 0;
          projectedOrder.add(mergedOriginOrder[cursor]);
          projectedCursors[origin] = cursor + 1;
        }

        for (var index = 1; index < projectedOrder.length; index++) {
          final before = projectedOrder[index - 1];
          final after = projectedOrder[index];
          final beforeOrigin = originFor(before);
          final afterOrigin = originFor(after);
          if (beforeOrigin == afterOrigin ||
              (!destinationAnchorsRemainValid &&
                  (beforeOrigin == targetPriority ||
                      afterOrigin == targetPriority))) {
            continue;
          }
          result.add((before, after));
        }
        return result;
      }

      final remoteReorderedOrigins = reorderedBaseOrigins(remote);
      final localReorderedOrigins = reorderedBaseOrigins(local);
      final localAnchors = insertionAnchors(
        local,
        destinationAnchorsRemainValid: !remoteReorderedOrigins.contains(
          targetPriority,
        ),
      );
      final remoteAnchors = insertionAnchors(
        remote,
        destinationAnchorsRemainValid: !localReorderedOrigins.contains(
          targetPriority,
        ),
      );
      final remoteAnchorSet = remoteAnchors.toSet();
      for (final (before, after) in localAnchors) {
        if (remoteAnchorSet.contains((after, before))) {
          conflicts.add(
            'New trip order for "$before" and "$after" changed differently '
            'locally and remotely.',
          );
          return localIds;
        }
      }
      for (final (before, after) in <(String, String)>[
        ...localAnchors,
        ...remoteAnchors,
      ]) {
        if (reaches(after, before)) {
          conflicts.add(
            'Trip insertion order cannot be combined without creating a '
            'cycle involving "$before" and "$after".',
          );
          return localIds;
        }
        addEdge(before, after);
      }

      final fallbackIndexes = _indexes(fallback);
      int compareFallback(String left, String right) => _orderRank(
        fallbackIndexes,
        left,
      ).compareTo(_orderRank(fallbackIndexes, right));
      final available =
          retainedIds.where((id) => incomingCounts[id] == 0).toList()
            ..sort(compareFallback);
      final result = <String>[];
      while (available.isNotEmpty) {
        final id = available.removeAt(0);
        result.add(id);
        for (final after in outgoing[id]!) {
          incomingCounts[after] = incomingCounts[after]! - 1;
          if (incomingCounts[after] == 0) {
            available.add(after);
            available.sort(compareFallback);
          }
        }
      }
      return result;
    }

    final baseIndexes = _indexes(baseIds);
    final localIndexes = _indexes(localIds);
    final remoteIndexes = _indexes(remoteIds);
    final nodes = retainedIds.toList();
    final outgoing = <String, Set<String>>{
      for (final id in nodes) id: <String>{},
    };
    final incomingCounts = <String, int>{for (final id in nodes) id: 0};

    for (var leftIndex = 0; leftIndex < nodes.length; leftIndex++) {
      for (
        var rightIndex = leftIndex + 1;
        rightIndex < nodes.length;
        rightIndex++
      ) {
        final left = nodes[leftIndex];
        final right = nodes[rightIndex];
        final leftBaseTrip = baseById[left];
        final rightBaseTrip = baseById[right];
        final cameFromDifferentBaseTiers =
            leftBaseTrip != null &&
            rightBaseTrip != null &&
            _tripPriority(leftBaseTrip) != _tripPriority(rightBaseTrip);
        final baseBefore = _comesBeforeInSource(
          baseById,
          baseIndexes,
          left,
          right,
        );
        // Existing trips from different base tiers had no shared order to
        // edit. If status changes later bring them into one tier, treating
        // their incidental backing positions as constraints can manufacture
        // cycles with legitimate reorders inside each origin tier. Keep the
        // origin groups independent; the deterministic fallback interleaves
        // them. Constraints involving a genuinely new ID remain meaningful.
        final localBefore = cameFromDifferentBaseTiers
            ? null
            : _comesBeforeInSource(localById, localIndexes, left, right);
        final remoteBefore = cameFromDifferentBaseTiers
            ? null
            : _comesBeforeInSource(remoteById, remoteIndexes, left, right);
        bool? selected;

        if (baseBefore != null) {
          final localChanged = localBefore != null && localBefore != baseBefore;
          final remoteChanged =
              remoteBefore != null && remoteBefore != baseBefore;
          if (localChanged && remoteChanged && localBefore != remoteBefore) {
            conflicts.add(
              'Trip order for "$left" and "$right" changed differently '
              'locally and remotely.',
            );
            return localIds;
          }
          selected = localChanged
              ? localBefore
              : remoteChanged
              ? remoteBefore
              : baseBefore;
        } else if (localBefore != null && remoteBefore != null) {
          if (localBefore != remoteBefore) {
            conflicts.add(
              'New trip order for "$left" and "$right" differs locally '
              'and remotely.',
            );
            return localIds;
          }
          selected = localBefore;
        } else {
          selected = localBefore ?? remoteBefore;
        }

        if (selected == null) continue;
        final before = selected ? left : right;
        final after = selected ? right : left;
        if (outgoing[before]!.add(after)) {
          incomingCounts[after] = incomingCounts[after]! + 1;
        }
      }
    }

    // A deterministic fallback handles independent additions for which
    // neither side supplied a relative ordering constraint.
    final fallbackOrder = <String>[
      ...baseIds,
      ...remoteIds.where((id) => !baseIndexes.containsKey(id)),
      ...localIds.where(
        (id) => !baseIndexes.containsKey(id) && !remoteIndexes.containsKey(id),
      ),
    ];
    final fallbackIndexes = _indexes(fallbackOrder);
    int compareFallback(String left, String right) => _orderRank(
      fallbackIndexes,
      left,
    ).compareTo(_orderRank(fallbackIndexes, right));

    final available = nodes.where((id) => incomingCounts[id] == 0).toList()
      ..sort(compareFallback);
    final result = <String>[];
    while (available.isNotEmpty) {
      final id = available.removeAt(0);
      result.add(id);
      for (final after in outgoing[id]!) {
        incomingCounts[after] = incomingCounts[after]! - 1;
        if (incomingCounts[after] == 0) {
          available.add(after);
          available.sort(compareFallback);
        }
      }
    }

    if (result.length != nodes.length) {
      final entrants = retainedIds.difference(stableIds);
      final hasGenuinelyNewEntrant = entrants.any(
        (id) => !baseById.containsKey(id),
      );
      if (entrants.isNotEmpty && !hasGenuinelyNewEntrant) {
        final stableConflicts = <String>[];
        final stableOrder = _mergeOrder(
          base: base,
          local: local,
          remote: remote,
          retainedIds: stableIds,
          stableIds: stableIds,
          targetPriority: targetPriority,
          conflicts: stableConflicts,
        );
        if (stableConflicts.isEmpty) {
          final entrantConflicts = <String>[];
          final entrantOrder = _mergeOrder(
            base: base,
            local: local,
            remote: remote,
            retainedIds: entrants,
            // Entrants are now the complete subproblem. Marking them stable
            // prevents the cycle fallback from recursively splitting the
            // same set again, while retaining their same-tier constraints.
            stableIds: entrants,
            targetPriority: targetPriority,
            conflicts: entrantConflicts,
          );
          if (entrantConflicts.isEmpty) {
            return <String>[...stableOrder, ...entrantOrder];
          }
          conflicts.addAll(entrantConflicts);
          return localIds;
        }
      }
      conflicts.add(
        'Trip ordering changes cannot be combined without creating a cycle.',
      );
      return localIds;
    }
    return result;
  }

  static Map<String, int> _indexes(List<String> ids) => <String, int>{
    for (var index = 0; index < ids.length; index++) ids[index]: index,
  };

  static bool? _comesBeforeInSource(
    Map<String, Map<String, dynamic>> tripsById,
    Map<String, int> indexes,
    String left,
    String right,
  ) {
    final leftTrip = tripsById[left];
    final rightTrip = tripsById[right];
    if (leftTrip == null ||
        rightTrip == null ||
        _tripPriority(leftTrip) != _tripPriority(rightTrip)) {
      return null;
    }
    final leftIndex = indexes[left];
    final rightIndex = indexes[right];
    if (leftIndex == null || rightIndex == null) return null;
    return leftIndex < rightIndex;
  }

  static int _orderRank(Map<String, int> indexes, String id) =>
      indexes[id] ?? indexes.length;

  static _FieldState _fieldState(Map<String, dynamic> trip, String field) =>
      trip.containsKey(field)
      ? _FieldState.present(trip[field])
      : const _FieldState.absent();

  static bool _fieldEquals(_FieldState left, _FieldState right) =>
      left.present == right.present &&
      (!left.present || _deepEquals(left.value, right.value));

  static bool _deepEquals(Object? left, Object? right) {
    if (identical(left, right)) return true;
    if (left is List && right is List) {
      if (left.length != right.length) return false;
      for (var i = 0; i < left.length; i++) {
        if (!_deepEquals(left[i], right[i])) return false;
      }
      return true;
    }
    if (left is Map && right is Map) {
      if (left.length != right.length) return false;
      for (final key in left.keys) {
        if (!right.containsKey(key) || !_deepEquals(left[key], right[key])) {
          return false;
        }
      }
      return true;
    }
    return left == right;
  }

  static Map<String, dynamic> _copyMap(Map<String, dynamic> value) => {
    for (final entry in value.entries) entry.key: _copyValue(entry.value),
  };

  static dynamic _copyValue(dynamic value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): _copyValue(entry.value),
      };
    }
    if (value is List) return value.map(_copyValue).toList();
    return value;
  }
}

final class _FieldState {
  const _FieldState.absent() : present = false, value = null;

  const _FieldState.present(this.value) : present = true;

  final bool present;
  final dynamic value;
}
