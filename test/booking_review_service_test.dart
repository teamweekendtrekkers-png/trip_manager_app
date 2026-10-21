import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/services/github_service.dart';
import 'package:trip_manager_app/services/booking_review_service.dart';

class BookingConfig extends GitHubService {
  BookingConfig() : super(settings: AppSettings());
  @override
  Future<GitHubFileResult> fetchFile(String path) async => GitHubFileResult(
    success: true, sha: 'config', content: jsonEncode({
      'endpoint': '${BookingReviewService.origin}/functions/v1/booking-request',
      'anonKey': 'header.${base64Url.encode(utf8.encode(jsonEncode({'role':'anon','ref':'vdxunrhcahgkwtzvjjdj'})))}.signature',
    }),
  );
}
void main() {
  test('analytics requires admin login and sends only aggregate filters', () async {
    final service=BookingReviewService(BookingConfig(),client:MockClient((request) async {
      if(request.url.path=='/auth/v1/token') return http.Response(jsonEncode({'access_token':'session','user':{'app_metadata':{'trip_manager_admin':true}}}),200);
      expect(request.url.path,'/rest/v1/rpc/twt_journey_report');
      expect(jsonDecode(request.body),{'p_start':'2026-10-01','p_end':'2026-10-21','p_trip':'theyyam','p_device':'mobile'});
      expect(request.headers['Authorization'],'Bearer session');
      return http.Response('{"sessions":12,"funnel":[]}',200);
    }));
    await expectLater(service.analytics(start:'2026-10-01',end:'2026-10-21'),throwsStateError);
    await service.signIn('admin@example.com','password');
    final result=await service.analytics(start:'2026-10-01',end:'2026-10-21',trip:'theyyam',device:'mobile');
    expect(result['sessions'],12);service.dispose();
  });
  test('GitHub access and a non-admin Supabase account cannot read bookings', () async {
    var calls = 0;
    final service = BookingReviewService(BookingConfig(), client: MockClient((request) async {
      calls++;
      expect(request.url.path, '/auth/v1/token');
      return http.Response(jsonEncode({'access_token':'session','user':{'app_metadata':{}}}), 200);
    }));
    await expectLater(service.load(), throwsStateError);
    expect(calls, 0);
    await expectLater(service.signIn('admin@example.com', 'password'), throwsStateError);
    expect(service.signedIn, false);
    await expectLater(service.load(), throwsStateError);
    expect(calls, 1);
    service.dispose();
  });
  test('admin session sends a leased manual review and expires on access denial', () async {
    var deny = false;
    final service = BookingReviewService(BookingConfig(), client: MockClient((request) async {
      if (request.url.path == '/auth/v1/token') return http.Response(jsonEncode({'access_token':'session','user':{'app_metadata':{'trip_manager_admin':true}}}), 200);
      expect(request.headers['Authorization'], 'Bearer session');
      if (deny) return http.Response('{}', 403);
      final body = jsonDecode(request.body);
      if (request.url.path.endsWith('twt_list_bookings')) {
        expect(body['p_search'], 'UPI123456'); expect(body['p_offset'], 50);
        return http.Response('[{"id":"demo","payment_reviewed_at":"2026-10-16T00:00:00Z"}]', 200);
      }
      expect(request.url.path, '/rest/v1/rpc/twt_review_booking');
      expect(body['p_status'], 'verified');
      expect(body['p_expected_at'], '2026-10-16T00:00:00Z');
      expect(body['p_note'], 'Credit checked');
      return http.Response('{"saved":true}', 200);
    }));
    await service.signIn('admin@example.com','password');
    final rows = await service.load(search: 'UPI123456', offset: 50);
    await service.review(rows.single,'verified','Credit checked');
    deny = true;
    await expectLater(service.load(), throwsStateError);
    expect(service.signedIn, false);
    service.dispose();
  });
}
