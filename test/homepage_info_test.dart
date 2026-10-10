import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/models/homepage_config.dart';
import 'package:trip_manager_app/services/homepage_settings_service.dart';
import 'package:trip_manager_app/widgets/homepage_sections_editor.dart';
import 'homepage_settings_test.dart' as fixtures;

const sectionNames = ['howItWorks', 'whyChooseUs'];
HomepageConfig edit(void Function(Map<String, dynamic>) change) {
  final json = HomepageConfig.initial().toJson();
  change(json['sections'] as Map<String, dynamic>);
  return HomepageConfig.parse(jsonEncode(json));
}

void main() {
  test(
    'old homepage settings gain new sections without losing legacy content',
    () {
      final json = HomepageConfig.initial().toJson();
      final sections = json['sections'] as Map;
      for (final name in sectionNames) {
        sections.remove(name);
      }
      sections['whyUs']['title'] = 'My saved heading';
      sections['whyUs']['items'][0]['text'] = 'My saved reason';
      json['hero']['backgroundImage'] = 'images/custom-hero.jpg';
      final before = jsonEncode(json);
      final actual = HomepageConfig.parse(before).toJson();
      expect(jsonEncode(json), before);
      expect(actual['sections']['whyUs'], sections['whyUs']);
      expect(actual['hero'], json['hero']);
      expect(actual['upcomingBatches'], json['upcomingBatches']);
      expect(actual['sections']['reviews'], sections['reviews']);
      for (final name in sectionNames) {
        expect(actual['sections'][name]['items'], hasLength(3));
      }
    },
  );
  test(
    'legacy hidden visibility is inherited until a replacement is configured',
    () {
      final json = HomepageConfig.initial().toJson();
      json['sections']['whyUs']['enabled'] = false;
      for (final name in sectionNames) {
        json['sections'].remove(name);
      }
      var actual = HomepageConfig.parse(jsonEncode(json)).toJson();
      for (final name in sectionNames) {
        expect(actual['sections'][name]['enabled'], false);
      }
      json['sections']['howItWorks'] = {'enabled': true};
      actual = HomepageConfig.parse(jsonEncode(json)).toJson();
      expect(actual['sections']['howItWorks']['enabled'], true);
      expect(actual['sections']['whyChooseUs']['enabled'], false);
    },
  );
  test(
    'new sections roundtrip edits, ordering, visibility, empty lists and optional text',
    () {
      final config = edit((s) {
        s['howItWorks']['title'] = 'Plan your weekend';
        s['howItWorks']['eyebrow'] = '';
        s['howItWorks']['subtitle'] = '';
        s['howItWorks']['items'] = (s['howItWorks']['items'] as List).reversed
            .toList();
        s['howItWorks']['items'][0]['visible'] = false;
        s['whyChooseUs']['items'][0]['value'] = '₹0';
        s['whyChooseUs']['items'][0]['accent'] = 'green';
        s['whyChooseUs']['items'][1]['value'] = '';
      });
      expect(HomepageConfig.parse(config.encode()).toJson(), config.toJson());
      for (final name in sectionNames) {
        expect(
          edit(
            (s) => s[name]['items'] = [],
          ).toJson()['sections'][name]['items'],
          isEmpty,
        );
      }
    },
  );
  for (final name in sectionNames) {
    test(
      '$name blocks schema drift, malformed fields, duplicates and unsafe colours',
      () {
        for (final mutate in <void Function(Map<String, dynamic>)>[
          (s) => s[name]['extra'] = 'unsupported',
          (s) => s[name]['enabled'] = 1,
          (s) => s[name]['title'] = '',
          (s) => s[name]['subtitle'] = null,
          (s) => s[name]['items'][0]['accent'] = 'red injected-class',
          (s) => s[name]['items'][0].remove('title'),
          (s) => s[name]['items'][0]['newField'] = true,
          (s) => s[name]['items'][1]['id'] = s[name]['items'][0]['id'],
          (s) => s[name]['items'] = List.generate(
            9,
            (i) => {...s[name]['items'][0] as Map, 'id': '$i'},
          ),
        ]) {
          expect(() => edit(mutate), throwsFormatException);
        }
      },
    );
  }
  test(
    'independent new-section edits merge; simultaneous card-list edits report exact conflicts',
    () {
      final base = HomepageConfig.initial();
      final local = edit(
        (s) => s['howItWorks']['items'][0]['title'] = 'Choose your trip',
      );
      final remote = edit((s) => s['whyChooseUs']['title'] = 'Our promise');
      final merged = HomepageSettingsService.merge(
        base,
        local,
        remote,
      ).toJson()['sections'];
      expect(merged['howItWorks']['items'][0]['title'], 'Choose your trip');
      expect(merged['whyChooseUs']['title'], 'Our promise');
      expect(
        () => HomepageSettingsService.merge(
          base,
          local,
          edit((s) => s['howItWorks']['items'].removeAt(0)),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.toString(),
            'conflict',
            contains('sections.howItWorks.items'),
          ),
        ),
      );
    },
  );
  test(
    'fake GitHub publication writes only homepage JSON, reloads both sections and preserves archived content',
    () async {
      final legacy = HomepageConfig.initial().toJson();
      for (final name in sectionNames) {
        legacy['sections'].remove(name);
      }
      legacy['sections']['whyUs']['title'] = 'Preserve this old heading';
      final base = HomepageConfig.parse(jsonEncode(legacy));
      final github = fixtures.MemoryGitHub([
        fixtures.file(base),
        fixtures.file(base),
      ]);
      final service = HomepageSettingsService(github);
      final draft = (await service.load()).toJson();
      draft['sections']['howItWorks']['items'][0]['title'] =
          'Choose a departure';
      draft['sections']['whyChooseUs']['items'][0]['value'] = '₹0';
      final result = await service.save(
        HomepageConfig.parse(jsonEncode(draft)),
      );
      expect(result.success, true);
      expect(github.calls.single.keys, [HomepageSettingsService.path]);
      final published = HomepageConfig.parse(github.calls.single.values.single);
      github.snapshots.add(fixtures.file(published, 'saved'));
      final reloaded = (await service.load()).toJson();
      expect(reloaded, draft);
      expect(
        reloaded['sections']['whyUs']['title'],
        'Preserve this old heading',
      );
    },
  );

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

  Future<void> fill(WidgetTester tester, String key, String value) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.enterText(finder, value);
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    for (final name in sectionNames) {
      testWidgets(
        '$name supports editing, colours, ordering, selection and add/remove in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
          if (!Platform.isAndroid) {
            tester.view.physicalSize = const Size(411, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
          }
          final sections =
              HomepageConfig.initial().toJson()['sections']
                  as Map<String, dynamic>;
          final archived = jsonEncode(sections['whyUs']);
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
          expect(find.text('Why Travel With Us'), findsNothing);
          await tap(tester, 'homepage-section-$name');
          final id = sections[name]['items'][0]['id'];
          await tap(tester, 'details-section-$name-$id');
          if (!Platform.isAndroid) {
            await expectLater(
              find.byType(Scaffold),
              matchesGoldenFile(
                'goldens/homepage_${name}_${dark ? 'dark' : 'light'}.png',
              ),
            );
          }
          await fill(tester, 'section-$name-$id-icon', '✨');
          await fill(tester, 'section-$name-$id-title', 'Our custom heading');
          await fill(tester, 'section-$name-$id-text', 'Our custom details');
          if (name == 'whyChooseUs') {
            await fill(tester, 'section-$name-$id-value', '₹0');
          }
          await tap(tester, 'section-$name-$id-accent');
          await tester.tap(find.text('Green').last);
          await tester.pumpAndSettle();
          expect(sections[name]['items'][0]['accent'], 'green');
          expect(sections[name]['items'][0]['title'], 'Our custom heading');
          expect(sections[name]['items'][0]['text'], 'Our custom details');
          await tap(tester, 'section-$name-$id-visible');
          expect(sections[name]['items'][0]['visible'], false);
          await tap(tester, 'section-$name-$id-down');
          expect(sections[name]['items'][1]['id'], id);
          await tap(tester, 'section-$name-$id-up');
          expect(sections[name]['items'][0]['id'], id);
          await tap(tester, 'section-$name-add');
          expect(sections[name]['items'], hasLength(4));
          final added = sections[name]['items'].last['id'];
          await tap(tester, 'details-section-$name-$added');
          await tap(tester, 'section-$name-$added-remove');
          expect(sections[name]['items'], hasLength(3));
          await fill(tester, 'section-$name-title', 'Our section heading');
          await fill(tester, 'section-$name-eyebrow', '');
          await fill(tester, 'section-$name-subtitle', 'Our supporting text');
          await tap(tester, 'section-$name-enabled');
          expect(sections[name]['enabled'], false);
          expect(jsonEncode(sections['whyUs']), archived);
          HomepageConfig.parse(
            jsonEncode({...HomepageConfig.defaults, 'sections': sections}),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
