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
  }) async {
    try {
      // Generate filename
      final extension = imageFile.path.split('.').last.toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = customFileName ?? 'img_$timestamp.$extension';
      final remotePath = 'images/gallery/$tripId/$fileName';

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
        'message': 'Add gallery image for $tripId via Trip Manager App',
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
