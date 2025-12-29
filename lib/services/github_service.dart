import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/app_settings.dart';

class GitHubService {
  final Dio _dio;
  final AppSettings settings;

  GitHubService({required this.settings})
      : _dio = Dio(BaseOptions(
          baseUrl: 'https://api.github.com',
          headers: {
            'Accept': 'application/vnd.github.v3+json',
          },
        )) {
    if (settings.githubToken.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'token ${settings.githubToken}';
    }
  }

  String get _repoPath => '/repos/${settings.repositoryOwner}/${settings.repositoryName}';

  /// Fetch the trips-data.js file content
  Future<GitHubFileResult> fetchTripsData() async {
    try {
      final response = await _dio.get(
        '$_repoPath/contents/${settings.tripsDataPath}',
        queryParameters: {'ref': settings.branch},
      );

      final content = utf8.decode(base64.decode(
        response.data['content'].toString().replaceAll('\n', ''),
      ));
      
      return GitHubFileResult(
        content: content,
        sha: response.data['sha'],
        success: true,
      );
    } on DioException catch (e) {
      return GitHubFileResult(
        content: '',
        sha: '',
        success: false,
        error: e.response?.data?['message'] ?? e.message,
      );
    }
  }

  /// Update the trips-data.js file
  Future<GitHubCommitResult> updateTripsData({
    required String content,
    required String sha,
    required String commitMessage,
  }) async {
    try {
      final response = await _dio.put(
        '$_repoPath/contents/${settings.tripsDataPath}',
        data: {
          'message': commitMessage,
          'content': base64.encode(utf8.encode(content)),
          'sha': sha,
          'branch': settings.branch,
        },
      );

      return GitHubCommitResult(
        success: true,
        commitSha: response.data['commit']['sha'],
        message: 'Changes committed successfully',
      );
    } on DioException catch (e) {
      return GitHubCommitResult(
        success: false,
        error: e.response?.data?['message'] ?? e.message,
      );
    }
  }

  /// Upload an image to the repository
  Future<GitHubUploadResult> uploadImage({
    required String filePath,
    required List<int> imageBytes,
    String? commitMessage,
  }) async {
    try {
      // Check if file exists first
      String? existingSha;
      try {
        final existingFile = await _dio.get(
          '$_repoPath/contents/$filePath',
          queryParameters: {'ref': settings.branch},
        );
        existingSha = existingFile.data['sha'];
      } catch (_) {
        // File doesn't exist, that's fine
      }

      final data = <String, dynamic>{
        'message': commitMessage ?? 'Add image: $filePath',
        'content': base64.encode(imageBytes),
        'branch': settings.branch,
      };

      if (existingSha != null) {
        data['sha'] = existingSha;
      }

      final response = await _dio.put(
        '$_repoPath/contents/$filePath',
        data: data,
      );

      final downloadUrl = response.data['content']['download_url'];
      
      return GitHubUploadResult(
        success: true,
        url: downloadUrl,
        path: filePath,
      );
    } on DioException catch (e) {
      return GitHubUploadResult(
        success: false,
        error: e.response?.data?['message'] ?? e.message,
      );
    }
  }

  /// Delete an image from the repository
  Future<bool> deleteImage({
    required String filePath,
    String? commitMessage,
  }) async {
    try {
      // Get the file SHA first
      final fileResponse = await _dio.get(
        '$_repoPath/contents/$filePath',
        queryParameters: {'ref': settings.branch},
      );
      
      final sha = fileResponse.data['sha'];

      await _dio.delete(
        '$_repoPath/contents/$filePath',
        data: {
          'message': commitMessage ?? 'Delete image: $filePath',
          'sha': sha,
          'branch': settings.branch,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  /// List images in the images/trips directory
  Future<List<String>> listTripImages() async {
    try {
      final response = await _dio.get(
        '$_repoPath/contents/images/trips',
        queryParameters: {'ref': settings.branch},
      );

      final List<dynamic> files = response.data;
      return files
          .where((f) => f['type'] == 'file')
          .map<String>((f) => f['name'] as String)
          .where((name) => 
              name.endsWith('.jpg') || 
              name.endsWith('.jpeg') || 
              name.endsWith('.png') ||
              name.endsWith('.webp'))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Verify GitHub token is valid
  Future<bool> verifyToken() async {
    try {
      await _dio.get('/user');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get repository info
  Future<Map<String, dynamic>?> getRepositoryInfo() async {
    try {
      final response = await _dio.get(_repoPath);
      return response.data;
    } catch (_) {
      return null;
    }
  }
}

class GitHubFileResult {
  final String content;
  final String sha;
  final bool success;
  final String? error;

  GitHubFileResult({
    required this.content,
    required this.sha,
    required this.success,
    this.error,
  });
}

class GitHubCommitResult {
  final bool success;
  final String? commitSha;
  final String? message;
  final String? error;

  GitHubCommitResult({
    required this.success,
    this.commitSha,
    this.message,
    this.error,
  });
}

class GitHubUploadResult {
  final bool success;
  final String? url;
  final String? path;
  final String? error;

  GitHubUploadResult({
    required this.success,
    this.url,
    this.path,
    this.error,
  });
}
