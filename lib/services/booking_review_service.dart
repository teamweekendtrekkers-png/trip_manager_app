import 'dart:convert';
import 'package:http/http.dart' as http;
import 'github_service.dart';

/// A separate Supabase administrator login; GitHub access never grants access
/// to customer records. The access token lives only for this screen's session.
class BookingReviewService {
  BookingReviewService(this.github, {http.Client? client})
    : _client = client ?? http.Client();
  final GitHubService github;
  final http.Client _client;
  static const origin = 'https://vdxunrhcahgkwtzvjjdj.supabase.co';
  String? _anon, _token;
  bool get signedIn => _token != null;

  Future<void> signIn(String email, String password) async {
    final file = await github.fetchFile('js/booking-config.json');
    if (!file.success) throw StateError('Could not load booking service settings.');
    final config = jsonDecode(file.content) as Map;
    if (config['endpoint'] != '$origin/functions/v1/booking-request' ||
        config['anonKey'] is! String) {
      throw StateError('The booking service is not configured.');
    }
    _anon = config['anonKey'] as String;
    // Accept only the project's public anon JWT, never an admin/service key.
    final parts = _anon!.split('.');
    Map claims;
    try {
      claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map;
    } catch (_) { throw StateError('A public booking service key is required.'); }
    if (claims['role'] != 'anon' || claims['ref'] != 'vdxunrhcahgkwtzvjjdj') {
      throw StateError('A public booking service key is required.');
    }
    final response = await _client.post(
      Uri.parse('$origin/auth/v1/token?grant_type=password'),
      headers: {'apikey': _anon!, 'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw StateError('Sign-in failed. Check your administrator account.');
    final result = jsonDecode(response.body) as Map;
    if ((result['user'] as Map?)?['app_metadata']?['trip_manager_admin'] != true ||
        result['access_token'] is! String) {
      throw StateError('This account has not been granted booking administrator access.');
    }
    _token = result['access_token'] as String;
  }

  Future<Object?> _rpc(String name, Map<String, dynamic> body) async {
    if (!signedIn) throw StateError('Sign in to review bookings.');
    final response = await _client.post(Uri.parse('$origin/rest/v1/rpc/$name'),
      headers: {'apikey': _anon!, 'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode == 401 || response.statusCode == 403) {
      _token = null;
      throw StateError('Your session expired or access was denied. Sign in again.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = response.body.contains('review_conflict')
        ? 'Another administrator changed this review. Refresh before trying again.'
        : name == 'twt_journey_report' ? 'Analytics is unavailable. Check the analytics database setup or try again.' : 'Booking review is unavailable. Check the database migration and try again.';
      throw StateError(error);
    }
    return jsonDecode(response.body);
  }

  Future<List<Map<String, dynamic>>> load({String search = '', int offset = 0}) async {
    final result = await _rpc('twt_list_bookings', {'p_search': search.trim(), 'p_offset': offset});
    return (result as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<Map<String, dynamic>> analytics({required String start, required String end, String trip = '', String device = ''}) async {
    final result = await _rpc('twt_journey_report', {'p_start': start, 'p_end': end, 'p_trip': trip, 'p_device': device});
    if (result is! Map) throw StateError('Analytics returned an invalid report.');
    return Map<String, dynamic>.from(result);
  }

  Future<void> review(Map<String, dynamic> booking, String status, String note) async {
    if (!['verified', 'rejected', 'pending'].contains(status)) throw ArgumentError('Invalid review status');
    await _rpc('twt_review_booking', {'p_id': booking['id'], 'p_status': status,
      'p_note': note.trim(), 'p_expected_at': booking['payment_reviewed_at']});
  }

  Future<void> signOut() async {
    final token = _token;
    _token = null;
    if (token != null) {
      try {
        await _client.post(Uri.parse('$origin/auth/v1/logout'),
          headers: {'apikey': _anon!, 'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 10));
      } catch (_) { /* Local credentials are cleared even if offline. */ }
    }
  }
  void dispose() { _token = null; _client.close(); }
}
