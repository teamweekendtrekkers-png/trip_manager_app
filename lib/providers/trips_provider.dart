import 'package:flutter/foundation.dart';
import '../services/github_service.dart';
import '../services/trip_merge_service.dart';
import '../services/trips_parser.dart';
import '../models/app_settings.dart';

class TripsProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _trips = [];
  List<Map<String, dynamic>> _baseTrips = [];
  bool _isLoading = false;
  String? _error;
  String? _currentSha;
  String? _currentFeaturedSha;
  String? _tripsSource;
  String? _featuredSource;
  List<String> _publicationErrors = [];
  AppSettings _settings;
  GitHubService? _githubService;
  bool _hasUnsavedChanges = false;
  bool _hasConflict = false;
  int _settingsEpoch = 0;
  final Set<String> _intentionalDeletedIds = {};
  final Set<String> _featuredDriftIds = {};
  final GitHubService Function(AppSettings settings)? _serviceFactory;

  TripsProvider(
    this._settings, {
    GitHubService Function(AppSettings settings)? serviceFactory,
  }) : _serviceFactory = serviceFactory {
    _initService();
  }

  void _initService() {
    _githubService =
        _serviceFactory?.call(_settings) ?? GitHubService(settings: _settings);
  }

  /// Derive the featured-trips.js path from the tripsDataPath setting
  String get _featuredTripsPath {
    final dir = _settings.tripsDataPath.contains('/')
        ? _settings.tripsDataPath.substring(
            0,
            _settings.tripsDataPath.lastIndexOf('/') + 1,
          )
        : '';
    return '${dir}featured-trips.js';
  }

  List<Map<String, dynamic>> get trips => _trips;
  List<Map<String, dynamic>> get orderedTrips => _stablePriorityOrder(_trips);
  List<Map<String, dynamic>> get featuredTrips =>
      _trips.where((t) => t['featured'] == true).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasTrips => _trips.isNotEmpty;
  int get tripCount => _trips.length;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  bool get hasConflict => _hasConflict;
  String? get currentSha => _currentSha;
  String? get currentFeaturedSha => _currentFeaturedSha;
  List<String> get publicationErrors => List.unmodifiable(_publicationErrors);
  bool get hasCompleteRemoteSnapshot =>
      _tripsSource != null &&
      _featuredSource != null &&
      _currentSha != null &&
      _currentFeaturedSha != null;
  bool get canPublish =>
      hasCompleteRemoteSnapshot && _publicationErrors.isEmpty;
  Set<String> get intentionalDeletedIds =>
      Set.unmodifiable(_intentionalDeletedIds);
  Set<String> get featuredDriftIds => Set.unmodifiable(_featuredDriftIds);
  bool get hasFeaturedDrift => _featuredDriftIds.isNotEmpty;

  static int tripPriority(Map<String, dynamic> trip) {
    final active = trip['isActive'] != false;
    if (!active) return 0;
    return trip['featured'] == true ? 2 : 1;
  }

  static List<Map<String, dynamic>> _stablePriorityOrder(
    List<Map<String, dynamic>> source,
  ) {
    final featuredActive = <Map<String, dynamic>>[];
    final active = <Map<String, dynamic>>[];
    final inactive = <Map<String, dynamic>>[];
    for (final trip in source) {
      final priority = tripPriority(trip);
      if (priority == 2) {
        featuredActive.add(trip);
      } else if (priority == 1) {
        active.add(trip);
      } else {
        inactive.add(trip);
      }
    }
    return [...featuredActive, ...active, ...inactive];
  }

  void updateSettings(AppSettings settings) {
    final targetChanged =
        _settings.repositoryOwner != settings.repositoryOwner ||
        _settings.repositoryName != settings.repositoryName ||
        _settings.branch != settings.branch ||
        _settings.tripsDataPath != settings.tripsDataPath;
    final connectionChanged =
        targetChanged || _settings.githubToken != settings.githubToken;
    _settings = settings;
    if (connectionChanged) {
      _settingsEpoch++;
      // A target change cancels ownership of any in-flight operation. Its
      // network request may still complete, but epoch checks prevent it from
      // applying old-target data to this provider.
      _isLoading = false;
      _initService();
    }
    if (targetChanged) {
      _currentSha = null;
      _currentFeaturedSha = null;
      _tripsSource = null;
      _featuredSource = null;
      _publicationErrors = const ['Reload trips before publishing.'];
      _hasConflict = false;
      _error = null;
    }
    notifyListeners();
  }

  /// Load trips from GitHub (acts as git pull)
  ///
  /// This is deliberately a non-destructive entry point. Call
  /// [reloadDiscardingLocalChanges] only after the UI has explicitly confirmed
  /// that local work may be discarded.
  Future<void> loadTrips() async {
    if (_hasUnsavedChanges) {
      _error =
          'Unsaved changes were not discarded. Use refresh to merge them, or '
          'explicitly confirm a discard and reload.';
      notifyListeners();
      return;
    }
    await _loadTripsFromCurrentTarget();
  }

  /// Replace all in-memory trip state with the current remote target.
  ///
  /// The provider intentionally does not expose a `force` flag on [loadTrips],
  /// so destructive reloads remain easy to identify and double-confirm in UI.
  Future<bool> reloadDiscardingLocalChanges() async {
    if (_isLoading) return false;
    await _loadTripsFromCurrentTarget();
    return _error == null && !_hasUnsavedChanges;
  }

  Future<void> _loadTripsFromCurrentTarget() async {
    if (_githubService == null || _isLoading) return;
    final service = _githubService!;
    final operationEpoch = _settingsEpoch;
    final featuredPath = _featuredTripsPath;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('Fetching trips from GitHub...');
      final tripsFile = await service.fetchTripsData();
      if (!tripsFile.success) {
        throw StateError(tripsFile.error ?? 'Failed to load trips');
      }

      final featuredFile = await service.fetchFile(featuredPath);
      if (!featuredFile.success) {
        throw StateError(featuredFile.error ?? 'Failed to load featured trips');
      }

      final tripsDocument = TripsParser.parseTripsDocument(tripsFile.content);
      final featuredDocument = TripsParser.parseFeaturedTripsDocument(
        featuredFile.content,
      );
      if (operationEpoch != _settingsEpoch) return;
      _publicationErrors = [
        ...tripsDocument.errors.map((error) => 'trips-data.js: $error'),
        ...featuredDocument.errors.map((error) => 'featured-trips.js: $error'),
      ];

      _trips = _copyTrips(tripsDocument.trips);
      _baseTrips = _copyTrips(_trips);
      _tripsSource = tripsFile.content;
      _featuredSource = featuredFile.content;
      _currentSha = tripsFile.sha;
      _currentFeaturedSha = featuredFile.sha;
      _intentionalDeletedIds.clear();
      _updateFeaturedDrift(featuredDocument.ids, _trips);
      _hasUnsavedChanges = false;
      _hasConflict = false;

      if (_publicationErrors.isNotEmpty) {
        _error = 'Publishing blocked:\n${_publicationErrors.join('\n')}';
      } else {
        _error = null;
      }
      debugPrint('Parsed ${_trips.length} trips');
    } catch (e, stack) {
      if (operationEpoch != _settingsEpoch) return;
      _error = _readableError(e);
      debugPrint('Exception: $e');
      debugPrint('Stack: $stack');
    }

    if (operationEpoch != _settingsEpoch) return;
    _isLoading = false;
    notifyListeners();
  }

  /// Refresh trips (pull latest from remote) - useful before saving
  Future<bool> refreshTrips() async {
    if (_isLoading) return false;
    if (_hasUnsavedChanges) {
      final result = await pullAndMerge();
      return result.success;
    }
    await loadTrips();
    return _error == null;
  }

  /// Check for conflicts before saving
  Future<ConflictCheckResult?> checkForConflicts() async {
    if (_githubService == null ||
        _currentSha == null ||
        _currentFeaturedSha == null) {
      return null;
    }

    final tripsSha = await _githubService!.getLatestSha(
      _settings.tripsDataPath,
    );
    final featuredSha = await _githubService!.getLatestSha(_featuredTripsPath);
    if (tripsSha == null || featuredSha == null) {
      return ConflictCheckResult(
        hasConflict: false,
        canProceed: false,
        message: 'Could not verify both managed files.',
      );
    }
    final changed =
        tripsSha != _currentSha || featuredSha != _currentFeaturedSha;
    return ConflictCheckResult(
      hasConflict: changed,
      canProceed: !changed,
      latestSha: tripsSha,
      message: changed
          ? 'Remote managed files have changed. Save will merge them first.'
          : 'No conflicts detected',
    );
  }

  /// Save trips to GitHub with conflict detection (acts as git push)
  Future<SaveResult> saveTrips({String? commitMessage}) async {
    if (_isLoading) {
      return SaveResult(
        success: false,
        error: 'Another operation is in progress.',
      );
    }
    final snapshotError = _snapshotError();
    if (snapshotError != null) {
      return SaveResult(success: false, error: snapshotError);
    }
    final target = _captureManagedTarget();
    if (target == null) {
      return SaveResult(success: false, error: 'GitHub service not configured');
    }

    _beginOperation();
    try {
      final latest = await _fetchAndValidateManagedFiles(target);
      if (!_isCurrentTarget(target)) return _cancelledSaveResult();
      if (!latest.success) return _finishFailure(latest.error!);

      final merge = TripMergeService.merge(
        base: _baseTrips,
        local: _trips,
        remote: latest.tripsDocument!.trips,
        intentionalDeletedIds: _intentionalDeletedIds,
      );
      if (!merge.success) {
        return _finishFailure(
          'Merge conflicts:\n${merge.conflicts.join('\n')}',
          hasConflict: true,
        );
      }

      return await _publishManagedFiles(
        trips: merge.trips,
        latest: latest,
        target: target,
        commitMessage: commitMessage ?? 'Update trips via mobile app',
      );
    } catch (e, stack) {
      debugPrint('Save failed: $e\n$stack');
      if (!_isCurrentTarget(target)) return _cancelledSaveResult();
      return _finishFailure(_readableError(e));
    }
  }

  /// Force save after conflict resolution (discards remote changes)
  Future<SaveResult> forceSaveTrips({String? commitMessage}) async {
    if (_isLoading) {
      return SaveResult(
        success: false,
        error: 'Another operation is in progress.',
      );
    }
    final snapshotError = _snapshotError();
    if (snapshotError != null) {
      return SaveResult(success: false, error: snapshotError);
    }
    final target = _captureManagedTarget();
    if (target == null) {
      return SaveResult(success: false, error: 'GitHub service not configured');
    }

    _beginOperation();
    try {
      final latest = await _fetchAndValidateManagedFiles(target);
      if (!_isCurrentTarget(target)) return _cancelledSaveResult();
      if (!latest.success) return _finishFailure(latest.error!);
      return await _publishManagedFiles(
        trips: _copyTrips(_trips),
        latest: latest,
        target: target,
        commitMessage:
            commitMessage ?? 'Overwrite trips via mobile app (normal commit)',
      );
    } catch (e, stack) {
      debugPrint('Overwrite failed: $e\n$stack');
      if (!_isCurrentTarget(target)) return _cancelledSaveResult();
      return _finishFailure(_readableError(e));
    }
  }

  /// Pull and merge remote changes with local changes
  Future<MergeResult> pullAndMerge() async {
    if (_isLoading) {
      return MergeResult(
        success: false,
        error: 'Another operation is in progress.',
      );
    }
    final snapshotError = _snapshotError();
    if (snapshotError != null) {
      return MergeResult(success: false, error: snapshotError);
    }
    final target = _captureManagedTarget();
    if (target == null) {
      return MergeResult(
        success: false,
        error: 'GitHub service not configured',
      );
    }

    _beginOperation();
    try {
      final latest = await _fetchAndValidateManagedFiles(target);
      if (!_isCurrentTarget(target)) {
        return MergeResult(
          success: false,
          error: 'Repository settings changed while refreshing.',
        );
      }
      if (!latest.success) {
        final failure = _finishFailure(latest.error!);
        return MergeResult(success: false, error: failure.error);
      }

      final remoteTrips = latest.tripsDocument!.trips;
      final merge = TripMergeService.merge(
        base: _baseTrips,
        local: _trips,
        remote: remoteTrips,
        intentionalDeletedIds: _intentionalDeletedIds,
      );
      if (!merge.success) {
        final failure = _finishFailure(
          'Merge conflicts:\n${merge.conflicts.join('\n')}',
          hasConflict: true,
        );
        return MergeResult(success: false, error: failure.error);
      }

      final oldBaseIds = _baseTrips.map((trip) => trip['id']).toSet();
      final remoteIds = remoteTrips.map((trip) => trip['id']).toSet();
      _trips = _copyTrips(merge.trips);
      _baseTrips = _copyTrips(remoteTrips);
      _rememberRemoteSnapshot(latest);
      _updateFeaturedDrift(latest.featuredDocument!.ids, _trips);
      _hasConflict = false;
      _hasUnsavedChanges = true;
      _error = null;
      _isLoading = false;
      notifyListeners();

      return MergeResult(
        success: true,
        message: 'Merged successfully',
        newTripsAdded: remoteIds.difference(oldBaseIds).length,
        deletedRemotely: oldBaseIds.difference(remoteIds).length,
      );
    } catch (e, stack) {
      debugPrint('Pull and merge failed: $e\n$stack');
      if (!_isCurrentTarget(target)) {
        return MergeResult(
          success: false,
          error: 'Repository settings changed while refreshing.',
        );
      }
      final failure = _finishFailure(_readableError(e));
      return MergeResult(success: false, error: failure.error);
    }
  }

  Future<_ManagedFilesSnapshot> _fetchAndValidateManagedFiles(
    _ManagedTarget target,
  ) async {
    final tripsFile = await target.service.fetchTripsData();
    if (!_isCurrentTarget(target)) {
      return const _ManagedFilesSnapshot.failure(
        'Repository settings changed while fetching trips.',
      );
    }
    if (!tripsFile.success) {
      return _ManagedFilesSnapshot.failure(
        tripsFile.error ?? 'Failed to fetch trips-data.js.',
      );
    }
    final featuredFile = await target.service.fetchFile(target.featuredPath);
    if (!_isCurrentTarget(target)) {
      return const _ManagedFilesSnapshot.failure(
        'Repository settings changed while fetching featured trips.',
      );
    }
    if (!featuredFile.success) {
      return _ManagedFilesSnapshot.failure(
        featuredFile.error ?? 'Failed to fetch featured-trips.js.',
      );
    }

    final tripsDocument = TripsParser.parseTripsDocument(tripsFile.content);
    final featuredDocument = TripsParser.parseFeaturedTripsDocument(
      featuredFile.content,
    );
    final errors = [
      ...tripsDocument.errors.map((error) => 'trips-data.js: $error'),
      ...featuredDocument.errors.map((error) => 'featured-trips.js: $error'),
    ];
    if (errors.isNotEmpty) {
      // This validates a newly fetched candidate, not the already loaded base
      // snapshot. Keep the valid base publication state intact so a temporary
      // malformed remote revision does not poison every later retry (and
      // force the administrator to discard otherwise safe local work).
      return _ManagedFilesSnapshot.failure(
        'Publishing blocked:\n${errors.join('\n')}',
      );
    }

    return _ManagedFilesSnapshot.success(
      tripsFile: tripsFile,
      featuredFile: featuredFile,
      tripsDocument: tripsDocument,
      featuredDocument: featuredDocument,
    );
  }

  Future<SaveResult> _publishManagedFiles({
    required List<Map<String, dynamic>> trips,
    required _ManagedFilesSnapshot latest,
    required _ManagedTarget target,
    required String commitMessage,
  }) async {
    if (!_isCurrentTarget(target)) return _cancelledSaveResult();
    final tripsWrite = TripsParser.replaceTripsDataObject(
      source: latest.tripsFile!.content,
      trips: trips,
    );
    if (!tripsWrite.success) {
      return _finishFailure(
        'Publishing blocked:\n${tripsWrite.errors.join('\n')}',
      );
    }

    final featuredIds = trips
        .where((trip) => trip['featured'] == true)
        .map((trip) => trip['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    final featuredWrite = TripsParser.replaceFeaturedTripIdsArray(
      source: latest.featuredFile!.content,
      ids: featuredIds,
    );
    if (!featuredWrite.success) {
      return _finishFailure(
        'Publishing blocked:\n${featuredWrite.errors.join('\n')}',
      );
    }

    if (!_isCurrentTarget(target)) return _cancelledSaveResult();
    final result = await target.service.commitFilesAtomically(
      files: {
        target.tripsPath: tripsWrite.content!,
        target.featuredPath: featuredWrite.content!,
      },
      expectedBlobShas: {
        target.tripsPath: latest.tripsFile!.sha,
        target.featuredPath: latest.featuredFile!.sha,
      },
      commitMessage: commitMessage,
    );
    if (!_isCurrentTarget(target)) {
      return SaveResult(
        success: result.success,
        commitSha: result.commitSha,
        error: result.success
            ? null
            : result.error ?? 'The previous-target save did not complete.',
        message: result.success
            ? 'The save completed for the previously selected repository. '
                  'Reload the current repository before continuing.'
            : null,
      );
    }
    if (!result.success) {
      return _finishFailure(
        result.error ?? 'Failed to commit managed trip files.',
        hasConflict: result.hasConflict,
      );
    }

    final committedDocument = TripsParser.parseTripsDocument(
      tripsWrite.content!,
    );
    _trips = _copyTrips(committedDocument.trips);
    _baseTrips = _copyTrips(_trips);
    _tripsSource = tripsWrite.content;
    _featuredSource = featuredWrite.content;
    _currentSha = result.fileBlobShas[target.tripsPath];
    _currentFeaturedSha = result.fileBlobShas[target.featuredPath];
    _publicationErrors = [];
    if (_currentSha == null || _currentFeaturedSha == null) {
      _publicationErrors = const [
        'Save succeeded, but the new blob SHAs were unavailable. Reload before publishing again.',
      ];
    }
    _intentionalDeletedIds.clear();
    _featuredDriftIds.clear();
    _hasUnsavedChanges = false;
    _hasConflict = false;
    _error = null;
    _isLoading = false;
    notifyListeners();
    return SaveResult(
      success: true,
      commitSha: result.commitSha,
      message: 'Changes saved successfully!',
    );
  }

  void _rememberRemoteSnapshot(_ManagedFilesSnapshot snapshot) {
    _tripsSource = snapshot.tripsFile!.content;
    _featuredSource = snapshot.featuredFile!.content;
    _currentSha = snapshot.tripsFile!.sha;
    _currentFeaturedSha = snapshot.featuredFile!.sha;
    _publicationErrors = [];
  }

  void _updateFeaturedDrift(
    List<String> companionIds,
    List<Map<String, dynamic>> trips,
  ) {
    final embeddedIds = trips
        .where((trip) => trip['featured'] == true)
        .map((trip) => trip['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    final embeddedSet = embeddedIds.toSet();
    final companionSet = companionIds.toSet();
    _featuredDriftIds
      ..clear()
      ..addAll(embeddedSet.difference(companionSet))
      ..addAll(companionSet.difference(embeddedSet));

    // The homepage consumes this array in order, so equal membership with a
    // different sequence is still real drift. Mark only IDs whose positions
    // differ to keep the Data Health report actionable.
    for (final id in embeddedSet.intersection(companionSet)) {
      if (embeddedIds.indexOf(id) != companionIds.indexOf(id)) {
        _featuredDriftIds.add(id);
      }
    }
  }

  _ManagedTarget? _captureManagedTarget() {
    final service = _githubService;
    if (service == null) return null;
    return _ManagedTarget(
      epoch: _settingsEpoch,
      service: service,
      tripsPath: _settings.tripsDataPath,
      featuredPath: _featuredTripsPath,
    );
  }

  bool _isCurrentTarget(_ManagedTarget target) =>
      target.epoch == _settingsEpoch &&
      identical(target.service, _githubService) &&
      target.tripsPath == _settings.tripsDataPath &&
      target.featuredPath == _featuredTripsPath;

  SaveResult _cancelledSaveResult() => SaveResult(
    success: false,
    error:
        'Repository settings changed while publishing. Reload before saving.',
  );

  String? _snapshotError() {
    if (_githubService == null) return 'GitHub service not configured';
    if (_publicationErrors.isNotEmpty) {
      return 'Publishing blocked:\n${_publicationErrors.join('\n')}';
    }
    if (_tripsSource == null ||
        _featuredSource == null ||
        _currentSha == null ||
        _currentFeaturedSha == null) {
      return 'No complete remote snapshot is loaded. Refresh before saving.';
    }
    return null;
  }

  void _beginOperation() {
    _isLoading = true;
    _error = null;
    notifyListeners();
  }

  SaveResult _finishFailure(String error, {bool hasConflict = false}) {
    _error = error;
    _hasConflict = hasConflict;
    _isLoading = false;
    notifyListeners();
    return SaveResult(success: false, hasConflict: hasConflict, error: error);
  }

  static String _readableError(Object error) {
    if (error is StateError) return error.message;
    return error.toString();
  }

  /// Add a new trip with duplicate ID validation
  /// Returns error message if duplicate found, null on success
  String? addTrip(Map<String, dynamic> trip) {
    if (_isLoading) return 'Another operation is in progress.';
    final newId = trip['id']?.toString();
    if (newId != null && newId.isNotEmpty) {
      final existingIndex = _trips.indexWhere((t) => t['id'] == newId);
      if (existingIndex >= 0) {
        return 'Duplicate trip ID "$newId" already exists at position ${existingIndex + 1}. Please use a unique ID.';
      }
    }
    _trips.add(trip);
    if (newId != null) _intentionalDeletedIds.remove(newId);
    _hasUnsavedChanges = true;
    notifyListeners();
    return null;
  }

  void updateTrip(int index, Map<String, dynamic> trip) {
    if (_isLoading) return;
    if (index >= 0 && index < _trips.length) {
      _trips[index] = trip;
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  void deleteTrip(int index) {
    if (_isLoading) return;
    if (index >= 0 && index < _trips.length) {
      final id = _trips[index]['id']?.toString();
      if (id != null && id.isNotEmpty) _intentionalDeletedIds.add(id);
      _trips.removeAt(index);
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  /// Reorder the derived display list without allowing an item to cross its
  /// featured/active priority boundary. Returns false for a cross-tier move.
  bool reorderTrips(int oldIndex, int newIndex) {
    if (_isLoading) return false;
    final displayed = orderedTrips;
    if (oldIndex < 0 || oldIndex >= displayed.length) return false;
    if (newIndex > oldIndex) newIndex -= 1;

    final item = displayed.removeAt(oldIndex);
    final priority = tripPriority(item);
    final tierStart = displayed
        .where((trip) => tripPriority(trip) > priority)
        .length;
    final tierLength = displayed
        .where((trip) => tripPriority(trip) == priority)
        .length;
    final tierEnd = tierStart + tierLength;
    if (newIndex < tierStart || newIndex > tierEnd) return false;

    final insertionIndex = newIndex.clamp(0, displayed.length);
    displayed.insert(insertionIndex, item);
    final reorderedTier = displayed
        .where((trip) => tripPriority(trip) == priority)
        .toList();
    final backingTierIndexes = <int>[
      for (var index = 0; index < _trips.length; index++)
        if (tripPriority(_trips[index]) == priority) index,
    ];
    for (var index = 0; index < backingTierIndexes.length; index++) {
      _trips[backingTierIndexes[index]] = reorderedTier[index];
    }
    _hasUnsavedChanges = true;
    notifyListeners();
    return true;
  }

  void toggleFeatured(int index) {
    if (_isLoading) return;
    if (index >= 0 && index < _trips.length) {
      _trips[index]['featured'] = !(_trips[index]['featured'] ?? false);
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  Map<String, dynamic>? getTripById(String id) {
    try {
      return _trips.firstWhere((t) => t['id'] == id);
    } catch (_) {
      return null;
    }
  }

  int? getTripIndexById(String id) {
    for (int i = 0; i < _trips.length; i++) {
      if (_trips[i]['id'] == id) return i;
    }
    return null;
  }

  List<Map<String, dynamic>> searchTrips(String query) {
    final ordered = orderedTrips;
    if (query.isEmpty) return ordered;
    final lowerQuery = query.toLowerCase();
    return ordered.where((t) {
      final name = (t['name'] ?? t['title'] ?? '').toString().toLowerCase();
      final destination = (t['destination'] ?? t['location'] ?? '')
          .toString()
          .toLowerCase();
      return name.contains(lowerQuery) || destination.contains(lowerQuery);
    }).toList();
  }

  static List<Map<String, dynamic>> _copyTrips(
    List<Map<String, dynamic>> trips,
  ) => trips.map(_copyMap).toList();

  static Map<String, dynamic> _copyMap(Map<String, dynamic> source) => {
    for (final entry in source.entries) entry.key: _copyValue(entry.value),
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

  void clearError() {
    _error = null;
    _hasConflict = false;
    notifyListeners();
  }

  void markChangesSaved() {
    _hasUnsavedChanges = false;
    notifyListeners();
  }

  /// Public method to mark data as modified and notify listeners.
  /// Used by screens that directly mutate trip data (e.g., Data Health auto-fix).
  void markDataModified() {
    if (_isLoading) return;
    _hasUnsavedChanges = true;
    notifyListeners();
  }
}

/// Result of a save operation
class SaveResult {
  final bool success;
  final bool hasConflict;
  final String? commitSha;
  final String? message;
  final String? error;

  SaveResult({
    required this.success,
    this.hasConflict = false,
    this.commitSha,
    this.message,
    this.error,
  });
}

/// Result of a merge operation
class MergeResult {
  final bool success;
  final String? message;
  final String? error;
  final int newTripsAdded;
  final int deletedRemotely;

  MergeResult({
    required this.success,
    this.message,
    this.error,
    this.newTripsAdded = 0,
    this.deletedRemotely = 0,
  });
}

class _ManagedFilesSnapshot {
  final bool success;
  final String? error;
  final GitHubFileResult? tripsFile;
  final GitHubFileResult? featuredFile;
  final TripsDataDocumentResult? tripsDocument;
  final FeaturedTripsDocumentResult? featuredDocument;

  const _ManagedFilesSnapshot.success({
    required GitHubFileResult this.tripsFile,
    required GitHubFileResult this.featuredFile,
    required TripsDataDocumentResult this.tripsDocument,
    required FeaturedTripsDocumentResult this.featuredDocument,
  }) : success = true,
       error = null;

  const _ManagedFilesSnapshot.failure(String failure)
    : success = false,
      error = failure,
      tripsFile = null,
      featuredFile = null,
      tripsDocument = null,
      featuredDocument = null;
}

class _ManagedTarget {
  final int epoch;
  final GitHubService service;
  final String tripsPath;
  final String featuredPath;

  const _ManagedTarget({
    required this.epoch,
    required this.service,
    required this.tripsPath,
    required this.featuredPath,
  });
}
