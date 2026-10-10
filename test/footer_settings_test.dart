import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/models/footer_config.dart';
import 'package:trip_manager_app/models/homepage_config.dart';
import 'package:trip_manager_app/services/homepage_settings_service.dart';
import 'package:trip_manager_app/widgets/footer_settings_editor.dart';
import 'homepage_settings_test.dart' as fixtures;

HomepageConfig edit(void Function(Map<String, dynamic>) change) {
  final json = HomepageConfig.initial().toJson();
  change(json['footer'] as Map<String, dynamic>);
  return HomepageConfig.parse(jsonEncode(json));
}

Map<String, dynamic> information(String id) => {
  'id': id,
  'label': 'Travel information',
  'url': 'contact.html',
  'visible': true,
};

void main() {
  test(
    'legacy settings gain footer defaults without changing saved content',
    () {
      final legacy = HomepageConfig.initial().toJson()..remove('footer');
      legacy['hero']['backgroundImage'] = 'images/saved-hero.jpg';
      final before = jsonEncode(legacy);
      final actual = HomepageConfig.parse(before).toJson();
      expect(actual['footer'], FooterConfig.defaults());
      for (final name in ['hero', 'upcomingBatches', 'sections']) {
        expect(actual[name], legacy[name]);
      }
      expect(jsonEncode(legacy), before);
      final copy = FooterConfig.defaults();
      copy['informationLinks'].add(information('copy'));
      expect(FooterConfig.defaults()['informationLinks'], isEmpty);
    },
  );
  test(
    'footer edits and explicit empty overrides roundtrip without payment IDs',
    () {
      final value = edit((f) {
        f['brandName'] = 'Weekend Crew';
        f['showUpi'] = false;
        f['showSocialLinks'] = false;
        f['whatsAppNumber'] = '919876543210';
        f['instagramUrl'] = 'https://www.instagram.com/weekendcrew/';
        f['email'] = 'hello@example.com';
        f['informationLinks'] = [information('first'), information('second')];
        f['informationLinks'][1]['visible'] = false;
      });
      expect(HomepageConfig.parse(value.encode()).toJson(), value.toJson());
      final json = value.toJson();
      for (final key in [
        'whatsAppNumber',
        'instagramUrl',
        'instagramLabel',
        'email',
      ]) {
        json['footer'][key] = '';
      }
      json['footer']['informationLinks'] = [];
      expect(HomepageConfig.parse(jsonEncode(json)).toJson(), json);
      expect(json['footer'].containsKey('upiId'), false);
    },
  );
  test(
    'information URLs only allow essential pages and safe HTTPS destinations',
    () {
      for (final value in [
        'index.html',
        'trips.html',
        'about.html#team',
        'contact.html',
        'https://example.com/policy.pdf',
      ]) {
        expect(FooterConfig.safeLink(value), true, reason: value);
      }
      for (final value in [
        'javascript:alert(1)',
        'data:text/html,hi',
        '//example.com',
        '../private',
        'missing.html',
        'https://user:pass@example.com',
        'https://example.com:443/path',
        'https://example.com/a b',
        'https://example.com/"onclick=x',
        'http://example.com',
      ]) {
        expect(FooterConfig.safeLink(value), false, reason: value);
      }
      for (final value in [
        'https://instagram.com/',
        'https://instagram.com.evil.test/me',
        'https://example.com/me',
      ]) {
        expect(FooterConfig.safeInstagram(value), false, reason: value);
      }
    },
  );
  test(
    'schema drift, invalid contact details and malformed information links block save',
    () {
      for (final change in <void Function(Map<String, dynamic>)>[
        (f) => f['upiId'] = 'unauthorized@bank',
        (f) => f['homeUrl'] = 'other.html',
        (f) => f['showUpi'] = 'false',
        (f) => f['showSocialLinks'] = null,
        (f) => f['brandName'] = '',
        (f) => f['copyright'] = List.filled(2001, 'x').join(),
        (f) => f['location'] = 42,
        (f) => f['whatsAppNumber'] = '+91 1234567890',
        (f) => f['instagramUrl'] = 'https://example.com/me',
        (f) => f['email'] = 'invalid',
        (f) => f['informationLinks'] = [information('x'), information('x')],
        (f) => f['informationLinks'] = [
          {...information('x'), 'extra': true},
        ],
        (f) => f['informationLinks'] = [
          {...information('x'), 'visible': 'true'},
        ],
        (f) => f['informationLinks'] = [
          {...information('x'), 'url': 'javascript:alert(1)'},
        ],
        (f) => f['informationLinks'] = [
          {...information('x'), 'label': ''},
        ],
        (f) =>
            f['informationLinks'] = List.generate(9, (i) => information('$i')),
      ]) {
        expect(() => edit(change), throwsFormatException);
      }
      final json = HomepageConfig.initial().toJson()..['footer'] = [];
      expect(
        () => HomepageConfig.parse(jsonEncode(json)),
        throwsFormatException,
      );
    },
  );
  test(
    'independent footer fields merge; competing branding and link edits conflict',
    () {
      final base = HomepageConfig.initial();
      final local = edit((f) => f['showUpi'] = false);
      final remote = edit((f) => f['location'] = 'Bangalore, India');
      final merged = HomepageSettingsService.merge(
        base,
        local,
        remote,
      ).toJson();
      expect(merged['footer']['showUpi'], false);
      expect(merged['footer']['location'], 'Bangalore, India');
      for (final field in ['brandName', 'informationLinks']) {
        expect(
          () => HomepageSettingsService.merge(
            base,
            edit(
              (f) => f[field] = field == 'brandName'
                  ? 'Local'
                  : [information('local')],
            ),
            edit(
              (f) => f[field] = field == 'brandName'
                  ? 'Remote'
                  : [information('remote')],
            ),
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.toString(),
              'conflict',
              contains('footer.$field'),
            ),
          ),
        );
      }
    },
  );
  test(
    'fake GitHub publishes only homepage JSON and reloads footer independently',
    () async {
      final base = HomepageConfig.initial();
      final github = fixtures.MemoryGitHub([
        fixtures.file(base),
        fixtures.file(base),
      ]);
      final service = HomepageSettingsService(github);
      await service.load();
      final draft = edit((f) {
        f['showUpi'] = false;
        f['informationLinks'] = [information('help')];
      });
      final saved = await service.save(draft);
      expect(saved.success, true);
      expect(github.calls.single.keys, [HomepageSettingsService.path]);
      final published = HomepageConfig.parse(github.calls.single.values.single);
      github.snapshots.add(fixtures.file(published, 'saved'));
      expect((await service.load()).toJson(), draft.toJson());
      for (final key in ['hero', 'sections', 'upcomingBatches']) {
        expect(published.toJson()[key], base.toJson()[key]);
      }
    },
  );

  Future<void> show(WidgetTester tester, String key) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await show(tester, key);
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String key, String value) async {
    await show(tester, key);
    await tester.enterText(find.byKey(ValueKey(key)), value);
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets(
      'footer editing, visibility, fixed labels and information management ${dark ? 'dark' : 'light'}',
      (tester) async {
        if (!Platform.isAndroid) {
          tester.view.physicalSize = const Size(411, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
        }
        final footer = FooterConfig.defaults();
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => SingleChildScrollView(
                  child: FooterSettingsEditor(
                    footer: footer,
                    onChanged: () => setState(() {}),
                  ),
                ),
              ),
            ),
          ),
        );
        await tap(tester, 'website-footer-editor');
        await tap(tester, 'footer-showUpi');
        expect(footer['showUpi'], false);
        if (!Platform.isAndroid) {
          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile('goldens/footer_${dark ? 'dark' : 'light'}.png'),
          );
        }
        for (final entry in {
          'brandName': 'Weekend Crew',
          'description': 'Travel together',
          'location': 'Bangalore, India',
          'homeLabel': 'Start here',
          'whatsAppNumber': '919876543210',
          'instagramUrl': 'https://instagram.com/weekendcrew',
          'email': 'hello@example.com',
          'upiTitle': 'Pay securely',
          'copyright': '© {year} {brand}',
        }.entries) {
          await fill(tester, 'footer-${entry.key}', entry.value);
          expect(footer[entry.key], entry.value);
        }
        await tap(tester, 'footer-showSocialLinks');
        expect(footer['showSocialLinks'], false);
        await tap(tester, 'footer-add-link');
        final links = footer['informationLinks'] as List;
        final first = links.single['id'];
        await fill(tester, 'footer-link-$first-label', 'Travel policies');
        await fill(
          tester,
          'footer-link-$first-url',
          'https://example.com/policies.pdf',
        );
        await tap(tester, 'footer-add-link');
        await tap(tester, 'footer-link-$first-down');
        expect(links.last['id'], first);
        await tap(tester, 'footer-link-$first-up');
        expect(links.first['id'], first);
        await tap(tester, 'footer-link-$first-visible');
        expect(links.first['visible'], false);
        await tap(tester, 'footer-link-$first-remove');
        expect(links, hasLength(1));
        await fill(tester, 'footer-whatsAppNumber', '');
        await fill(tester, 'footer-instagramUrl', '');
        FooterConfig.validate(footer);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
