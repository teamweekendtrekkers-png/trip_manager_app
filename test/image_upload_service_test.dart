import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/services/image_upload_service.dart';

void main() {
  test('main image upload never edits trips-data.js', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.github.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (options.method == 'GET') {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: 404,
                ),
              ),
            );
            return;
          }
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 201,
              data: const <String, dynamic>{},
            ),
          );
        },
      ),
    );
    final file = File(
      '${Directory.systemTemp.path}/trip-manager-image-${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(<int>[1, 2, 3]);
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });

    final result = await ImageUploadService(
      settings: AppSettings(
        githubToken: 'test',
        repositoryOwner: 'owner',
        repositoryName: 'repo',
        branch: 'main',
      ),
      dio: dio,
    ).uploadImage(imageFile: file, tripId: 'alpha', isMainImage: true);

    expect(result.success, isTrue, reason: result.error);
    expect(result.imagePath, startsWith('images/trips/alpha_'));
    expect(requests, hasLength(2));
    expect(
      requests.where((request) => request.path.contains('trips-data.js')),
      isEmpty,
    );
    expect(requests.where((request) => request.method == 'PUT'), hasLength(1));
  });
}
