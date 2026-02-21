import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../models/app_settings.dart';

/// Service to upload images to GitHub repository
class ImageUploadService {
  final Dio _dio;
  final AppSettings settings;

  ImageUploadService({required this.settings})
      : _dio = Dio(BaseOptions(
          baseUrl: 'https://api.github.com',
          headers: {
            'Accept': 'application/vnd.github.v3+json',
          },
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        )) {
    if (settings.githubToken.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'token ${settings.githubToken}';
    }
  }

  String get _repoPath =>
      '/repos/${settings.repositoryOwner}/${settings.repositoryName}';

  /// Upload a single image to the repository
  /// Returns the path where the image was uploaded (e.g., 'images/gallery/trip_123/image1.jpg')
  Future<ImageUploadResult> uploadImage({
    required File imageFile,
    required String tripId,
    String? customFileName,
    bool isMainImage = false,
  }) async {
    try {
      // Generate filename
      final extension = imageFile.path.split('.').last.toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = customFileName ?? 'img_$timestamp.$extension';
      
      // Use different path for main images vs gallery images
      final String remotePath;
      final String commitMessage;
      if (isMainImage) {
        remotePath = 'images/trips/${tripId}_$timestamp.$extension';
        commitMessage = 'Update display image for $tripId via Trip Manager App';
      } else {
        remotePath = 'images/gallery/$tripId/$fileName';
        commitMessage = 'Add gallery image for $tripId via Trip Manager App';
      }

      // Read file and encode to base64
      final bytes = await imageFile.readAsBytes();
      final base64Content = base64.encode(bytes);

      // Check if file exists (to get SHA for update)
      String? existingSha;
      try {
        final existingResponse = await _dio.get(
          '$_repoPath/contents/$remotePath',
          queryParameters: {'ref': settings.branch},
        );
        existingSha = existingResponse.data['sha'];
      } on DioException catch (e) {
        // 404 is expected if file doesn't exist
        if (e.response?.statusCode != 404) {
          rethrow;
        }
      }

      // Upload file
      final data = <String, dynamic>{
        'message': commitMessage,
        'content': base64Content,
        'branch': settings.branch,
      };
      if (existingSha != null) {
        data['sha'] = existingSha;
      }

      await _dio.put(
        '$_repoPath/contents/$remotePath',
        data: data,
      );

      // If this is a main/display image, also update the image path in trips-data.js
      if (isMainImage) {
        await _updateTripsDataImage(tripId: tripId, newImagePath: remotePath);
      }

      return ImageUploadResult(
        success: true,
        imagePath: remotePath,
        message: 'Image uploaded successfully',
      );
    } on DioException catch (e) {
      return ImageUploadResult(
        success: false,
        error: _getErrorMessage(e),
      );
    } catch (e) {
      return ImageUploadResult(
        success: false,
        error: 'Failed to upload image: $e',
      );
    }
  }

  /// Upload multiple images for a trip
  Future<List<ImageUploadResult>> uploadMultipleImages({
    required List<File> imageFiles,
    required String tripId,
    Function(int completed, int total)? onProgress,
  }) async {
    final results = <ImageUploadResult>[];

    for (int i = 0; i < imageFiles.length; i++) {
      final result = await uploadImage(
        imageFile: imageFiles[i],
        tripId: tripId,
      );
      results.add(result);

      if (onProgress != null) {
        onProgress(i + 1, imageFiles.length);
      }
    }

    return results;
  }

  /// Delete an image from the repository
  Future<ImageUploadResult> deleteImage({
    required String imagePath,
  }) async {
    try {
      // Get the SHA of the file
      final response = await _dio.get(
        '$_repoPath/contents/$imagePath',
        queryParameters: {'ref': settings.branch},
      );
      final sha = response.data['sha'];

      // Delete the file
      await _dio.delete(
        '$_repoPath/contents/$imagePath',
        data: {
          'message': 'Delete gallery image via Trip Manager App',
          'sha': sha,
          'branch': settings.branch,
        },
      );

      return ImageUploadResult(
        success: true,
        message: 'Image deleted successfully',
      );
    } on DioException catch (e) {
      return ImageUploadResult(
        success: false,
        error: _getErrorMessage(e),
      );
    } catch (e) {
      return ImageUploadResult(
        success: false,
        error: 'Failed to delete image: $e',
      );
    }
  }

