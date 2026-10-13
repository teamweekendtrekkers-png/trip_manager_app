import 'golden_platform.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/models/homepage_config.dart';
import 'package:trip_manager_app/models/homepage_section_defaults.dart';
import 'package:trip_manager_app/models/homepage_sections.dart';
import 'package:trip_manager_app/services/homepage_settings_service.dart';
import 'package:trip_manager_app/widgets/homepage_sections_editor.dart';

HomepageConfig edited(void Function(Map<String, dynamic>) edit) {
  final json = HomepageConfig.initial().toJson();
  edit(json['sections'] as Map<String, dynamic>);
  return HomepageConfig.parse(jsonEncode(json));
}

void main() {
  test(
    'legacy JSON gains defaults without changing hero, dates or existing input',
    () {
      final raw = Map<String, dynamic>.from(HomepageConfig.defaults);
      final before = jsonEncode(raw);
      final result = HomepageConfig.parse(before).toJson();
      expect(result['sections'], homepageSectionDefaults());
      expect(result['sections']['reviews']['items'], hasLength(6));
      expect(result['hero'], raw['hero']);
      expect(result['upcomingBatches'], raw['upcomingBatches']);
      expect(jsonEncode(raw), before);
      result['sections']['reviews']['items'].clear();
      expect(
        HomepageConfig.initial().toJson()['sections']['reviews']['items'],
        hasLength(6),
      );
    },
  );
  test(
    'roundtrip preserves selection, ordering, content, optional URLs and explicit empty lists',
    () {
      final config = edited((sections) {
        final reviews = sections['reviews'] as Map;
        reviews['items'] = (reviews['items'] as List).reversed.toList();
        reviews['items'][0]['visible'] = false;
        reviews['items'][1]['text'] = '<script>plain text only</script> 🏕️';
        reviews['items'][1]['googleMapsUrl'] =
            'https://maps.app.goo.gl/individual';
        reviews['googleMapsUrl'] = 'https://g.page/r/business/review';
        sections['stats']['items'] = [];
        sections['whyUs']['enabled'] = false;
        sections['cta']['title'] = 'Your next journey';
      });
      expect(HomepageConfig.parse(config.encode()).toJson(), config.toJson());
      expect(
        config.toJson()['sections']['reviews']['items'][0]['id'],
        'review-6',
      );
      expect(config.toJson()['sections']['stats']['items'], isEmpty);
    },
  );
  test(
    'unknown fields, malformed types, duplicate IDs and invalid ranges block publication',
    () {
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (s) => s['other'] = {},
        (s) => s['reviews']['unexpected'] = true,
        (s) => s['stats']['enabled'] = 'true',
        (s) => s['reviews']['items'] = 'bad',
        (s) => s['reviews']['items'][0]['unknown'] = 'new',
        (s) => s['reviews']['items'][0].remove('text'),
        (s) => s['reviews']['items'][1]['id'] = 'review-1',
        (s) => s['reviews']['items'][0]['id'] = '../unsafe',
        (s) => s['reviews']['items'][0]['visible'] = 1,
        (s) => s['reviews']['items'][0]['name'] = '',
        (s) => s['reviews']['items'][0]['rating'] = 0,
        (s) => s['reviews']['items'][0]['rating'] = 6,
        (s) => s['reviews']['items'][0]['rating'] = '5',
        (s) => s['reviews']['rating'] = 'NaN',
        (s) => s['reviews']['rating'] = '5.1',
        (s) => s['reviews']['intervalSeconds'] = 3,
        (s) => s['reviews']['intervalSeconds'] = 31,
        (s) => s['reviews']['autoPlay'] = 1,
        (s) => s['reviews']['items'] = List.generate(
          31,
          (i) => {...s['reviews']['items'][0] as Map, 'id': 'r$i'},
        ),
        (s) => s['stats']['items'] = List.generate(
          9,
          (i) => {...s['stats']['items'][0] as Map, 'id': 's$i'},
        ),
      ]) {
        expect(() => edited(mutate), throwsFormatException);
      }
    },
  );
  test('Google review links use a strict HTTPS host allowlist', () {
    for (final value in [
      'https://maps.app.goo.gl/abc',
      'https://www.google.com/maps/reviews/data=x',
      'https://maps.google.com/?cid=123',
      'https://goo.gl/maps/abc',
      'https://g.page/r/abc/review',
      'https://www.google.co.in/maps/place/abc',
    ]) {
      expect(HomepageSections.safeGoogleMapsUrl(value), isTrue, reason: value);
    }
    for (final value in [
      'javascript:alert(1)',
      'http://maps.app.goo.gl/x',
      'https://maps.app.goo.gl.evil.test/x',
      'https://user@maps.app.goo.gl/x',
      'https://example.com/maps',
      'https://google.com/search?q=maps',
      'https://maps.app.goo.gl/',
      'https://maps.app.goo.gl:8443/x',
      'https://maps.app.goo.gl/x\\evil',
      'https://maps.app.goo.gl/x\ny',
    ]) {
      expect(HomepageSections.safeGoogleMapsUrl(value), isFalse, reason: value);
      expect(
        () => edited((s) => s['reviews']['googleMapsUrl'] = value),
        throwsFormatException,
      );
      expect(
        () => edited((s) => s['reviews']['items'][0]['googleMapsUrl'] = value),
        throwsFormatException,
      );
    }
  });
  test(
    'photos reject script/data URLs while blank optional photos/dates/links remain valid',
    () {
      for (final url in [
        'javascript:alert(1)',
        'data:image/png,x',
        'http://example.com/x',
        'https://user:pass@example.com/x',
        'https://example.com/\nx',
      ]) {
        expect(
          () => edited((s) => s['reviews']['items'][0]['photo'] = url),
          throwsFormatException,
        );
      }
      edited((s) {
        s['reviews']['items'][0]['photo'] = '';
        s['reviews']['items'][0]['date'] = '';
      });
    },
  );
  test(
    'three-way publication preserves unrelated sections and blocks simultaneous review-list changes',
    () {
      final base = HomepageConfig.initial();
      final local = edited((s) => s['reviews']['items'][0]['visible'] = false);
      final remote = edited((s) => s['stats']['items'][0]['value'] = '800+');
      final merged = HomepageSettingsService.merge(
        base,
        local,
        remote,
      ).toJson()['sections'];
      expect(merged['reviews']['items'][0]['visible'], false);
      expect(merged['stats']['items'][0]['value'], '800+');
      expect(
        () => HomepageSettingsService.merge(
          base,
          local,
          edited((s) => s['reviews']['items'].removeAt(0)),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.toString(),
            'conflict path',
            contains('sections.reviews.items'),
          ),
        ),
      );
    },
  );

  Future<Map<String, dynamic>> open(
    WidgetTester tester, {
    bool dark = false,
  }) async {
    if (!Platform.isAndroid) {
      tester.view.physicalSize = const Size(411, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    final sections = homepageSectionDefaults();
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? ThemeData.dark() : ThemeData.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: HomepageSectionsEditor(
                sections: sections,
                onChanged: () => setState(() {}),
              ),
            ),
          ),
        ),
      ),
    );
    return sections;
  }

  Future<void> tap(WidgetTester tester, String key) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final finder = find.byKey(
      key.startsWith('details-') ? PageStorageKey(key) : ValueKey(key),
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets(
      'review selection, edit, move, add/remove and slider settings in ${dark ? "dark" : "light"} mode',
      (tester) async {
        final sections = await open(tester, dark: dark);
        await tap(tester, 'homepage-section-reviews');
        await tap(tester, 'details-section-reviews-review-1');
        if (!Platform.isAndroid) {
          await expectLater(
            find.byType(Scaffold),
            platformGolden(
              'goldens/homepage_reviews_${dark ? "dark" : "light"}.png',
            ),
          );
        }
        await tap(tester, 'section-reviews-review-1-visible');
        expect(sections['reviews']['items'][0]['visible'], false);
        await tester.enterText(
          find.byKey(const ValueKey('section-reviews-review-1-name')),
          'Edited reviewer',
        );
        // Flush the input edit's UI updates before inspecting the draft.
        await tester.pumpAndSettle();
        expect(sections['reviews']['items'][0]['name'], 'Edited reviewer');
        await tap(tester, 'section-reviews-review-1-down');
        expect(sections['reviews']['items'][1]['id'], 'review-1');
        await tap(tester, 'section-reviews-review-1-up');
        expect(sections['reviews']['items'][0]['id'], 'review-1');
        await tap(tester, 'section-reviews-autoPlay');
        expect(sections['reviews']['autoPlay'], false);
        await tap(tester, 'section-reviews-add');
        expect(sections['reviews']['items'], hasLength(7));
        final id = sections['reviews']['items'].last['id'];
        await tap(tester, 'details-section-reviews-$id');
        await tap(tester, 'section-reviews-$id-remove');
        expect(sections['reviews']['items'], hasLength(6));
        HomepageConfig.parse(
          jsonEncode({...HomepageConfig.defaults, 'sections': sections}),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('all screenshot sections expose editable text and visibility', (
    tester,
  ) async {
    final sections = await open(tester);
    for (final name in ['stats', 'howItWorks', 'whyChooseUs', 'cta']) {
      await tap(tester, 'homepage-section-$name');
      await tap(tester, 'section-$name-enabled');
      expect(sections[name]['enabled'], false);
    }
    await tester.enterText(
      find.byKey(const ValueKey('section-cta-title')),
      'Adventure awaits',
    );
    expect(sections['cta']['title'], 'Adventure awaits');
    await tap(tester, 'details-section-stats-trips');
    await tester.enterText(
      find.byKey(const ValueKey('section-stats-trips-value')),
      '999+',
    );
    expect(sections['stats']['items'][0]['value'], '999+');
    await tap(tester, 'details-section-whyChooseUs-pricing');
    await tester.enterText(
      find.byKey(const ValueKey('section-whyChooseUs-pricing-text')),
      'Our custom promise',
    );
    expect(sections['whyChooseUs']['items'][0]['text'], 'Our custom promise');
  });
}
