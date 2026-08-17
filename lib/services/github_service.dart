import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/app_settings.dart';

class GitHubService {
  final Dio _dio;
  final AppSettings settings;

  GitHubService({required this.settings, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.github.com',
              headers: {'Accept': 'application/vnd.github.v3+json'},
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
            ),
          ) {
    if (_dio.options.baseUrl.isEmpty) {
      _dio.options.baseUrl = 'https://api.github.com';
    }
    _dio.options.headers.putIfAbsent(
      'Accept',
      () => 'application/vnd.github.v3+json',
    );
    if (settings.githubToken.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'token ${settings.githubToken}';
    }
  }

  String get _repoPath =>
      '/repos/${settings.repositoryOwner}/${settings.repositoryName}';

  /// Fetch the trips-data.js file content
  Future<GitHubFileResult> fetchTripsData() async {
    try {
      final response = await _dio.get(
        '$_repoPath/contents/${settings.tripsDataPath}',
        queryParameters: {'ref': settings.branch},
      );

      final content = utf8.decode(
        base64.decode(response.data['content'].toString().replaceAll('\n', '')),
      );

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
  Future<ConflictCheckResult> checkForConflicts(
    String filePath,
    String localSha,
  ) async {
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
        final conflictCheck = await checkForConflicts(
          settings.tripsDataPath,
          sha,
        );

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
          error:
              'Conflict: Remote file has changed. Please refresh and try again.',
          hasConflict: true,
        );
      }
      // Check for 422 Unprocessable Entity (SHA mismatch)
      if (e.response?.statusCode == 422) {
        return GitHubCommitResult(
          success: false,
          error:
              'SHA mismatch: The file has been modified. Please refresh and re-apply your changes.',
          hasConflict: true,
        );
      }
      return GitHubCommitResult(success: false, error: _getErrorMessage(e));
    }
  }

  /// Fetch any file from the repository by path
  Future<GitHubFileResult> fetchFile(String filePath) async {
    try {
      final response = await _dio.get(
        '$_repoPath/contents/$filePath',
        queryParameters: {'ref': settings.branch},
      );

      final content = utf8.decode(
        base64.decode(response.data['content'].toString().replaceAll('\n', '')),
      );

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

  /// Update any file in the repository by path (no conflict check — caller handles it)
  Future<GitHubCommitResult> updateFile({
    required String filePath,
    required String content,
    required String sha,
    required String commitMessage,
  }) async {
    try {
      final response = await _dio.put(
        '$_repoPath/contents/$filePath',
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
        message: 'File updated successfully',
      );
    } on DioException catch (e) {
      return GitHubCommitResult(success: false, error: _getErrorMessage(e));
    }
  }

  /// Atomically commit several text files using GitHub's Git Database API.
  ///
  /// Every managed path must have an entry in [expectedBlobShas]. Use `null`
  /// when the caller expects a new file. The method reads one branch head,
  /// verifies all expected blobs against that tree, creates one commit with all
  /// replacements, and advances the branch without force. A changed blob or a
  /// branch race is returned as a conflict; history is never rewritten.
  Future<GitHubCommitResult> commitFilesAtomically({
    required Map<String, String> files,
    required Map<String, String?> expectedBlobShas,
    required String commitMessage,
  }) async {
    final validationError = _validateAtomicCommitInput(
      files,
      expectedBlobShas,
      commitMessage,
    );
    if (validationError != null) {
      return GitHubCommitResult(success: false, error: validationError);
    }

    final encodedBranch = Uri.encodeComponent(settings.branch);
    try {
      final refResponse = await _dio.get(
        '$_repoPath/git/ref/heads/$encodedBranch',
      );
      final baseCommitSha = _requiredString(
        refResponse.data?['object']?['sha'],
        'branch head SHA',
      );

      final commitResponse = await _dio.get(
        '$_repoPath/git/commits/$baseCommitSha',
      );
      final baseTreeSha = _requiredString(
        commitResponse.data?['tree']?['sha'],
        'base tree SHA',
      );

      final treeResponse = await _dio.get(
        '$_repoPath/git/trees/$baseTreeSha',
        queryParameters: {'recursive': '1'},
      );
      if (treeResponse.data?['truncated'] == true) {
        return GitHubCommitResult(
          success: false,
          error:
              'Repository tree is too large to validate safely. No commit was created.',
        );
      }

      final treeEntries = treeResponse.data?['tree'];
      if (treeEntries is! List) {
        throw const FormatException(
          'GitHub returned an invalid repository tree.',
        );
      }
      final currentEntries = <String, Map<String, dynamic>>{};
      for (final rawEntry in treeEntries) {
        if (rawEntry is Map && rawEntry['path'] is String) {
          currentEntries[rawEntry['path'] as String] =
              Map<String, dynamic>.from(rawEntry);
        }
      }

      final conflicts = <String>[];
      for (final path in files.keys) {
        final currentEntry = currentEntries[path];
        final currentSha = currentEntry?['sha']?.toString();
        final expectedSha = expectedBlobShas[path];
        if (currentEntry != null && currentEntry['type'] != 'blob') {
          conflicts.add('$path (remote path is not a file)');
        } else if (currentSha != expectedSha) {
          conflicts.add(
            '$path (expected ${expectedSha ?? 'new file'}, found ${currentSha ?? 'missing'})',
          );
        }
      }
      if (conflicts.isNotEmpty) {
        return GitHubCommitResult(
          success: false,
          hasConflict: true,
          baseCommitSha: baseCommitSha,
          error:
              'Remote files changed before publishing: ${conflicts.join(', ')}.',
        );
      }

      final createdBlobShas = <String, String>{};
      for (final entry in files.entries) {
        final blobResponse = await _dio.post(
          '$_repoPath/git/blobs',
          data: {
            'content': base64.encode(utf8.encode(entry.value)),
            'encoding': 'base64',
          },
        );
        createdBlobShas[entry.key] = _requiredString(
          blobResponse.data?['sha'],
          'blob SHA for ${entry.key}',
        );
      }

      final newTreeResponse = await _dio.post(
        '$_repoPath/git/trees',
        data: {
          'base_tree': baseTreeSha,
          'tree': [
            for (final entry in createdBlobShas.entries)
              {
                'path': entry.key,
                'mode':
                    currentEntries[entry.key]?['mode']?.toString() ?? '100644',
                'type': 'blob',
                'sha': entry.value,
              },
          ],
        },
      );
      final newTreeSha = _requiredString(
        newTreeResponse.data?['sha'],
        'new tree SHA',
      );

      final newCommitResponse = await _dio.post(
        '$_repoPath/git/commits',
        data: {
          'message': commitMessage,
          'tree': newTreeSha,
          'parents': [baseCommitSha],
        },
      );
      final newCommitSha = _requiredString(
        newCommitResponse.data?['sha'],
        'new commit SHA',
      );

      await _dio.patch(
        '$_repoPath/git/refs/heads/$encodedBranch',
        data: {'sha': newCommitSha, 'force': false},
      );

      return GitHubCommitResult(
        success: true,
        commitSha: newCommitSha,
        baseCommitSha: baseCommitSha,
        fileBlobShas: createdBlobShas,
        message: '${files.length} files committed atomically',
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final failedWhileAdvancingRef = e.requestOptions.path.contains(
        '/git/refs/',
      );
      if (failedWhileAdvancingRef && (status == 409 || status == 422)) {
        return GitHubCommitResult(
          success: false,
          hasConflict: true,
          error:
              'The branch changed while publishing. Refresh and merge before retrying.',
        );
      }
      return GitHubCommitResult(success: false, error: _getErrorMessage(e));
    } on FormatException catch (e) {
      return GitHubCommitResult(success: false, error: e.message);
    } catch (e) {
      return GitHubCommitResult(
        success: false,
        error: 'Atomic commit failed: $e',
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
        message: existingSha != null
            ? 'Image updated successfully'
            : 'Image uploaded successfully',
      );
    } on DioException catch (e) {
      // Check for conflict errors
      if (e.response?.statusCode == 409 || e.response?.statusCode == 422) {
        return GitHubUploadResult(
          success: false,
          error:
              'Image upload conflict. The file may have been modified. Please try again.',
          hasConflict: true,
        );
      }
      return GitHubUploadResult(success: false, error: _getErrorMessage(e));
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

      return GitHubDeleteResult(
        success: true,
        message: 'Image deleted successfully',
      );
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
          .where(
            (name) =>
                name.endsWith('.jpg') ||
                name.endsWith('.jpeg') ||
                name.endsWith('.png') ||
                name.endsWith('.webp'),
          )
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
        final canPush =
            permissions['push'] == true || permissions['admin'] == true;

        return TokenValidationResult(
          isValid: true,
          hasRepoAccess: true,
          canPush: canPush,
          username: username,
          message: canPush
              ? 'Token valid with write access'
              : 'Token valid but read-only access',
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

  /// Get GitHub Pages site info (URL, custom domain, HTTPS)
  Future<DeploymentStatusResult> getDeploymentStatus() async {
    try {
      final response = await _dio.get('$_repoPath/pages');

      return DeploymentStatusResult(
        success: true,
        siteUrl: response.data['html_url'],
        status: response.data['status'],
        cname: response.data['cname'],
        isHttpsEnforced: response.data['https_enforced'] == true,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return DeploymentStatusResult(
          success: false,
          error: 'GitHub Pages is not enabled for this repository.',
        );
      }
      return DeploymentStatusResult(success: false, error: _getErrorMessage(e));
    }
  }

  /// Get recent GitHub Actions workflow runs (deployment history)
  Future<List<WorkflowRunResult>> getRecentDeployments({int limit = 10}) async {
    try {
      final response = await _dio.get(
        '$_repoPath/actions/runs',
        queryParameters: {'per_page': limit, 'branch': settings.branch},
      );
      return _parseWorkflowRuns(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return [];
      }
      return [];
    }
  }

  /// Get workflow runs created for one exact saved commit.
  ///
  /// Unlike [getRecentDeployments], failures are retained in the result so a
  /// monitoring screen can distinguish missing Actions permission from an API
  /// or network error. This method is read-only.
  Future<WorkflowRunsQueryResult> getWorkflowRunsForCommit(
    String headSha, {
    int limit = 10,
  }) async {
    final normalizedSha = headSha.trim();
    if (normalizedSha.isEmpty) {
      return const WorkflowRunsQueryResult(
        success: false,
        error: 'A commit SHA is required to monitor a deployment.',
      );
    }

    try {
      final response = await _dio.get(
        '$_repoPath/actions/runs',
        queryParameters: {'head_sha': normalizedSha, 'per_page': limit},
      );
      return WorkflowRunsQueryResult(
        success: true,
        runs: _parseWorkflowRuns(response.data),
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      return WorkflowRunsQueryResult(
        success: false,
        permissionDenied: statusCode == 403,
        statusCode: statusCode,
        error: statusCode == 403
            ? 'GitHub denied access to workflow runs. Grant Actions read permission to the token.'
            : _getErrorMessage(e),
      );
    } catch (e) {
      return WorkflowRunsQueryResult(
        success: false,
        error: 'Invalid workflow response: $e',
      );
    }
  }

  List<WorkflowRunResult> _parseWorkflowRuns(dynamic responseData) {
    if (responseData is! Map) return const <WorkflowRunResult>[];
    final rawRuns = responseData['workflow_runs'];
    if (rawRuns is! List) return const <WorkflowRunResult>[];

    return rawRuns.whereType<Map>().map((run) {
      int? durationSecs;
      if (run['created_at'] != null && run['updated_at'] != null) {
        try {
          final start = DateTime.parse(run['created_at'].toString());
          final end = DateTime.parse(run['updated_at'].toString());
          durationSecs = end.difference(start).inSeconds;
        } catch (_) {}
      }

      final actor = run['actor'];
      return WorkflowRunResult(
        success: true,
        id: run['id'] is int ? run['id'] as int : int.tryParse('${run['id']}'),
        name: run['name']?.toString(),
        status: run['status']?.toString(),
        conclusion: run['conclusion']?.toString(),
        commitSha: run['head_sha']?.toString(),
        commitMessage: run['display_title']?.toString(),
        branch: run['head_branch']?.toString(),
        event: run['event']?.toString(),
        createdAt: run['created_at']?.toString(),
        updatedAt: run['updated_at']?.toString(),
        htmlUrl: run['html_url']?.toString(),
        runNumber: run['run_number'] is int
            ? run['run_number'] as int
            : int.tryParse('${run['run_number']}'),
        durationSecs: durationSecs,
        actorLogin: actor is Map ? actor['login']?.toString() : null,
        actorAvatar: actor is Map ? actor['avatar_url']?.toString() : null,
      );
    }).toList();
  }

  /// Get latest commits for reference
  Future<List<Map<String, dynamic>>> getRecentCommits({int limit = 5}) async {
    try {
      final response = await _dio.get(
        '$_repoPath/commits',
        queryParameters: {'sha': settings.branch, 'per_page': limit},
      );
      return List<Map<String, dynamic>>.from(response.data);
    } catch (_) {
      return [];
    }
  }

  String? _validateAtomicCommitInput(
    Map<String, String> files,
    Map<String, String?> expectedBlobShas,
    String commitMessage,
  ) {
    if (files.isEmpty) return 'At least one file is required.';
    if (commitMessage.trim().isEmpty) return 'Commit message cannot be empty.';

    final filePaths = files.keys.toSet();
    final expectedPaths = expectedBlobShas.keys.toSet();
    if (filePaths.length != expectedPaths.length ||
        filePaths.difference(expectedPaths).isNotEmpty ||
        expectedPaths.difference(filePaths).isNotEmpty) {
      return 'Expected blob SHAs must be supplied for every file and no others.';
    }

    for (final path in filePaths) {
      final segments = path.split('/');
      if (path.isEmpty ||
          path.startsWith('/') ||
          path.contains('\\') ||
          segments.any(
            (segment) => segment.isEmpty || segment == '.' || segment == '..',
          )) {
        return 'Unsafe repository path: "$path".';
      }
      final expectedSha = expectedBlobShas[path];
      if (expectedSha != null && expectedSha.trim().isEmpty) {
        return 'Expected blob SHA for "$path" cannot be empty.';
      }
    }
    return null;
  }

  String _requiredString(dynamic value, String label) {
    if (value is String && value.isNotEmpty) return value;
    throw FormatException('GitHub response is missing $label.');
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
  final String? baseCommitSha;
  final Map<String, String> fileBlobShas;
  final String? message;
  final String? error;
  final bool hasConflict;

  GitHubCommitResult({
    required this.success,
    this.commitSha,
    this.baseCommitSha,
    this.fileBlobShas = const {},
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

  GitHubDeleteResult({required this.success, this.message, this.error});
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

class DeploymentStatusResult {
  final bool success;
  final String? siteUrl;
  final String? status;
  final String? cname;
  final bool isHttpsEnforced;
  final String? error;

  DeploymentStatusResult({
    required this.success,
    this.siteUrl,
    this.status,
    this.cname,
    this.isHttpsEnforced = false,
    this.error,
  });
}

/// A workflow query that retains HTTP failure details for deployment monitors.
class WorkflowRunsQueryResult {
  final bool success;
  final List<WorkflowRunResult> runs;
  final bool permissionDenied;
  final int? statusCode;
  final String? error;

  const WorkflowRunsQueryResult({
    required this.success,
    this.runs = const <WorkflowRunResult>[],
    this.permissionDenied = false,
    this.statusCode,
    this.error,
  });
}

class WorkflowRunResult {
  final bool success;
  final int? id;
  final String? name; // e.g. 'Validate and Deploy'
  final String? status; // 'queued', 'in_progress', 'completed'
  final String? conclusion; // 'success', 'failure', 'cancelled', null
  final String? commitSha;
  final String? commitMessage;
  final String? branch;
  final String? event; // 'push', 'workflow_dispatch', etc.
  final String? createdAt;
  final String? updatedAt;
  final String? htmlUrl;
  final int? runNumber;
  final int? durationSecs;
  final String? actorLogin;
  final String? actorAvatar;
  final String? error;

  WorkflowRunResult({
    required this.success,
    this.id,
    this.name,
    this.status,
    this.conclusion,
    this.commitSha,
    this.commitMessage,
    this.branch,
    this.event,
    this.createdAt,
    this.updatedAt,
    this.htmlUrl,
    this.runNumber,
    this.durationSecs,
    this.actorLogin,
    this.actorAvatar,
    this.error,
  });

  /// Still running or queued
  bool get isInProgress => status == 'in_progress' || status == 'queued';

  /// Completed successfully
  bool get isSuccess => status == 'completed' && conclusion == 'success';

  /// Completed with failure
  bool get isFailure => status == 'completed' && conclusion == 'failure';

  /// Completed but cancelled
  bool get isCancelled => status == 'completed' && conclusion == 'cancelled';
}
