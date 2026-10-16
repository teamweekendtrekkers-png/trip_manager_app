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
    'version': 2,
    'payment': <String, dynamic>{
      'upiId': '',
      'receiverName': '',
      'showReceiverName': true,
      'showRazorpay': false,
      'mode': 'direct',
      'checkoutVersion': 2,
      'requestTripIds': <String>[],
      'activeProfileId': 'primary',
      'profiles': <Map<String,dynamic>>[
        {'id':'primary','label':'Primary account','upiId':'','receiverName':'','qrImage':''},
        {'id':'backup','label':'Backup account','upiId':'','receiverName':'','qrImage':''},
      ],
      'directDepartures': <Map<String, dynamic>>[],
      'showQr': false,
      'qrImage': '',
      'instructions': '',
    },
    'showCoupons': true,
    'coupons': <Map<String, dynamic>>[],
  };

  static Map<String,dynamic> normalize(Map<String,dynamic> value) {
    final p=<String,dynamic>{...(defaults()['payment'] as Map), ...?(value['payment'] as Map?)};
    if ((value['payment'] as Map?)?['profiles'] is! List) {
      p['profiles']=<Map<String,dynamic>>[
        {'id':'primary','label':'Primary account','upiId':p['upiId'],'receiverName':p['receiverName'],'qrImage':p['qrImage']},
        {'id':'backup','label':'Backup account','upiId':'','receiverName':'','qrImage':''},
      ];
      p['activeProfileId']='primary';
    }
    p['checkoutVersion']=2;p['mode']='direct';p['directDepartures']=<Map<String,dynamic>>[];
    p['showRazorpay']=false;p['showReceiverName']=true;
    p['requestTripIds']=List<String>.from(p['requestTripIds'] as List? ?? []);
    final active=(p['profiles'] as List).cast<Map>().firstWhere((a)=>a['id']==p['activeProfileId']);
    for(final key in ['upiId','receiverName','qrImage'])p[key]=active[key]??'';
    return {...value,'version':2,'payment':p};
  }

  static bool validQrPath(String value) =>
      RegExp(
        r'^images/[a-zA-Z0-9_./-]+\.(png|jpe?g|webp)$',
        caseSensitive: false,
      ).hasMatch(value) &&
      !value.split('/').contains('..') &&
      !value.contains('//');

  static bool _dateKey(String value) {
    final parts = value.split('/');
    if (parts.length != 2) return false;
    final dates = parts.map(DateTime.tryParse).toList();
    return dates.every((date) => date != null) &&
        List.generate(
          2,
          (i) => dates[i]!.toIso8601String().substring(0, 10) == parts[i],
        ).every((v) => v) &&
        !dates[1]!.isBefore(dates[0]!);
  }

  static void validate(Map<String, dynamic> config) {
    if (![1,2].contains(config['version']) ||
        config['payment'] is! Map ||
        config['coupons'] is! List ||
        config['showCoupons'] is! bool) {
      throw const FormatException('Unsupported payment settings.');
    }
    final payment = config['payment'] as Map;
    if(payment['profiles']!=null){
      final profiles=payment['profiles'];
      if(profiles is! List||profiles.length!=2)throw const FormatException('Keep exactly two payment profiles.');
      final ids=<String>{};
      for(final account in profiles){
        if(account is! Map||account['id'] is! String||!ids.add(account['id'])||account['label'] is! String||account['label'].toString().trim().isEmpty||account['label'].toString().length>80||account['upiId'] is! String||account['receiverName'] is! String||account['qrImage'] is! String)throw const FormatException('Invalid payment profile.');
        final id=account['upiId'] as String,qr=account['qrImage'] as String;
        if(id.isNotEmpty&&!RegExp(r'^[\w.-]+@[\w.-]+$').hasMatch(id))throw const FormatException('Enter a valid UPI ID for each account.');
        if(qr.isNotEmpty&&!validQrPath(qr))throw const FormatException('Choose an original PNG, JPG or WebP QR image.');
      }
      if(!ids.contains(payment['activeProfileId']))throw const FormatException('Choose an active payment account.');
      final requests=payment['requestTripIds'];
      if(requests is! List||requests.length>1000||requests.any((id)=>id is! String||!RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(id))||requests.toSet().length!=requests.length)throw const FormatException('Choose unique trips for optional booking requests.');
    }
    final upi = payment['upiId'];
    if (upi is! String ||
        (upi.isNotEmpty && !RegExp(r'^[\w.-]+@[\w.-]+$').hasMatch(upi))) {
      throw const FormatException(
        'Enter a valid UPI ID, or leave it blank to use the existing account.',
      );
    }
    if (payment['receiverName'] is! String ||
        payment['showReceiverName'] is! bool ||
        payment['showRazorpay'] is! bool) {
      throw const FormatException('Invalid payment display settings.');
    }
    if (![
          'confirmation',
          'direct',
          'both',
        ].contains(payment['mode'] ?? 'confirmation') ||
        (payment['showQr'] ?? false) is! bool ||
        (payment['qrImage'] ?? '') is! String ||
        (payment['instructions'] ?? '') is! String ||
        (payment['instructions'] ?? '').toString().length > 500) {
      throw const FormatException('Invalid payment mode or QR settings.');
    }
    final image = payment['qrImage'] ?? '';
    if (image.isNotEmpty && !validQrPath(image))
      throw const FormatException(
        'Choose a PNG, JPG or WebP image inside the images folder.',
      );
    if (payment['showQr'] == true && image.isEmpty)
      throw const FormatException(
        'Upload or choose a QR image before showing the QR section.',
      );
    final approvals = payment['directDepartures'] ?? [];
    if (approvals is! List || approvals.length > 1000)
      throw const FormatException('Invalid direct-payment departures.');
    final approved = <String>{};
    for (final item in approvals) {
      if (item is! Map ||
          item['tripId'] is! String ||
          !RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(item['tripId']) ||
          item['dateKey'] is! String ||
          !_dateKey(item['dateKey']) ||
          !approved.add('${item['tripId']}|${item['dateKey']}')) {
        throw const FormatException(
          'Direct-payment approvals require unique trips and valid departure dates.',
        );
      }
    }
    final codes = <String>{};
    for (final raw in config['coupons'] as List) {
      if (raw is! Map) throw const FormatException('Invalid coupon.');
      final code = raw['code']?.toString().trim().toUpperCase() ?? '';
      final value = raw['value'];
      if (!RegExp(r'^[A-Z0-9_-]{2,40}$').hasMatch(code) || !codes.add(code)) {
        throw const FormatException(
          'Coupon codes must be unique and contain 2–40 letters, numbers, hyphens or underscores.',
        );
      }
      if (!['fixed', 'percent'].contains(raw['type']) ||
          value is! num ||
          !value.isFinite ||
          value <= 0 ||
          (raw['type'] == 'percent' && value > 100)) {
        throw const FormatException(
          'Enter a positive coupon amount, or a percentage up to 100.',
        );
      }
      if (raw['enabled'] is! bool ||
          raw['tripIds'] is! List ||
          (raw['tripIds'] as List).any((id) => id is! String)) {
        throw const FormatException('Invalid coupon eligibility.');
      }
      final cap = raw['maxDiscount'];
      if (cap != null && (cap is! num || !cap.isFinite || cap <= 0))
        throw const FormatException('Maximum savings must be positive.');
      DateTime? starts;
      DateTime? expires;
      for (final field in ['startsAt', 'expiresAt']) {
        final text = raw[field];
        if (text == null || text == '') continue;
        final parsed = text is String ? DateTime.tryParse(text) : null;
        if (parsed == null ||
            !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(text as String))
          throw const FormatException('Coupon dates must include a time zone.');
        if (field == 'startsAt') {
          starts = parsed;
        } else {
          expires = parsed;
        }
      }
      if (starts != null && expires != null && !expires.isAfter(starts))
        throw const FormatException('Coupon expiry must follow its start.');
    }
  }

  Future<Map<String, dynamic>> load() async {
    final file = await github.fetchFile(path);
    if (!file.success && file.statusCode != 404)
      throw StateError(file.error ?? 'Cannot load payment settings.');
    _sha = file.success ? file.sha : null;
    _baseContent = file.success ? file.content : null;
    _loaded = true;
    final config = file.success
        ? Map<String, dynamic>.from(jsonDecode(file.content) as Map)
        : defaults();
    validate(config);
    return normalize(config);
  }

  Future<GitHubCommitResult> save(Map<String, dynamic> config) async {
    if (!_loaded)
      return GitHubCommitResult(
        success: false,
        error: 'Load settings before publishing.',
      );
    try {
      validate(config);
      final latest = await github.fetchFile(path);
      if (!latest.success && latest.statusCode != 404)
        throw StateError(latest.error ?? 'Cannot check current settings.');
      if ((latest.success ? latest.sha : null) != _sha ||
          (latest.success ? latest.content : null) != _baseContent) {
        return GitHubCommitResult(
          success: false,
          hasConflict: true,
          error:
              'Payment settings changed remotely. Your edits are retained; review the latest settings before publishing.',
        );
      }
      final files = <String, String>{
        path: '${const JsonEncoder.withIndent('  ').convert(config)}\n',
      };
      final expected = <String, String?>{path: _sha};
      final upi = (config['payment'] as Map)['upiId'] as String;
      if (upi.isNotEmpty) {
        final security = await github.fetchFile('js/security.js');
        if (!security.success)
          throw StateError('Cannot load the existing UPI configuration.');
        final parts = upi.split('@');
        var checksum = 0;
        for (final unit in upi.codeUnits) {
          checksum = ((checksum << 5) - checksum + unit).toSigned(32);
        }
        var source = security.content;
        for (final entry in {
          r'_p1:\s*\[[^\]]+\]': '_p1: [${parts[0].codeUnits.join(',')}]',
          r'_p2:\s*\d+': '_p2: 64',
          r'_p3:\s*\[[^\]]+\]': '_p3: [${parts[1].codeUnits.join(',')}]',
          r'_checksum:\s*-?\d+': '_checksum: $checksum',
        }.entries) {
          final pattern = RegExp(entry.key);
          if (pattern.allMatches(source).length != 1)
            throw StateError('UPI configuration needs review before updating.');
          source = source.replaceFirst(pattern, entry.value);
        }
        if (source != security.content) {
          files['js/security.js'] = source;
          expected['js/security.js'] = security.sha;
        }
      }
      final result = await github.commitFilesAtomically(
        files: files,
        expectedBlobShas: expected,
        commitMessage:
            'Update payment settings and coupon offers via Trip Manager',
      );
      if (result.success) {
        _sha = result.fileBlobShas[path];
        _baseContent = files[path];
      }
      return result;
    } catch (error) {
      return GitHubCommitResult(success: false, error: error.toString());
    }
  }
}
