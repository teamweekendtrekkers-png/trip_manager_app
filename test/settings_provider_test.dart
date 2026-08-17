import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/providers/settings_provider.dart';

final class MemorySettingsStore implements SettingsStore {
  final Map<String, String> values = <String, String>{};
  bool initialized = false;

  @override
  Future<void> init() async => initialized = true;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> clear() async => values.clear();
}

final class NonStringCompatibleStore implements SettingsStore {
  Object? value = 42;

  @override
  Future<void> init() async {}

  @override
  Future<String?> read(String key) async =>
      value is String ? value as String : null;

  @override
  Future<void> write(String key, String value) async => this.value = value;

  @override
  Future<void> clear() async => value = null;
}

void main() {
  test(
    'restores every setting including dark mode from injected storage',
    () async {
      final store = MemorySettingsStore();
      final first = SettingsProvider(store: store);
      await first.init();
      await first.saveSettings(
        AppSettings(
          githubToken: 'token',
          repositoryOwner: 'owner',
          repositoryName: 'repository',
          branch: 'release',
          tripsDataPath: 'data/trips.js',
          whatsappNumber: '911234567890',
          upiId: 'team@bank',
          darkMode: true,
        ),
      );

      final restored = SettingsProvider(store: store);
      await restored.init();

      expect(store.initialized, isTrue);
      expect(restored.isInitialized, isTrue);
      expect(restored.isConfigured, isTrue);
      expect(restored.settings.githubToken, 'token');
      expect(restored.settings.repositoryOwner, 'owner');
      expect(restored.settings.repositoryName, 'repository');
      expect(restored.settings.branch, 'release');
      expect(restored.settings.tripsDataPath, 'data/trips.js');
      expect(restored.settings.whatsappNumber, '911234567890');
      expect(restored.settings.upiId, 'team@bank');
      expect(restored.settings.darkMode, isTrue);
    },
  );

  test('invalid stored JSON safely restores defaults', () async {
    final store = MemorySettingsStore()..values['app_settings'] = '{bad';
    final provider = SettingsProvider(store: store);

    await provider.init();

    expect(provider.settings.repositoryName, 'teamweekendtrekkerwebsite');
    expect(provider.settings.darkMode, isFalse);
  });

  test('legacy non-string storage safely restores defaults', () async {
    final provider = SettingsProvider(store: NonStringCompatibleStore());

    await expectLater(provider.init(), completes);

    expect(provider.isInitialized, isTrue);
    expect(provider.settings.repositoryName, 'teamweekendtrekkerwebsite');
    expect(provider.settings.githubToken, isEmpty);
  });

  test('toggle and clear persist their behavior', () async {
    final store = MemorySettingsStore();
    final provider = SettingsProvider(store: store);
    await provider.init();

    await provider.toggleDarkMode();
    expect(provider.settings.darkMode, isTrue);
    expect(store.values, isNotEmpty);

    await provider.clearSettings();
    expect(provider.settings.darkMode, isFalse);
    expect(provider.settings.githubToken, isEmpty);
    expect(store.values, isEmpty);
  });
}
