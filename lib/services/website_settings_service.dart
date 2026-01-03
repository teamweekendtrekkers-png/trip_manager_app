import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/app_settings.dart';

/// Service to update website-wide settings like UPI ID and WhatsApp number
class WebsiteSettingsService {
  final Dio _dio;
  final AppSettings settings;

  WebsiteSettingsService({required this.settings})
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

  /// Update UPI ID in security.js
  /// The UPI is encoded as ASCII codes with a checksum for security
  Future<UpdateResult> updateUpiId(String newUpiId) async {
    try {
      // Validate UPI format
      if (!_isValidUpi(newUpiId)) {
        return UpdateResult(
          success: false,
          error: 'Invalid UPI ID format. Expected: number@provider (e.g., 9538236581@ybl)',
        );
      }

      // Fetch current security.js
      final response = await _dio.get(
        '$_repoPath/contents/js/security.js',
        queryParameters: {'ref': settings.branch},
      );
      
      final currentContent = utf8.decode(base64.decode(
        response.data['content'].toString().replaceAll('\n', ''),
      ));
      final sha = response.data['sha'];

      // Generate new encoded UPI
      final parts = newUpiId.split('@');
      final number = parts[0]; // e.g., "9538236581"
      final provider = parts[1]; // e.g., "ybl"
      
      // Convert to ASCII arrays
      final p1Array = number.codeUnits; // [57, 53, 51, 56, 50, 51, 54, 53, 56, 49]
      final p2Code = '@'.codeUnitAt(0); // 64
      final p3Array = provider.codeUnits; // [121, 98, 108]
      
      // Compute checksum
      final checksum = _computeChecksum(newUpiId);
      
      // Update security.js content
      final updatedContent = _updateSecurityJs(
        currentContent, 
        p1Array, 
        p2Code, 
        p3Array, 
        checksum,
      );

      // Push to GitHub
      await _dio.put(
        '$_repoPath/contents/js/security.js',
        data: {
          'message': 'Update UPI ID via Trip Manager App',
          'content': base64.encode(utf8.encode(updatedContent)),
          'sha': sha,
          'branch': settings.branch,
        },
      );

      return UpdateResult(
        success: true,
        message: 'UPI ID updated successfully to $newUpiId',
      );
    } on DioException catch (e) {
      return UpdateResult(
        success: false,
        error: _getErrorMessage(e),
      );
    } catch (e) {
      return UpdateResult(
        success: false,
        error: 'Failed to update UPI: $e',
      );
    }
  }

  /// Update WhatsApp number across all HTML files
  Future<UpdateResult> updateWhatsAppNumber(String newNumber) async {
    try {
      // Validate number format (should be country code + number)
      if (!_isValidWhatsApp(newNumber)) {
        return UpdateResult(
          success: false,
          error: 'Invalid WhatsApp number format. Use format: 917019235581 (country code + number)',
        );
      }

      // Get current WhatsApp number from settings or detect from files
      final currentNumber = await _getCurrentWhatsAppNumber();
      if (currentNumber == null) {
        return UpdateResult(
          success: false,
          error: 'Could not detect current WhatsApp number in website files',
        );
      }

      if (currentNumber == newNumber) {
        return UpdateResult(
          success: true,
          message: 'WhatsApp number is already set to $newNumber',
        );
      }

      // Files to update
      final htmlFiles = ['index.html', 'trips.html', 'trip-detail.html', 'about.html', 'contact.html'];
      int updatedCount = 0;
      final errors = <String>[];

      for (final file in htmlFiles) {
        try {
          final result = await _updateWhatsAppInFile(file, currentNumber, newNumber);
          if (result) {
            updatedCount++;
          }
        } catch (e) {
          errors.add('$file: $e');
        }
      }

      if (updatedCount == 0) {
        return UpdateResult(
          success: false,
          error: 'Failed to update any files. Errors: ${errors.join(', ')}',
        );
      }

      return UpdateResult(
        success: true,
        message: 'WhatsApp updated in $updatedCount files (from $currentNumber to $newNumber)',
        details: errors.isEmpty ? null : 'Errors: ${errors.join(', ')}',
      );
    } catch (e) {
      return UpdateResult(
        success: false,
        error: 'Failed to update WhatsApp: $e',
      );
    }
  }

  /// Update both UPI and WhatsApp
  Future<UpdateResult> updateBothSettings(String newUpiId, String newWhatsApp) async {
    final results = <String>[];
    var hasError = false;

    // Update UPI
    final upiResult = await updateUpiId(newUpiId);
    if (upiResult.success) {
      results.add('✓ UPI: ${upiResult.message}');
    } else {
      results.add('✗ UPI: ${upiResult.error}');
      hasError = true;
    }

    // Update WhatsApp
    final waResult = await updateWhatsAppNumber(newWhatsApp);
    if (waResult.success) {
      results.add('✓ WhatsApp: ${waResult.message}');
    } else {
      results.add('✗ WhatsApp: ${waResult.error}');
      hasError = true;
    }

    return UpdateResult(
      success: !hasError,
      message: hasError ? 'Some updates failed' : 'All settings updated successfully',
      details: results.join('\n'),
    );
  }

