import 'dart:convert';
import 'github_service.dart';
import '../models/trip_content_settings.dart';

class TripContentService {
  TripContentService(this.github);
  final GitHubService github;
  static const path = 'js/trip-content-config.json';
  String? _sha;
  String? _base;
  Future<Map<String, dynamic>> load() async {
    final file = await github.fetchFile(path);
    if (!file.success) throw StateError(file.error ?? 'Cannot load shared trip content. Publish the website update first.');
    final config = Map<String, dynamic>.from(jsonDecode(file.content) as Map);
    if (config['version'] != 1 || config['sections'] is! Map) throw const FormatException('Unsupported shared content.');
    TripContentSettings.validate(config['sections'] as Map, shared: true);
    _sha = file.sha; _base = file.content;
    return config;
  }
  Future<GitHubCommitResult> save(Map<String,dynamic> config) async {
    try {
      if (_base == null) throw StateError('Load settings before publishing.');
      TripContentSettings.validate(config['sections'] as Map, shared: true);
      final latest = await github.fetchFile(path);
      if (!latest.success || latest.sha != _sha || latest.content != _base) return GitHubCommitResult(success:false, hasConflict:true, error:'Shared content changed remotely. Your edits are retained; reload before publishing.');
      final text = '${const JsonEncoder.withIndent('  ').convert(config)}\n';
      final compiled = 'window.TRIP_CONTENT_CONFIG = ${jsonEncode(config)};\n';
      final oldCompiled = await github.fetchFile('js/trip-content-defaults.js');
      if (!oldCompiled.success) throw StateError('Cannot load shared content defaults.');
      final result = await github.commitFilesAtomically(files:{path:text,'js/trip-content-defaults.js':compiled}, expectedBlobShas:{path:_sha,'js/trip-content-defaults.js':oldCompiled.sha},commitMessage:'Update shared trip content via Trip Manager');
      if(result.success){_sha=result.fileBlobShas[path];_base=text;}
      return result;
    } catch(error) {return GitHubCommitResult(success:false,error:error.toString());}
  }
}
