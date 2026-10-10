import 'dart:convert';
import '../models/homepage_config.dart';
import 'github_service.dart';

/// Publishes only the dedicated homepage JSON using optimistic concurrency.
class HomepageSettingsService {
  HomepageSettingsService(this.github);
  final GitHubService github;
  static const path = 'js/homepage-config.json';
  HomepageConfig? _base;
  String? _sha;

  Future<HomepageConfig> load() async {
    final snapshot = await _fetch();
    _base = snapshot.$1;
    _sha = snapshot.$2;
    return snapshot.$1;
  }

  Future<(HomepageConfig, String?)> _fetch() async {
    final file = await github.fetchFile(path);
    if (!file.success) {
      if (file.statusCode == 404) return (HomepageConfig.initial(), null);
      throw StateError(file.error ?? 'Cannot load homepage configuration.');
    }
    return (HomepageConfig.parse(file.content), file.sha);
  }

  static HomepageConfig merge(
    HomepageConfig base,
    HomepageConfig local,
    HomepageConfig remote,
  ) {
    final conflicts = <String>[];
    Object? combine(
      Object? before,
      Object? ours,
      Object? theirs,
      String field,
    ) {
      if (_same(ours, before)) return theirs;
      if (_same(theirs, before) || _same(ours, theirs)) return ours;
      if (before is Map && ours is Map && theirs is Map) {
        return {
          for (final key in before.keys)
            key: combine(
              before[key],
              ours[key],
              theirs[key],
              field.isEmpty ? '$key' : '$field.$key',
            ),
        };
      }
      conflicts.add(field);
      return ours;
    }

    final merged = combine(base.toJson(), local.toJson(), remote.toJson(), '');
    if (conflicts.isNotEmpty) {
      throw StateError(
        'Homepage conflicts: ${conflicts.join(', ')}. Your edits are retained; reload only if you want to discard them.',
      );
    }
    return HomepageConfig.parse(jsonEncode(merged));
  }

  Future<GitHubCommitResult> save(HomepageConfig draft) async {
    if (_base == null) {
      return GitHubCommitResult(
        success: false,
        error: 'Load homepage settings before publishing.',
      );
    }
    try {
      for (var attempt = 0; attempt < 3; attempt++) {
        final latest = await _fetch();
        final merged = merge(_base!, draft, latest.$1);
        if (_same(merged.toJson(), latest.$1.toJson()) && latest.$2 != null) {
          _base = merged;
          _sha = latest.$2;
          return GitHubCommitResult(
            success: true,
            message: 'Homepage already matches your changes.',
          );
        }
        final result = await github.commitFilesAtomically(
          files: {path: merged.encode()},
          expectedBlobShas: {path: latest.$2},
          commitMessage: 'Customize homepage via Trip Manager',
        );
        if (result.success) {
          _base = merged;
          _sha = result.fileBlobShas[path];
          return result;
        }
        if (!result.hasConflict) return result;
      }
      return GitHubCommitResult(
        success: false,
        hasConflict: true,
        error:
            'The branch keeps changing. Your edits are retained; try publishing again.',
      );
    } catch (error) {
      return GitHubCommitResult(
        success: false,
        hasConflict: error.toString().contains('Homepage conflicts:'),
        error: error.toString(),
      );
    }
  }

  HomepageConfig? get savedConfig => _base;
  String? get currentSha => _sha;
}

/// Recursive equality without adding a dependency or treating JSON key order as data.
bool _same(Object? left, Object? right) =>
    jsonEncode(_sorted(left)) == jsonEncode(_sorted(right));
Object? _sorted(Object? value) {
  if (value is Map) {
    return {
      for (final key in (value.keys.cast<String>().toList()..sort()))
        key: _sorted(value[key]),
    };
  }
  if (value is List) return value.map(_sorted).toList();
  return value;
}
