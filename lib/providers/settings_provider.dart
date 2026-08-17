import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_settings.dart';

abstract interface class SettingsStore {
  Future<void> init();

  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> clear();
}

final class HiveSettingsStore implements SettingsStore {
  static const String _boxName = 'settings';

  @override
  Future<void> init() => Hive.initFlutter();

  @override
  Future<String?> read(String key) async {
    final box = await Hive.openBox(_boxName);
    final value = box.get(key);
    // Older/corrupt app versions may have persisted a non-JSON value under
    // this key. Treat it as missing so startup falls back to safe defaults
    // instead of throwing before SettingsProvider's JSON recovery can run.
    return value is String ? value : null;
  }

  @override
  Future<void> write(String key, String value) async {
    final box = await Hive.openBox(_boxName);
    await box.put(key, value);
  }

  @override
  Future<void> clear() async {
    final box = await Hive.openBox(_boxName);
    await box.clear();
  }
}

class SettingsProvider extends ChangeNotifier {
  static const String _settingsKey = 'app_settings';
  final SettingsStore _store;

  AppSettings _settings = AppSettings();
  bool _isInitialized = false;

  SettingsProvider({SettingsStore? store})
    : _store = store ?? HiveSettingsStore();

  AppSettings get settings => _settings;
  bool get isInitialized => _isInitialized;
  bool get isConfigured => _settings.githubToken.isNotEmpty;

  Future<void> init() async {
    await _store.init();
    final jsonStr = await _store.read(_settingsKey);

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
    await _store.write(_settingsKey, jsonEncode(newSettings.toJson()));
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
    await saveSettings(
      _settings.copyWith(
        repositoryOwner: owner,
        repositoryName: name,
        branch: branch,
      ),
    );
  }

  Future<void> toggleDarkMode() async {
    await saveSettings(_settings.copyWith(darkMode: !_settings.darkMode));
  }

  Future<void> clearSettings() async {
    await _store.clear();
    _settings = AppSettings();
    notifyListeners();
  }
}
