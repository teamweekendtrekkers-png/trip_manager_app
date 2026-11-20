import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:trip_manager_app/widgets/app_version_card.dart';
import 'package:trip_manager_app/models/manager_release_notes.dart';

void main() {
  testWidgets('About shows the notes for the installed build', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Trip Manager',
      packageName: 'test.manager',
      version: '1.34.0',
      buildNumber: '42',
      buildSignature: '',
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppVersionCard())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('What’s new'));
    await tester.pumpAndSettle();
    expect(find.text('Version 1.34.0 · Build 42'), findsOneWidget);
    expect(
      find.textContaining(managerReleaseNotes['1.34.0+42']!.first),
      findsOneWidget,
    );
    expect(
      find.textContaining(managerReleaseNotes['1.31.0+39']!.first),
      findsNothing,
    );
  });

  test('the current build has authored release notes', () {
    final manifest = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([^\s#]+)',
      multiLine: true,
    ).firstMatch(manifest)?.group(1);
    expect(version, isNotNull);
    expect(
      managerReleaseNotes[version],
      isNotEmpty,
      reason:
          'Add What’s new notes for $version in manager_release_notes.dart.',
    );
    expect(managerReleaseNotes[version], everyElement(isNotEmpty));
  });
}
