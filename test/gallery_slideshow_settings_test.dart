import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/models/homepage_config.dart';

void main() {
  test('older website settings receive gallery defaults', () {
    final data = HomepageConfig.initial().toJson()..remove('tripGallery');
    expect(HomepageConfig.parse(jsonEncode(data)).toJson()['tripGallery'],
        {'autoSlide': true, 'intervalSeconds': 5});
  });
  test('gallery on/off and timing survive publishing serialization', () {
    for (final seconds in [3, 7, 30]) {
      final data = HomepageConfig.initial().toJson();
      data['tripGallery'] = {'autoSlide': false, 'intervalSeconds': seconds};
      final saved = HomepageConfig.parse(jsonEncode(data));
      expect(HomepageConfig.parse(saved.encode()).toJson()['tripGallery'],
          data['tripGallery']);
    }
  });
  test('gallery rejects invalid timing and visibility values', () {
    for (final value in [2, 31, 4.5, '5', null]) {
      final data = HomepageConfig.initial().toJson();
      data['tripGallery']['intervalSeconds'] = value;
      expect(() => HomepageConfig.parse(jsonEncode(data)),
          throwsFormatException);
    }
    final data = HomepageConfig.initial().toJson();
    data['tripGallery']['autoSlide'] = 'true';
    expect(() => HomepageConfig.parse(jsonEncode(data)), throwsFormatException);
  });
}
