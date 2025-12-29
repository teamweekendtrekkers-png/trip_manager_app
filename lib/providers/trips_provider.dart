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

  void updateSettings(AppSettings settings) {
    _settings = settings;
    _initService();
    notifyListeners();
  }

  Future<void> loadTrips() async {
    if (_githubService == null) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _githubService!.fetchTripsData();
      
      if (result.success) {
        _trips = TripsParser.parseTripsData(result.content);
        _currentSha = result.sha;
        _error = null;
      } else {
        _error = result.error ?? 'Failed to load trips';
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> saveTrips({String? commitMessage}) async {
    if (_githubService == null || _currentSha == null) return false;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final jsContent = TripsParser.generateTripsDataJs(_trips);
      final result = await _githubService!.updateTripsData(
        content: jsContent,
        sha: _currentSha!,
        commitMessage: commitMessage ?? 'Update trips via mobile app',
      );
      
      if (result.success) {
        // Reload to get new SHA
        await loadTrips();
        return true;
      } else {
        _error = result.error ?? 'Failed to save trips';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void addTrip(Map<String, dynamic> trip) {
    _trips.add(trip);
    notifyListeners();
  }

  void updateTrip(int index, Map<String, dynamic> trip) {
    if (index >= 0 && index < _trips.length) {
      _trips[index] = trip;
      notifyListeners();
    }
  }

  void deleteTrip(int index) {
    if (index >= 0 && index < _trips.length) {
      _trips.removeAt(index);
      notifyListeners();
    }
  }

  void reorderTrips(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = _trips.removeAt(oldIndex);
    _trips.insert(newIndex, item);
    notifyListeners();
  }

  void toggleFeatured(int index) {
    if (index >= 0 && index < _trips.length) {
      _trips[index]['featured'] = !(_trips[index]['featured'] ?? false);
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
      final name = (t['name'] ?? '').toString().toLowerCase();
      final destination = (t['destination'] ?? '').toString().toLowerCase();
      return name.contains(lowerQuery) || destination.contains(lowerQuery);
    }).toList();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
