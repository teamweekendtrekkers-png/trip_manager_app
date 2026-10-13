import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_settings.dart';

/// Local drafts never contain credentials and are isolated by repository,
/// branch and managed data path. Publishing always rechecks the remote files.
abstract final class DraftStore {
  static Box<String>? _box;
  static Future<void> _writes = Future.value();
  static bool get available => _box != null;
  static String? error;
  static Future<void> init() async {
    try {
      _box = await Hive.openBox<String>('manager_drafts_v1');
      error = null;
    } catch (e) {
      error = 'Local draft storage is unavailable: $e';
    }
  }

  static Future<void> recordPublication(String scope, String? commit) async {
    if (!available) return;
    try {
      await write(scope, 'publication', {
        'commit': commit,
        'publishedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      error = 'Published successfully, but local status could not be saved: $e';
    }
  }

  static Future<void> close() async {
    await _writes.catchError((Object _) {});
    await _box?.close();
    _box = null;
    _writes = Future.value();
  }

  static String scope(AppSettings settings) => jsonEncode([
    settings.repositoryOwner,
    settings.repositoryName,
    settings.branch,
    settings.tripsDataPath,
  ]);
  static String _key(String scope, String slot) => '$scope::$slot';
  static Map<String, dynamic>? read(String scope, String slot) {
    try {
      final raw = _box?.get(_key(scope, slot));
      return raw == null
          ? null
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(
    String scope,
    String slot,
    Map<String, dynamic> data,
  ) {
    final encoded = jsonEncode({
      'savedAt': DateTime.now().toIso8601String(),
      'data': data,
    });
    final operation = _writes.catchError((Object _) {}).then((_) async {
      await _box?.put(_key(scope, slot), encoded);
    });
    _writes = operation;
    return operation;
  }

  static Future<void> remove(String scope, String slot) {
    if (!available) return Future.value();
    final operation = _writes.catchError((Object _) {}).then((_) async {
      await _box?.delete(_key(scope, slot));
    });
    _writes = operation;
    return operation;
  }

  static List<Map<String, dynamic>> history(String scope, String slot) {
    final record = read(scope, 'history:$slot');
    return (record?['data']?['items'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static List<Map<String, dynamic>> tripVersions(String scope, String id) => [
    for (final record in history(scope, 'workspace'))
      for (final trip in record['data']['trips'] as List? ?? [])
        if (trip is Map && trip['id'] == id)
          {...record, 'data': Map<String, dynamic>.from(trip)},
  ];

  static Future<void> remember(
    String scope,
    String slot,
    Map<String, dynamic> data,
    String label,
  ) async {
    final items = history(scope, slot);
    if (items.isNotEmpty && jsonEncode(items.first['data']) == jsonEncode(data))
      return;
    items.insert(0, {
      'label': label,
      'time': DateTime.now().toIso8601String(),
      'data': data,
    });
    await write(scope, 'history:$slot', {'items': items.take(20).toList()});
  }
}
