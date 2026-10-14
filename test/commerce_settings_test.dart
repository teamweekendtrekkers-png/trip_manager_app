import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/services/github_service.dart';
import 'package:trip_manager_app/services/commerce_settings_service.dart';
import 'package:trip_manager_app/services/trip_date_utils.dart';
import 'package:trip_manager_app/services/trips_parser.dart';

class MemoryCommerce extends GitHubService {
  MemoryCommerce() : super(settings: AppSettings());
  String content = jsonEncode(CommerceSettingsService.defaults());
  String sha = 'base';
  int commits = 0;
  @override
  Future<GitHubFileResult> fetchFile(String path) async =>
      GitHubFileResult(content: content, sha: sha, success: true);
  @override
  Future<GitHubCommitResult> commitFilesAtomically({
    required Map<String, String> files,
    required Map<String, String?> expectedBlobShas,
    required String commitMessage,
  }) async {
    expect(expectedBlobShas[CommerceSettingsService.path], sha);
    commits++;
    content = files[CommerceSettingsService.path]!;
    sha = 'saved';
    return GitHubCommitResult(
      success: true,
      fileBlobShas: {CommerceSettingsService.path: sha},
    );
  }
}

void main() {
  test(
    'legacy payment settings keep confirmation-first and a hidden QR section',
    () async {
      final github = MemoryCommerce();
      github.content = jsonEncode({
        'version': 1,
        'payment': {
          'upiId': '',
          'receiverName': '',
          'showReceiverName': true,
          'showRazorpay': false,
        },
        'showCoupons': true,
        'coupons': [],
      });
      final config = await CommerceSettingsService(github).load();
      expect(config['payment']['mode'], 'confirmation');
      expect(config['payment']['showQr'], false);
      expect(config['payment']['directDepartures'], isEmpty);
    },
  );
  test('payment modes and QR approvals validate before publication', () async {
    final config = CommerceSettingsService.defaults();
    final payment = config['payment'] as Map<String, dynamic>;
    payment.addAll({
      'mode': 'both',
      'showQr': true,
      'qrImage': 'images/trips/payment-qr.png',
      'instructions': 'Check the receiver name.',
      'directDepartures': [
        {'tripId': 'demo', 'dateKey': '2099-12-20/2099-12-22'},
      ],
    });
    CommerceSettingsService.validate(config);
    for (final override in [
      {'mode': 'automatic'},
      {'showQr': true, 'qrImage': ''},
      {'qrImage': 'images/../qr.png'},
      {'qrImage': 'https://evil.test/qr.png'},
      {'qrImage': 'images/qr.svg'},
      {
        'directDepartures': [
          {'tripId': 'demo', 'dateKey': '2099-02-30/2099-03-01'},
        ],
      },
      {
        'directDepartures': [
          {'tripId': 'demo', 'dateKey': '2099-12-22/2099-12-20'},
        ],
      },
    ]) {
      expect(
        () => CommerceSettingsService.validate({
          ...config,
          'payment': {...payment, ...override},
        }),
        throwsFormatException,
      );
    }
    final github = MemoryCommerce();
    final service = CommerceSettingsService(github);
    await service.load();
    expect((await service.save(config)).success, true);
    final saved = jsonDecode(github.content)['payment'];
    expect(saved['mode'], 'both');
    expect(saved['qrImage'], 'images/trips/payment-qr.png');
    expect(saved['directDepartures'], payment['directDepartures']);
    payment['showQr'] = false;
    CommerceSettingsService.validate(config);
    expect(payment['qrImage'], 'images/trips/payment-qr.png');
  });
  test(
    'settings publish with a lease and conflicting edits are retained',
    () async {
      final github = MemoryCommerce();
      final service = CommerceSettingsService(github);
      final draft = await service.load();
      draft['showCoupons'] = false;
      expect((await service.save(draft)).success, true);
      expect(github.commits, 1);
      github.sha = 'someone-else';
      expect((await service.save(draft)).hasConflict, true);
      expect(github.commits, 1);
      expect(draft['showCoupons'], false);
    },
  );
  test('invalid discounts and duplicate codes block publishing', () {
    final config = CommerceSettingsService.defaults();
    final coupon = {
      'code': 'WEEKEND',
      'type': 'percent',
      'value': 20,
      'enabled': true,
      'tripIds': <String>[],
      'expiresAt': '2026-12-01T00:00:00+05:30',
    };
    config['coupons'] = [coupon];
    CommerceSettingsService.validate(config);
    for (final invalid in [
      {...coupon, 'value': 101},
      {...coupon, 'maxDiscount': -1},
      {...coupon, 'expiresAt': '2026-12-01'},
      {
        ...coupon,
        'tripIds': [1],
      },
    ]) {
      config['coupons'] = [invalid];
      expect(
        () => CommerceSettingsService.validate(config),
        throwsFormatException,
      );
    }
    config['coupons'] = [
      coupon,
      {...coupon, 'code': 'weekend'},
    ];
    expect(
      () => CommerceSettingsService.validate(config),
      throwsFormatException,
    );
  });
  test(
    'booking cutoff uses departure time plus 24 hours, including year changes',
    () {
      final trip = {
        'availableDates': ['Dec 31-Jan 2, 2026-2027'],
        'departureTime': '20:30',
      };
      final range = TripDateUtils.parse(
        (trip['availableDates'] as List).first as String,
      )!;
      expect(
        TripDateUtils.bookingCutoff(range, trip),
        DateTime.utc(2027, 1, 1, 15),
      );
      expect(
        TripDateUtils.getUpcomingDateRanges(
          trip,
          referenceDate: DateTime.utc(2027, 1, 1, 14, 59, 59),
        ),
        hasLength(1),
      );
      expect(
        TripDateUtils.getUpcomingDateRanges(
          trip,
          referenceDate: DateTime.utc(2027, 1, 1, 15),
        ),
        isEmpty,
      );
      expect(
        TripDateUtils.departureClock({
          'boardingLocations': [
            {'time': '8:30 PM'},
          ],
        }),
        '20:30',
      );
    },
  );
  test('public slugs round-trip and duplicate routes block publication', () {
    final trips = <Map<String, dynamic>>[
      {
        'id': 'legacy',
        'title': 'Updated trip',
        'image': 'images/cover.jpg',
        'publicSlug': 'new-trip',
        'previousSlugs': ['old-trip'],
        'departureTime': '20:30',
      },
    ];
    final source = TripsParser.generateTripsDataJs(trips);
    final restored = TripsParser.parseTripsDocument(source).trips.single;
    expect(restored['previousSlugs'], ['old-trip']);
    expect(restored['publicSlug'], 'new-trip');
    expect(
      () => TripsParser.generateTripsDataJs([
        ...trips,
        {'id': 'new-trip', 'title': 'Other'},
      ]),
      throwsFormatException,
    );
  });
}
