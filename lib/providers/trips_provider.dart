import 'package:flutter/foundation.dart';
import '../services/github_service.dart';
import '../services/trips_parser.dart';
import '../models/app_settings.dart';

class TripsProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _trips = [];
  bool _isLoading = false;
  String? _error;
  String? _currentSha;
  AppSettings _settings;
  GitHubService? _githubService;
  bool _hasUnsavedChanges = false;
  bool _hasConflict = false;

  TripsProvider(this._settings) {
    _initService();
  }

  void _initService() {
    _githubService = GitHubService(settings: _settings);
  }

  List<Map<String, dynamic>> get trips => _trips;
  List<Map<String, dynamic>> get featuredTrips => 
      _trips.where((t) => t['featured'] == true).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasTrips => _trips.isNotEmpty;
  int get tripCount => _trips.length;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  bool get hasConflict => _hasConflict;
  String? get currentSha => _currentSha;

  void updateSettings(AppSettings settings) {
    _settings = settings;
    _initService();
    notifyListeners();
  }

  /// Load trips from GitHub (acts as git pull)
  Future<void> loadTrips() async {
    if (_githubService == null) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('Fetching trips from GitHub...');
      final result = await _githubService!.fetchTripsData();
      
      if (result.success) {
        debugPrint('Got content, parsing...');
        debugPrint('Content length: ${result.content.length}');
        _trips = TripsParser.parseTripsData(result.content);
        debugPrint('Parsed ${_trips.length} trips');
        _currentSha = result.sha;
        _error = null;
        _hasUnsavedChanges = false;
        _hasConflict = false;
      } else {
        _error = result.error ?? 'Failed to load trips';
        debugPrint('Error: $_error');
      }
    } catch (e, stack) {
      _error = e.toString();
      debugPrint('Exception: $e');
      debugPrint('Stack: $stack');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Refresh trips (pull latest from remote) - useful before saving
  Future<bool> refreshTrips() async {
    if (_githubService == null) return false;
    
    try {
      final result = await _githubService!.fetchTripsData();
      if (result.success) {
        _currentSha = result.sha;
        _hasConflict = false;
        return true;
      }
    } catch (e) {
      debugPrint('Refresh error: $e');
    }
    return false;
  }

  /// Check for conflicts before saving
  Future<ConflictCheckResult?> checkForConflicts() async {
    if (_githubService == null || _currentSha == null) return null;
    
    return await _githubService!.checkForConflicts(
      _settings.tripsDataPath,
      _currentSha!,
    );
  }

  /// Save trips to GitHub with conflict detection (acts as git push)
  Future<SaveResult> saveTrips({String? commitMessage}) async {
    if (_githubService == null) {
      return SaveResult(success: false, error: 'GitHub service not configured');
    }
    
    if (_currentSha == null) {
      return SaveResult(success: false, error: 'No SHA available. Please refresh first.');
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Step 1: Check for conflicts (like git fetch + compare)
      debugPrint('Checking for conflicts...');
      final conflictCheck = await _githubService!.checkForConflicts(
        _settings.tripsDataPath,
        _currentSha!,
      );
      
      if (conflictCheck.hasConflict) {
        _hasConflict = true;
        _error = conflictCheck.message;
        _isLoading = false;
        notifyListeners();
        return SaveResult(
          success: false,
          hasConflict: true,
          error: conflictCheck.message ?? 'Remote file has been modified',
        );
      }

      // Step 2: Generate the updated content
      debugPrint('Generating trips data...');
      final jsContent = TripsParser.generateTripsDataJs(_trips);

      // Step 3: Push the changes
      debugPrint('Pushing changes to GitHub...');
      final result = await _githubService!.updateTripsData(
        content: jsContent,
        sha: _currentSha!,
        commitMessage: commitMessage ?? 'Update trips via mobile app',
      );
      
      if (result.success) {
        // Step 4: Reload to get new SHA (like git pull after push)
        debugPrint('Reloading to get new SHA...');
        await loadTrips();
        _hasUnsavedChanges = false;
        return SaveResult(
          success: true,
          commitSha: result.commitSha,
          message: 'Changes saved successfully!',
        );
      } else {
        if (result.hasConflict) {
          _hasConflict = true;
        }
        _error = result.error ?? 'Failed to save trips';
        _isLoading = false;
        notifyListeners();
        return SaveResult(
          success: false,
          hasConflict: result.hasConflict,
          error: _error,
        );
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return SaveResult(success: false, error: _error);
    }
  }

  /// Force save after conflict resolution (discards remote changes)
  Future<SaveResult> forceSaveTrips({String? commitMessage}) async {
    if (_githubService == null) {
      return SaveResult(success: false, error: 'GitHub service not configured');
    }
    
    // First get the latest SHA
    final latestSha = await _githubService!.getLatestSha(_settings.tripsDataPath);
    if (latestSha == null) {
      return SaveResult(success: false, error: 'Could not get latest file version');
    }
    
    _currentSha = latestSha;
    
    // Now save with the latest SHA
    return saveTrips(commitMessage: commitMessage ?? 'Force update trips via mobile app');
  }

  /// Pull and merge remote changes with local changes
  Future<MergeResult> pullAndMerge() async {
    if (_githubService == null) {
      return MergeResult(success: false, error: 'GitHub service not configured');
    }

    try {
      // Store local changes
      final localTrips = List<Map<String, dynamic>>.from(_trips);
      
      // Fetch remote
      final result = await _githubService!.fetchTripsData();
      if (!result.success) {
        return MergeResult(success: false, error: result.error);
      }
      
      // Parse remote trips
      final remoteTrips = TripsParser.parseTripsData(result.content);
      
      // Simple merge: keep local changes for existing trips, add new remote trips
      final mergedTrips = <Map<String, dynamic>>[];
      final localIds = localTrips.map((t) => t['id']).toSet();
      final remoteIds = remoteTrips.map((t) => t['id']).toSet();
      
      // Add all local trips (preserving local changes)
      mergedTrips.addAll(localTrips);
      
      // Add new remote trips that don't exist locally
      for (final remoteTrip in remoteTrips) {
        if (!localIds.contains(remoteTrip['id'])) {
          mergedTrips.add(remoteTrip);
        }
      }
      
      // Find trips that were deleted remotely
      final deletedRemotely = localIds.difference(remoteIds);
      
      _trips = mergedTrips;
      _currentSha = result.sha;
      _hasConflict = false;
      _hasUnsavedChanges = true; // Mark as needing save after merge
      notifyListeners();
      
      return MergeResult(
        success: true,
        message: 'Merged successfully',
        newTripsAdded: remoteIds.difference(localIds).length,
        deletedRemotely: deletedRemotely.length,
      );
    } catch (e) {
      return MergeResult(success: false, error: e.toString());
    }
  }

  void addTrip(Map<String, dynamic> trip) {
    _trips.add(trip);
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void updateTrip(int index, Map<String, dynamic> trip) {
    if (index >= 0 && index < _trips.length) {
      _trips[index] = trip;
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  void deleteTrip(int index) {
    if (index >= 0 && index < _trips.length) {
      _trips.removeAt(index);
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  void reorderTrips(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = _trips.removeAt(oldIndex);
    _trips.insert(newIndex, item);
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void toggleFeatured(int index) {
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
    if (query.isEmpty) return _trips;
    final lowerQuery = query.toLowerCase();
    return _trips.where((t) {
      final name = (t['name'] ?? t['title'] ?? '').toString().toLowerCase();
      final destination = (t['destination'] ?? t['location'] ?? '').toString().toLowerCase();
      return name.contains(lowerQuery) || destination.contains(lowerQuery);
    }).toList();
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
