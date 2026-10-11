import 'dart:convert';
import 'github_service.dart';

/// Coupon quotes are verified by the team before payment; no browser-only usage limits.
class CommerceSettingsService {
  CommerceSettingsService(this.github);
  final GitHubService github;
  static const path = 'js/commerce-config.json';
  String? _baseContent;
  String? _sha;
  bool _loaded = false;
  static Map<String, dynamic> defaults() => {
    'version': 1,
    'payment': {'upiId': '', 'receiverName': '', 'showReceiverName': true, 'showRazorpay': false},
    'showCoupons': true,
    'coupons': <Map<String, dynamic>>[],
  };

  static void validate(Map<String, dynamic> config) {
    if (config['version'] != 1 || config['payment'] is! Map || config['coupons'] is! List || config['showCoupons'] is! bool) {
      throw const FormatException('Unsupported payment settings.');
    }
    final payment = config['payment'] as Map;
    final upi = payment['upiId'];
    if (upi is! String || (upi.isNotEmpty && !RegExp(r'^[\w.-]+@[\w.-]+$').hasMatch(upi))) {
      throw const FormatException('Enter a valid UPI ID, or leave it blank to use the existing account.');
    }
    if (payment['receiverName'] is! String || payment['showReceiverName'] is! bool || payment['showRazorpay'] is! bool) {
      throw const FormatException('Invalid payment display settings.');
    }
    final codes = <String>{};
    for (final raw in config['coupons'] as List) {
      if (raw is! Map) throw const FormatException('Invalid coupon.');
      final code = raw['code']?.toString().trim().toUpperCase() ?? '';
      final value = raw['value'];
      if (!RegExp(r'^[A-Z0-9_-]{2,40}$').hasMatch(code) || !codes.add(code)) {
        throw const FormatException('Coupon codes must be unique and contain 2–40 letters, numbers, hyphens or underscores.');
      }
      if (!['fixed', 'percent'].contains(raw['type']) || value is! num || !value.isFinite || value <= 0 || (raw['type'] == 'percent' && value > 100)) {
        throw const FormatException('Enter a positive coupon amount, or a percentage up to 100.');
      }
      if (raw['enabled'] is! bool || raw['tripIds'] is! List || (raw['tripIds'] as List).any((id) => id is! String)) {
        throw const FormatException('Invalid coupon eligibility.');
      }
      final cap = raw['maxDiscount'];
      if (cap != null && (cap is! num || !cap.isFinite || cap <= 0)) throw const FormatException('Maximum savings must be positive.');
      DateTime? starts;
      DateTime? expires;
      for (final field in ['startsAt', 'expiresAt']) {
        final text = raw[field];
        if (text == null || text == '') continue;
        final parsed = text is String ? DateTime.tryParse(text) : null;
        if (parsed == null || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(text as String)) throw const FormatException('Coupon dates must include a time zone.');
        if (field == 'startsAt') { starts = parsed; } else { expires = parsed; }
      }
      if (starts != null && expires != null && !expires.isAfter(starts)) throw const FormatException('Coupon expiry must follow its start.');
    }
  }

  Future<Map<String, dynamic>> load() async {
    final file = await github.fetchFile(path);
    if (!file.success && file.statusCode != 404) throw StateError(file.error ?? 'Cannot load payment settings.');
    _sha = file.success ? file.sha : null;
    _baseContent = file.success ? file.content : null;
    _loaded = true;
    final config = file.success ? Map<String, dynamic>.from(jsonDecode(file.content) as Map) : defaults();
    validate(config);
    return config;
  }

  Future<GitHubCommitResult> save(Map<String, dynamic> config) async {
    if (!_loaded) return GitHubCommitResult(success: false, error: 'Load settings before publishing.');
    try {
      validate(config);
      final latest = await github.fetchFile(path);
      if (!latest.success && latest.statusCode != 404) throw StateError(latest.error ?? 'Cannot check current settings.');
      if ((latest.success ? latest.sha : null) != _sha || (latest.success ? latest.content : null) != _baseContent) {
        return GitHubCommitResult(success: false, hasConflict: true, error: 'Payment settings changed remotely. Your edits are retained; review the latest settings before publishing.');
      }
      final files = <String, String>{path: '${const JsonEncoder.withIndent('  ').convert(config)}\n'};
      final expected = <String, String?>{path: _sha};
      final upi = (config['payment'] as Map)['upiId'] as String;
      if (upi.isNotEmpty) {
        final security = await github.fetchFile('js/security.js');
        if (!security.success) throw StateError('Cannot load the existing UPI configuration.');
        final parts = upi.split('@');
        var checksum = 0;
        for (final unit in upi.codeUnits) { checksum = ((checksum << 5) - checksum + unit).toSigned(32); }
        var source = security.content;
        for (final entry in {
          r'_p1:\s*\[[^\]]+\]': '_p1: [${parts[0].codeUnits.join(',')}]',
          r'_p2:\s*\d+': '_p2: 64',
          r'_p3:\s*\[[^\]]+\]': '_p3: [${parts[1].codeUnits.join(',')}]',
          r'_checksum:\s*-?\d+': '_checksum: $checksum',
        }.entries) {
          final pattern = RegExp(entry.key);
          if (pattern.allMatches(source).length != 1) throw StateError('UPI configuration needs review before updating.');
          source = source.replaceFirst(pattern, entry.value);
        }
        if (source != security.content) { files['js/security.js'] = source; expected['js/security.js'] = security.sha; }
      }
      final result = await github.commitFilesAtomically(files: files, expectedBlobShas: expected, commitMessage: 'Update payment settings and coupon offers via Trip Manager');
      if (result.success) { _sha = result.fileBlobShas[path]; _baseContent = files[path]; }
      return result;
    } catch (error) { return GitHubCommitResult(success: false, error: error.toString()); }
  }
}
