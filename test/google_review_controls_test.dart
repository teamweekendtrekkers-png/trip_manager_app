import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/homepage_config.dart';
import '../lib/widgets/google_review_controls.dart';

void main() {
  test(
    'review mode validates, preserves selections and keeps legacy manual documents compatible',
    () {
      final original = HomepageConfig.initial();
      final data = original.toJson();
      expect(
        jsonDecode(
          original.encode(),
        )['sections']['reviews'].containsKey('source'),
        isFalse,
      );
      data['sections']['reviews']['source'] = 'google';
      final automatic = HomepageConfig.parse(jsonEncode(data));
      expect(
        jsonDecode(automatic.encode())['sections']['reviews']['source'],
        'google',
      );
      expect(
        automatic.toJson()['sections']['reviews']['items'],
        original.toJson()['sections']['reviews']['items'],
      );
      data['sections']['reviews']['source'] = 'unknown';
      expect(
        () => HomepageConfig.parse(jsonEncode(data)),
        throwsFormatException,
      );
    },
  );
  testWidgets(
    'manual selection remains available when Google setup is incomplete on a phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final section = {
        'source': 'manual',
        'items': [
          {'id': 'kept', 'visible': false},
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => GoogleReviewControls(
                  section: section,
                  onChanged: () => setState(() {}),
                  loadFeed: () async => {'connected': false},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Automatic five-star reviews').last);
      await tester.pumpAndSettle();
      expect(section['source'], 'google');
      expect((section['items'] as List).single, {
        'id': 'kept',
        'visible': false,
      });
      await tester.tap(find.text('Check Google connection'));
      await tester.pumpAndSettle();
      expect(find.textContaining('not connected yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
