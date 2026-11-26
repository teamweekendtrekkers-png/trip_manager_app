import 'dart:convert';

import 'package:http/http.dart' as http;

typedef PickupDeparture = ({String slug, String title, String date, bool open});

class PickupService {
  PickupService({http.Client? client}) : _client = client ?? http.Client();

  static final organizer = PickupService();
  static const _project = 'rllukahyjluwcsttpcdl.supabase.co';
  final http.Client _client;
  String? _key;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _expires;

  bool get signedIn => _accessToken != null;

  Future<String> _publicKey() async {
    if (_key != null) return _key!;
    final response = await _client
        .get(Uri.https('www.teamweekendtrekkers.com', '/pickup/config.json'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw StateError('Pickup is unavailable.');
    final settings = jsonDecode(response.body) as Map;
    final key = settings['key'];
    if (settings['url'] != 'https://$_project' ||
        key is! String ||
        !key.startsWith('sb_publishable_')) {
      throw StateError('Pickup is unavailable.');
    }
    return _key = key;
  }

  Future<void> _exchange(String grant, Map<String, String> credentials) async {
    final response = await _client
        .post(
          Uri.https(_project, '/auth/v1/token', {'grant_type': grant}),
          headers: {
            'apikey': await _publicKey(),
            'Content-Type': 'application/json',
          },
          body: jsonEncode(credentials),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode >= 500 || response.statusCode == 429) {
      throw StateError('Pickup sign-in is temporarily unavailable.');
    }
    final data = jsonDecode(response.body) as Map;
    if (response.statusCode != 200 ||
        (data['user'] as Map?)?['app_metadata']?['pickup_captain'] != true ||
        data['access_token'] is! String ||
        data['refresh_token'] is! String ||
        data['expires_in'] is! num) {
      _accessToken = _refreshToken = null;
      _expires = null;
      throw StateError('Sign in with your Pickup organizer account.');
    }
    _accessToken = data['access_token'] as String;
    _refreshToken = data['refresh_token'] as String;
    _expires = DateTime.now().add(
      Duration(seconds: (data['expires_in'] as num).toInt()),
    );
  }

  Future<void> signIn(String email, String password) =>
      _exchange('password', {'email': email.trim(), 'password': password});

  Future<void> signOut() async {
    final token = _accessToken;
    _accessToken = _refreshToken = null;
    _expires = null;
    if (token != null && _key != null) {
      try {
        await _client
            .post(
              Uri.https(_project, '/auth/v1/logout', {'scope': 'local'}),
              headers: {'apikey': _key!, 'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Local session has already been cleared.
      }
    }
  }

  Future<List<Map<String, dynamic>>> _rows(
    String table,
    Map<String, String> filters, {
    bool private = false,
  }) async {
    if (private && !signedIn) {
      throw StateError('Sign in to see traveller details.');
    }
    if (signedIn &&
        _expires!.isBefore(DateTime.now().add(const Duration(seconds: 45)))) {
      await _exchange('refresh_token', {'refresh_token': _refreshToken!});
    }
    final response = await _client
        .get(
          Uri.https(_project, '/rest/v1/$table', filters),
          headers: {
            'apikey': await _publicKey(),
            if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
          },
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode == 401 || response.statusCode == 403) {
      _accessToken = _refreshToken = null;
      _expires = null;
      throw StateError('Pickup access expired. Sign in again.');
    }
    if (response.statusCode != 200 && response.statusCode != 206) {
      throw StateError('Could not load the pickup list.');
    }
    return (jsonDecode(utf8.decode(response.bodyBytes)) as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<PickupDeparture>> departures() async {
    final rows = await _rows('pickup_departures', {
      'select': 'slug,title,departure_date,open',
      'order': 'departure_date.desc,slug.asc',
    });
    return [
      for (final row in rows)
        (
          slug: row['slug'] as String,
          title: row['title'] as String,
          date: row['departure_date'] as String,
          open: row['open'] as bool,
        ),
    ];
  }

  Future<List<Map<String, dynamic>>> stops(String slug) =>
      _rows('pickup_stops', {
        'select': 'id,name,pickup_time',
        'departure': 'eq.$slug',
        'order': 'position,id',
      }, private: true);

  Future<List<Map<String, dynamic>>> checkIns(String slug) async {
    final rows = <Map<String, dynamic>>[];
    const pageSize = 200;
    for (var offset = 0; ; offset += pageSize) {
      final page = await _rows('pickup_checkins', {
        'select': 'lead_name,phone,party_size,stop,passenger_names',
        'departure': 'eq.$slug',
        'updated_at': 'not.is.null',
        'order': 'code',
        'limit': '$pageSize',
        'offset': '$offset',
      }, private: true);
      rows.addAll(page);
      if (page.length < pageSize) return rows;
    }
  }
}