  /// Update the image path in js/trips-data.js for a given trip
  /// This ensures the website displays the correct image after upload
  Future<void> _updateTripsDataImage({
    required String tripId,
    required String newImagePath,
  }) async {
    const tripsDataPath = 'js/trips-data.js';

    try {
      // Fetch the current file content and SHA
      final response = await _dio.get(
        '$_repoPath/contents/$tripsDataPath',
        queryParameters: {'ref': settings.branch},
      );
      final currentSha = response.data['sha'] as String;
      final currentContent = utf8.decode(
        base64.decode(
          (response.data['content'] as String).replaceAll('\n', ''),
        ),
      );

      // Find and replace the image path for this trip
      // Pattern: find the trip's key block and update its image field
      final updatedContent = _replaceImageInTripsData(
        content: currentContent,
        tripId: tripId,
        newImagePath: newImagePath,
      );

      if (updatedContent == null || updatedContent == currentContent) {
        // No change needed or trip not found — skip silently
        return;
      }

      // Commit the updated file
      await _dio.put(
        '$_repoPath/contents/$tripsDataPath',
        data: {
          'message': 'Update display image path for $tripId in trips-data.js via Trip Manager App',
          'content': base64.encode(utf8.encode(updatedContent)),
          'sha': currentSha,
          'branch': settings.branch,
        },
      );
    } catch (e) {
      // Log but don't fail the image upload if JS update fails
      // The image was uploaded successfully, this is a secondary operation
      print('Warning: Failed to update trips-data.js for $tripId: $e');
    }
  }

  /// Replace the image path for a specific trip in the trips-data.js content
  /// Handles both quoted keys ("trip-id": {) and unquoted keys (tripId: {)
  String? _replaceImageInTripsData({
    required String content,
    required String tripId,
    required String newImagePath,
  }) {
    // Try quoted key first (for hyphenated IDs like "alleppey-varkala": {)
    RegExpMatch? tripMatch = RegExp('"${RegExp.escape(tripId)}"\\s*:\\s*\\{').firstMatch(content);
    
    // Try unquoted key (for simple IDs like kerala: {)
    tripMatch ??= RegExp('(?<!["\'])${RegExp.escape(tripId)}\\s*:\\s*\\{').firstMatch(content);
    
    if (tripMatch == null) return null;

    // From the trip block start, find the image field
    final afterTripKey = content.substring(tripMatch.start);
    final imagePattern = RegExp(r'image:\s*"[^"]*"');
    final imageMatch = imagePattern.firstMatch(afterTripKey);
    if (imageMatch == null) return null;

    // Calculate absolute position and replace
    final absoluteStart = tripMatch.start + imageMatch.start;
    final absoluteEnd = tripMatch.start + imageMatch.end;

    return content.substring(0, absoluteStart) +
        'image: "$newImagePath"' +
        content.substring(absoluteEnd);
  }

  /// Get full URL for an image path
  String getImageUrl(String imagePath) {
    if (imagePath.startsWith('http')) {
      return imagePath;
    }
    return 'https://raw.githubusercontent.com/${settings.repositoryOwner}/${settings.repositoryName}/${settings.branch}/$imagePath';
  }

  String _getErrorMessage(DioException e) {
    if (e.response?.statusCode == 401) {
      return 'Authentication failed. Please check your GitHub token.';
    }
    if (e.response?.statusCode == 403) {
      return 'Permission denied. Please check repository permissions.';
    }
    if (e.response?.statusCode == 404) {
      return 'Repository or file not found.';
    }
    if (e.response?.statusCode == 422) {
      return 'File already exists or invalid path.';
    }
    if (e.type == DioExceptionType.connectionTimeout) {
      return 'Connection timeout. Please check your internet connection.';
    }
    if (e.type == DioExceptionType.receiveTimeout) {
      return 'Request timeout. The file might be too large.';
    }
    return e.message ?? 'Unknown error occurred';
  }
}

/// Result of an image upload operation
class ImageUploadResult {
  final bool success;
  final String? imagePath;
  final String? message;
  final String? error;

  ImageUploadResult({
    required this.success,
    this.imagePath,
    this.message,
    this.error,
  });
}
