import 'dart:convert';
import 'package:http/http.dart' as http;
import 'github_service.dart';

class GoogleReviewService {
  GoogleReviewService(this.github, {http.Client? client})
    : client = client ?? http.Client();
  final GitHubService github;
  final http.Client client;
  Future<Map<String, dynamic>> check() async {
    try {
      final file = await github.fetchFile('js/booking-config.json');
      if (!file.success) throw StateError('Review connection unavailable.');
      final config = jsonDecode(file.content) as Map;
      const origin = 'https://vdxunrhcahgkwtzvjjdj.supabase.co';
      if (config['endpoint'] != '$origin/functions/v1/booking-request' ||
          config['anonKey'] is! String)
        throw StateError('Review connection unavailable.');
      final response = await client
          .get(
            Uri.parse('$origin/functions/v1/google-reviews'),
            headers: {
              'apikey': config['anonKey'],
              'Authorization': 'Bearer ${config['anonKey']}',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200)
        throw StateError('Review connection unavailable. Try again later.');
      final result = jsonDecode(response.body);
      if (result is! Map<String, dynamic> || result['connected'] is! bool)
        throw StateError('Review connection unavailable.');
      return result;
    } finally {
      client.close();
    }
  }
}
