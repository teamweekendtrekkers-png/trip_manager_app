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
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
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
        error: _getErrorMessage(e),
      );
    }
  }

  /// Get the latest SHA for a file (to check for conflicts)
  Future<String?> getLatestSha(String filePath) async {
    try {
      final response = await _dio.get(
        '$_repoPath/contents/$filePath',
        queryParameters: {'ref': settings.branch},
      );
      return response.data['sha'];
    } catch (_) {
      return null;
    }
  }

  /// Check if there are remote changes (conflict detection)
  Future<ConflictCheckResult> checkForConflicts(String filePath, String localSha) async {
    try {
      final latestSha = await getLatestSha(filePath);
      
      if (latestSha == null) {
        return ConflictCheckResult(
          hasConflict: false,
          canProceed: true,
          message: 'File not found on remote, will create new',
        );
      }
      
      if (latestSha == localSha) {
        return ConflictCheckResult(
          hasConflict: false,
          canProceed: true,
          latestSha: latestSha,
          message: 'No conflicts detected',
        );
      }
      
      return ConflictCheckResult(
        hasConflict: true,
        canProceed: false,
        latestSha: latestSha,
        message: 'Remote file has been modified. Please refresh and try again.',
      );
    } catch (e) {
      return ConflictCheckResult(
        hasConflict: false,
        canProceed: false,
        message: 'Failed to check for conflicts: $e',
      );
    }
  }

  /// Update the trips-data.js file with conflict checking
  Future<GitHubCommitResult> updateTripsData({
    required String content,
    required String sha,
    required String commitMessage,
    bool forceUpdate = false,
  }) async {
    try {
      // Step 1: Check for conflicts unless force update
      if (!forceUpdate) {
        final conflictCheck = await checkForConflicts(settings.tripsDataPath, sha);
        
        if (conflictCheck.hasConflict) {
          return GitHubCommitResult(
            success: false,
            error: conflictCheck.message,
            hasConflict: true,
          );
        }
        
        if (!conflictCheck.canProceed) {
          return GitHubCommitResult(
            success: false,
            error: conflictCheck.message,
          );
        }
      }

      // Step 2: Push the changes
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
      // Check for 409 Conflict error
      if (e.response?.statusCode == 409) {
        return GitHubCommitResult(
          success: false,
          error: 'Conflict: Remote file has changed. Please refresh and try again.',
          hasConflict: true,
        );
      }
      // Check for 422 Unprocessable Entity (SHA mismatch)
      if (e.response?.statusCode == 422) {
        return GitHubCommitResult(
          success: false,
          error: 'SHA mismatch: The file has been modified. Please refresh and re-apply your changes.',
          hasConflict: true,
        );
      }
      return GitHubCommitResult(
        success: false,
        error: _getErrorMessage(e),
      );
    }
  }

  /// Upload an image to the repository with conflict handling
  Future<GitHubUploadResult> uploadImage({
    required String filePath,
    required List<int> imageBytes,
    String? commitMessage,
  }) async {
    try {
      // Step 1: Check if file exists and get SHA
      String? existingSha;
      try {
        final existingFile = await _dio.get(
          '$_repoPath/contents/$filePath',
          queryParameters: {'ref': settings.branch},
        );
        existingSha = existingFile.data['sha'];
      } catch (_) {
        // File doesn't exist, that's fine - we'll create it
      }

      // Step 2: Prepare the request data
      final data = <String, dynamic>{
        'message': commitMessage ?? 'Upload image: $filePath via mobile app',
        'content': base64.encode(imageBytes),
        'branch': settings.branch,
      };

      // Include SHA if updating existing file
      if (existingSha != null) {
        data['sha'] = existingSha;
      }

      // Step 3: Upload the file
      final response = await _dio.put(
        '$_repoPath/contents/$filePath',
        data: data,
      );

      final downloadUrl = response.data['content']['download_url'];
      
      return GitHubUploadResult(
        success: true,
        url: downloadUrl,
        path: filePath,
        message: existingSha != null ? 'Image updated successfully' : 'Image uploaded successfully',
      );
    } on DioException catch (e) {
      // Check for conflict errors
      if (e.response?.statusCode == 409 || e.response?.statusCode == 422) {
        return GitHubUploadResult(
          success: false,
          error: 'Image upload conflict. The file may have been modified. Please try again.',
          hasConflict: true,
        );
      }
      return GitHubUploadResult(
        success: false,
        error: _getErrorMessage(e),
      );
    }
  }

  /// Delete an image from the repository
  Future<GitHubDeleteResult> deleteImage({
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
          'message': commitMessage ?? 'Delete image: $filePath via mobile app',
          'sha': sha,
          'branch': settings.branch,
        },
      );

      return GitHubDeleteResult(success: true, message: 'Image deleted successfully');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return GitHubDeleteResult(success: false, error: 'File not found');
      }
      return GitHubDeleteResult(success: false, error: _getErrorMessage(e));
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

  /// Verify GitHub token is valid and has required permissions
  Future<TokenValidationResult> verifyToken() async {
    try {
      // Check user authentication
      final userResponse = await _dio.get('/user');
      final username = userResponse.data['login'];
      
      // Check repository access
      try {
        await _dio.get(_repoPath);
      } catch (e) {
        return TokenValidationResult(
          isValid: true,
          hasRepoAccess: false,
          username: username,
          message: 'Token valid but no access to repository',
        );
      }
      
      // Check write access by checking permissions
      try {
        final repoResponse = await _dio.get(_repoPath);
        final permissions = repoResponse.data['permissions'] ?? {};
        final canPush = permissions['push'] == true || permissions['admin'] == true;
        
        return TokenValidationResult(
          isValid: true,
          hasRepoAccess: true,
          canPush: canPush,
          username: username,
          message: canPush ? 'Token valid with write access' : 'Token valid but read-only access',
        );
      } catch (_) {
        return TokenValidationResult(
          isValid: true,
          hasRepoAccess: true,
          username: username,
          message: 'Token valid with repository access',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return TokenValidationResult(
          isValid: false,
          message: 'Invalid or expired token',
        );
      }
      return TokenValidationResult(
        isValid: false,
        message: _getErrorMessage(e),
      );
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

  /// Get latest commits for reference
  Future<List<Map<String, dynamic>>> getRecentCommits({int limit = 5}) async {
    try {
      final response = await _dio.get(
        '$_repoPath/commits',
        queryParameters: {
          'sha': settings.branch,
          'per_page': limit,
        },
      );
      return List<Map<String, dynamic>>.from(response.data);
    } catch (_) {
      return [];
    }
  }

  /// Helper to extract error messages
  String _getErrorMessage(DioException e) {
    if (e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    }
    if (e.type == DioExceptionType.connectionTimeout) {
      return 'Connection timeout. Please check your internet connection.';
    }
    if (e.type == DioExceptionType.receiveTimeout) {
      return 'Server took too long to respond. Please try again.';
    }
    return e.message ?? 'Unknown error occurred';
  }
}

// Result classes

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
  final bool hasConflict;

  GitHubCommitResult({
    required this.success,
    this.commitSha,
    this.message,
    this.error,
    this.hasConflict = false,
  });
}

class GitHubUploadResult {
  final bool success;
  final String? url;
  final String? path;
  final String? message;
  final String? error;
  final bool hasConflict;

  GitHubUploadResult({
    required this.success,
    this.url,
    this.path,
    this.message,
    this.error,
    this.hasConflict = false,
  });
}

class GitHubDeleteResult {
  final bool success;
  final String? message;
  final String? error;

  GitHubDeleteResult({
    required this.success,
    this.message,
    this.error,
  });
}

class ConflictCheckResult {
  final bool hasConflict;
  final bool canProceed;
  final String? latestSha;
  final String? message;

  ConflictCheckResult({
    required this.hasConflict,
    required this.canProceed,
    this.latestSha,
    this.message,
  });
}

class TokenValidationResult {
  final bool isValid;
  final bool hasRepoAccess;
  final bool canPush;
  final String? username;
  final String? message;

  TokenValidationResult({
    required this.isValid,
    this.hasRepoAccess = false,
    this.canPush = false,
    this.username,
    this.message,
  });
}
