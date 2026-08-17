import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/services/website_settings_service.dart';

const _htmlPaths = <String>[
  'index.html',
  'trips.html',
  'trip-detail.html',
  'about.html',
  'contact.html',
];

void main() {
  group('WebsiteSettingsService characterization', () {
    test('reads the encoded UPI and WhatsApp values', () async {
      final github = _FakeContentsApi();
      final settings = await WebsiteSettingsService(
        settings: _settings,
        dio: github.dio,
      ).getCurrentWebsiteSettings();

      expect(settings.upiId, '9538236581@ybl');
      expect(settings.whatsAppNumber, '917019235581');
      expect(github.putPaths, isEmpty);
    });

    test('updates encoded UPI, checksum, and every masked display', () async {
      final github = _FakeContentsApi();
      final service = WebsiteSettingsService(
        settings: _settings,
        dio: github.dio,
      );

      final result = await service.updateUpiId('1111222233@paytm');

      expect(result.success, isTrue, reason: result.error);
      final security = github.files['js/security.js']!;
      expect(_decodeUpi(security), '1111222233@paytm');
      expect(_readChecksum(security), _checksum('1111222233@paytm'));
      for (final path in _htmlPaths) {
        expect(github.files[path], contains('••••••2233@paytm'), reason: path);
        expect(github.files[path], isNot(contains('••••••6581@ybl')));
      }
      expect(
        github.putPaths,
        containsAll(<String>['js/security.js', ..._htmlPaths]),
      );
    });

    test(
      'updates every WhatsApp occurrence in the configured HTML files',
      () async {
        final github = _FakeContentsApi();
        final result = await WebsiteSettingsService(
          settings: _settings,
          dio: github.dio,
        ).updateWhatsAppNumber('919876543210');

        expect(result.success, isTrue, reason: result.error);
        for (final path in _htmlPaths) {
          expect(github.files[path], contains('919876543210'), reason: path);
          expect(github.files[path], isNot(contains('917019235581')));
        }
        expect(github.putPaths.toSet(), containsAll(_htmlPaths));
      },
    );

    test('invalid inputs fail before making any GitHub request', () async {
      final github = _FakeContentsApi();
      final service = WebsiteSettingsService(
        settings: _settings,
        dio: github.dio,
      );

      final invalidUpi = await service.updateUpiId('not-a-upi');
      final invalidWhatsApp = await service.updateWhatsAppNumber('+91 123');

      expect(invalidUpi.success, isFalse);
      expect(invalidUpi.error, contains('Invalid UPI'));
      expect(invalidWhatsApp.success, isFalse);
      expect(invalidWhatsApp.error, contains('Invalid WhatsApp'));
      expect(github.requestCount, 0);
    });

    test(
      'partial HTML failure is reported without claiming full success',
      () async {
        final github = _FakeContentsApi(failWritesFor: const {'about.html'});
        final result = await WebsiteSettingsService(
          settings: _settings,
          dio: github.dio,
        ).updateWhatsAppNumber('919876543210');

        // Existing behavior treats a partial update as success but reports the
        // exact failed file for operator follow-up.
        expect(result.success, isTrue);
        expect(result.details, contains('about.html'));
        expect(github.files['about.html'], contains('917019235581'));
      },
    );
  });
}

final _settings = AppSettings(
  githubToken: 'test-token',
  repositoryOwner: 'owner',
  repositoryName: 'repo',
  branch: 'main',
);

final class _FakeContentsApi {
  _FakeContentsApi({this.failWritesFor = const <String>{}}) {
    files['js/security.js'] = _security('9538236581@ybl');
    for (final path in _htmlPaths) {
      files[path] = '''
<a href="https://wa.me/917019235581?text=Hello">WhatsApp</a>
<span>••••••6581@ybl</span>
<footer>917019235581</footer>
''';
    }

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestCount += 1;
          final marker = '/contents/';
          final markerIndex = options.path.indexOf(marker);
          final path = markerIndex < 0
              ? ''
              : options.path.substring(markerIndex + marker.length);
          if (!files.containsKey(path)) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: 404,
                  data: const {'message': 'Not found'},
                ),
              ),
            );
            return;
          }

          if (options.method == 'GET') {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'content': base64.encode(utf8.encode(files[path]!)),
                  'sha': 'sha-${putPaths.length}-$path',
                },
              ),
            );
            return;
          }

          if (options.method == 'PUT') {
            if (failWritesFor.contains(path)) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response<dynamic>(
                    requestOptions: options,
                    statusCode: 409,
                    data: const {'message': 'Synthetic write conflict'},
                  ),
                ),
              );
              return;
            }
            final data = Map<String, dynamic>.from(options.data as Map);
            files[path] = utf8.decode(base64.decode(data['content'] as String));
            putPaths.add(path);
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: const <String, dynamic>{},
              ),
            );
            return;
          }

          handler.reject(
            DioException(
              requestOptions: options,
              error: 'Unexpected ${options.method} ${options.path}',
            ),
          );
        },
      ),
    );
  }

  final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.github.test'));
  final Set<String> failWritesFor;
  final Map<String, String> files = <String, String>{};
  final List<String> putPaths = <String>[];
  int requestCount = 0;
}

String _security(String upi) {
  final parts = upi.split('@');
  return '''const SecurityConfig = {
  _p1: [${parts[0].codeUnits.join(',')}],
  _p2: 64,
  _p3: [${parts[1].codeUnits.join(',')}],
  _checksum: ${_checksum(upi)},
};''';
}

String _decodeUpi(String content) {
  List<int> array(String field) => RegExp('$field:\\s*\\[([^\\]]+)\\]')
      .firstMatch(content)!
      .group(1)!
      .split(',')
      .map((value) => int.parse(value.trim()))
      .toList();
  final separator = int.parse(
    RegExp(r'_p2:\s*(\d+)').firstMatch(content)!.group(1)!,
  );
  return String.fromCharCodes(array('_p1')) +
      String.fromCharCode(separator) +
      String.fromCharCodes(array('_p3'));
}

int _readChecksum(String content) =>
    int.parse(RegExp(r'_checksum:\s*(-?\d+)').firstMatch(content)!.group(1)!);

int _checksum(String value) {
  var sum = 0;
  for (final codeUnit in value.codeUnits) {
    sum = ((sum << 5) - sum + codeUnit).toSigned(32);
  }
  return sum;
}
