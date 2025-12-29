import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_settings.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _boxName = 'settings';
  static const String _settingsKey = 'app_settings';
  
  AppSettings _settings = AppSettings();
  bool _isInitialized = false;

  AppSettings get settings => _settings;
  bool get isInitialized => _isInitialized;
  bool get isConfigured => _settings.githubToken.isNotEmpty;

  Future<void> init() async {
    await Hive.initFlutter();
    
    final box = await Hive.openBox(_boxName);
    final jsonStr = box.get(_settingsKey);
    
    if (jsonStr != null) {
      try {
        final json = jsonDecode(jsonStr);
        _settings = AppSettings.fromJson(json);
      } catch (_) {
        _settings = AppSettings();
      }
    }
    
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> saveSettings(AppSettings newSettings) async {
    _settings = newSettings;
    final box = await Hive.openBox(_boxName);
    await box.put(_settingsKey, jsonEncode(newSettings.toJson()));
    notifyListeners();
  }

  Future<void> updateGithubToken(String token) async {
    await saveSettings(_settings.copyWith(githubToken: token));
  }

  Future<void> updateRepository({
    String? owner,
    String? name,
    String? branch,
  }) async {
    await saveSettings(_settings.copyWith(
      repositoryOwner: owner,
      repositoryName: name,
      branch: branch,
    ));
  }

  Future<void> toggleDarkMode() async {
    await saveSettings(_settings.copyWith(darkMode: !_settings.darkMode));
  }

  Future<void> clearSettings() async {
    final box = await Hive.openBox(_boxName);
    await box.clear();
    _settings = AppSettings();
    notifyListeners();
  }
}