  /// Get current settings from website files
  Future<WebsiteSettings> getCurrentWebsiteSettings() async {
    String? upiId;
    String? whatsAppNumber;

    try {
      // Get UPI from security.js
      final securityResponse = await _dio.get(
        '$_repoPath/contents/js/security.js',
        queryParameters: {'ref': settings.branch},
      );
      final securityContent = utf8.decode(base64.decode(
        securityResponse.data['content'].toString().replaceAll('\n', ''),
      ));
      upiId = _extractUpiFromSecurityJs(securityContent);
    } catch (_) {}

    try {
      // Get WhatsApp from index.html
      whatsAppNumber = await _getCurrentWhatsAppNumber();
    } catch (_) {}

    return WebsiteSettings(
      upiId: upiId,
      whatsAppNumber: whatsAppNumber,
    );
  }

  // ============== Private Helper Methods ==============

  bool _isValidUpi(String upi) {
    // Format: number@provider
    final regex = RegExp(r'^\d{10,12}@[a-z]{2,10}$', caseSensitive: false);
    return regex.hasMatch(upi);
  }

  bool _isValidWhatsApp(String number) {
    // Format: country code + number (e.g., 917019235581)
    final regex = RegExp(r'^\d{10,15}$');
    return regex.hasMatch(number);
  }

  /// Compute checksum matching the website's algorithm
  int _computeChecksum(String str) {
    int sum = 0;
    for (int i = 0; i < str.length; i++) {
      sum = ((sum << 5) - sum + str.codeUnitAt(i));
      // JavaScript's | 0 converts to 32-bit signed integer
      sum = sum.toSigned(32);
    }
    return sum;
  }

  /// Update security.js with new UPI encoding
  String _updateSecurityJs(
    String content, 
    List<int> p1Array, 
    int p2Code, 
    List<int> p3Array, 
    int checksum,
  ) {
    // Replace _p1 array
    content = content.replaceAllMapped(
      RegExp(r'_p1:\s*\[[^\]]+\]'),
      (match) => '_p1: [${p1Array.join(",")}]',
    );

    // Replace _p2 value
    content = content.replaceAllMapped(
      RegExp(r'_p2:\s*\d+'),
      (match) => '_p2: $p2Code',
    );

    // Replace _p3 array
    content = content.replaceAllMapped(
      RegExp(r'_p3:\s*\[[^\]]+\]'),
      (match) => '_p3: [${p3Array.join(",")}]',
    );

    // Replace checksum
    content = content.replaceAllMapped(
      RegExp(r'_checksum:\s*-?\d+'),
      (match) => '_checksum: $checksum',
    );

    return content;
  }

  /// Extract UPI from security.js encoded format
  String? _extractUpiFromSecurityJs(String content) {
    try {
      // Extract _p1 array
      final p1Match = RegExp(r'_p1:\s*\[([^\]]+)\]').firstMatch(content);
      if (p1Match == null) return null;
      final p1Codes = p1Match.group(1)!.split(',').map((s) => int.parse(s.trim())).toList();
      
      // Extract _p2 value
      final p2Match = RegExp(r'_p2:\s*(\d+)').firstMatch(content);
      if (p2Match == null) return null;
      final p2Code = int.parse(p2Match.group(1)!);
      
      // Extract _p3 array
      final p3Match = RegExp(r'_p3:\s*\[([^\]]+)\]').firstMatch(content);
      if (p3Match == null) return null;
      final p3Codes = p3Match.group(1)!.split(',').map((s) => int.parse(s.trim())).toList();
      
      // Reconstruct UPI
      final p1 = String.fromCharCodes(p1Codes);
      final p2 = String.fromCharCode(p2Code);
      final p3 = String.fromCharCodes(p3Codes);
      
      return '$p1$p2$p3';
    } catch (e) {
      return null;
    }
  }

  /// Get current WhatsApp number from index.html
  Future<String?> _getCurrentWhatsAppNumber() async {
    try {
      final response = await _dio.get(
        '$_repoPath/contents/index.html',
        queryParameters: {'ref': settings.branch},
      );
      
      final content = utf8.decode(base64.decode(
        response.data['content'].toString().replaceAll('\n', ''),
      ));
      
      // Extract WhatsApp number from URL like wa.me/917019235581
      final match = RegExp(r'wa\.me/(\d+)').firstMatch(content);
      return match?.group(1);
    } catch (e) {
      return null;
    }
  }

  /// Update WhatsApp number in a single file
  Future<bool> _updateWhatsAppInFile(String filePath, String oldNumber, String newNumber) async {
    try {
      final response = await _dio.get(
        '$_repoPath/contents/$filePath',
        queryParameters: {'ref': settings.branch},
      );
      
      final content = utf8.decode(base64.decode(
        response.data['content'].toString().replaceAll('\n', ''),
      ));
      final sha = response.data['sha'];

      // Check if this file contains the old number
      if (!content.contains(oldNumber)) {
        return false; // Skip files that don't have the number
      }

      // Replace all occurrences
      final updatedContent = content.replaceAll(oldNumber, newNumber);

      // Push to GitHub
      await _dio.put(
        '$_repoPath/contents/$filePath',
        data: {
          'message': 'Update WhatsApp number in $filePath via Trip Manager App',
          'content': base64.encode(utf8.encode(updatedContent)),
          'sha': sha,
          'branch': settings.branch,
        },
      );

      return true;
    } catch (e) {
      rethrow;
    }
  }

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

/// Result of an update operation
class UpdateResult {
  final bool success;
  final String? message;
  final String? error;
  final String? details;

  UpdateResult({
    required this.success,
    this.message,
    this.error,
    this.details,
  });
}

/// Current website settings
class WebsiteSettings {
  final String? upiId;
  final String? whatsAppNumber;

  WebsiteSettings({
    this.upiId,
    this.whatsAppNumber,
  });
}
