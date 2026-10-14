import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:trip_manager_app/services/draft_store.dart';
import 'package:trip_manager_app/services/trip_editor_document.dart';
import 'package:trip_manager_app/widgets/local_draft.dart';
import 'package:trip_manager_app/widgets/app_version_card.dart';

class DraftHarness extends StatefulWidget {
  const DraftHarness({super.key});
  @override
  State<DraftHarness> createState() => DraftHarnessState();
}

class DraftHarnessState extends State<DraftHarness>
    with LocalDraft<DraftHarness> {
  Map<String, dynamic> value = {'title': 'Published'};
  @override
  String get localScope => 'convenience-test';
  @override
  String get localSlot => 'trip:a';
  @override
  Map<String, dynamic> get currentDocument => value;
  @override
  void applyDocument(Map<String, dynamic> document) => value = document;
  @override
  void initState() {
    super.initState();
    startLocalDraft({'title': 'Published'});
  }

  void edit(String title) => setState(() => value = {'title': title});
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: SingleChildScrollView(child: localDraftBar()));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    await Hive.openBox<String>('manager_drafts_v1', bytes: Uint8List(0));
    await DraftStore.init();
  });
  tearDown(() async {
    await DraftStore.close();
  });

  test(
    'restoring older trips keeps editor defaults and unknown published fields',
    () {
      final original = <String, dynamic>{
        'id': 'older-trip',
        'name': 'Original title',
        'destination': 'Coorg',
        'description': 'Original description',
        'custom': {'keep': true},
      };
      final restored = publishedTripEditorDocument(original);
      expect(restored['publicSlug'], 'older-trip');
      expect(
        restored['departureTime'],
        matches(RegExp(r'^([01]\d|2[0-3]):[0-5]\d$')),
      );
      expect(restored['title'], 'Original title');
      expect(restored['location'], 'Coorg');
      expect(restored['about'], 'Original description');
      expect(restored['custom'], {'keep': true});
      expect(original.containsKey('departureTime'), false);
      expect(
        publishedTripEditorDocument({
          ...original,
          'publicSlug': 'custom-route',
          'departureTime': '22:30',
        })['departureTime'],
        '22:30',
      );
    },
  );

  for (final scenario in ['newer', 'current', 'expired', 'offline']) {
    testWidgets('update check reports $scenario build honestly', (
      tester,
    ) async {
      PackageInfo.setMockInitialValues(
        appName: 'Trip Manager',
        packageName: 'test.manager',
        version: '1.7.0',
        buildNumber: '8',
        buildSignature: '',
      );
      final client = Dio();
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            expect(request.headers.containsKey('Authorization'), false);
            if (scenario == 'offline') {
              handler.reject(
                DioException(
                  requestOptions: request,
                  type: DioExceptionType.connectionError,
                ),
              );
              return;
            }
            Object data;
            if (request.path.endsWith('/runs')) {
              expect(request.queryParameters['status'], 'success');
              expect(request.queryParameters['event'], 'push');
              data = {
                'workflow_runs': [
                  {'id': 42, 'head_sha': 'a' * 40},
                ],
              };
            } else if (request.path.endsWith('/artifacts')) {
              data = {
                'artifacts': [
                  {
                    'name': 'trip-manager-windows-x64',
                    'expired': scenario == 'expired',
                  },
                ],
              };
            } else {
              expect(request.path, contains('/${'a' * 40}/pubspec.yaml'));
              data =
                  'version: ${scenario == 'newer' ? '1.8.0+9' : '1.7.0+8'}\n';
            }
            handler.resolve(
              Response(requestOptions: request, data: data, statusCode: 200),
            );
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          home: Scaffold(body: AppVersionCard(updateClient: client)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();
      final expected = switch (scenario) {
        'newer' => 'Update available:',
        'current' => 'You’re up to date',
        'expired' => 'download is unavailable',
        _ => 'Could not check for updates',
      };
      expect(find.textContaining(expected), findsOneWidget);
      client.close();
    });
  }

  test(
    'release comparison handles build numbers, major changes and malformed tags',
    () {
      expect(compareManagerVersions('v1.7.0+9', '1.7.0+8'), greaterThan(0));
      expect(compareManagerVersions('v1.7.0+8', '1.7.0+8'), 0);
      expect(compareManagerVersions('v2.0.0', '1.9.9+99'), greaterThan(0));
      expect(compareManagerVersions('1.6.0+7', '1.7.0+8'), lessThan(0));
      expect(compareManagerVersions('v1.7.0-beta', '1.7.0+8'), isNull);
      expect(compareManagerVersions('unknown', '1.7.0+8'), isNull);
    },
  );

  testWidgets(
    'version comes from the installed package and exposes what is new',
    (tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'Trip Manager',
        packageName: 'test.manager',
        version: '1.7.0',
        buildNumber: '8',
        buildSignature: '',
      );
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppVersionCard())),
      );
      await tester.pumpAndSettle();
      expect(find.text('v1.7.0 · Build 8'), findsOneWidget);
      await tester.tap(find.text('What’s new'));
      await tester.pumpAndSettle();
      expect(find.text('Copy app details'), findsOneWidget);
    },
  );

  testWidgets(
    'cancel keeps edits; discard restores last local save even if autosave fires during confirmation',
    (tester) async {
      await tester.runAsync(() async {
        final key = GlobalKey<DraftHarnessState>();
        await tester.pumpWidget(MaterialApp(home: DraftHarness(key: key)));
        key.currentState!.edit('Saved draft');
        await key.currentState!.saveLocalDraft();
        await tester.pump();
        key.currentState!.edit('New edits');
        await tester.pump();
        await tester.tap(find.text('Discard changes'));
        await tester.pump();
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();
        expect(key.currentState!.value['title'], 'New edits');
        await key.currentState!.saveLocalDraft();
        key.currentState!.edit('Latest edits');
        await tester.pump();
        final discard = key.currentState!.discardEditorChanges();
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Discard changes'));
        await discard;
        await tester.pumpAndSettle();
        expect(key.currentState!.value['title'], 'New edits');
        expect(
          (DraftStore.read('convenience-test', 'trip:a')!['data']['draft']
              as Map)['title'],
          'New edits',
        );
        await tester.pumpWidget(const SizedBox());
      });
    },
  );

  testWidgets(
    'autosave retains the explicit save checkpoint across reopening',
    (tester) async {
      await tester.runAsync(() async {
        final first = GlobalKey<DraftHarnessState>();
        await tester.pumpWidget(MaterialApp(home: DraftHarness(key: first)));
        first.currentState!.edit('Explicit save');
        await first.currentState!.saveLocalDraft();
        first.currentState!.edit('Recovered edits');
        await first.currentState!.saveLocalDraft(checkpoint: false);
        await tester.pumpWidget(const SizedBox());
        final reopened = GlobalKey<DraftHarnessState>();
        await tester.pumpWidget(MaterialApp(home: DraftHarness(key: reopened)));
        expect(reopened.currentState!.value['title'], 'Recovered edits');
        await reopened.currentState!.discardEditorChanges(confirm: false);
        expect(reopened.currentState!.value['title'], 'Explicit save');
        await tester.pumpWidget(const SizedBox());
      });
    },
  );

  testWidgets(
    'delete draft restores original and removes only this draft, including on disposal',
    (tester) async {
      await tester.runAsync(() async {
        await DraftStore.write('convenience-test', 'trip:b', {'keep': true});
        final key = GlobalKey<DraftHarnessState>();
        await tester.pumpWidget(MaterialApp(home: DraftHarness(key: key)));
        key.currentState!.edit('Saved draft');
        await key.currentState!.saveLocalDraft();
        await tester.pump();
        final deletion = key.currentState!.discardEditorChanges(
          deleteDraft: true,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(FilledButton, 'Delete saved draft'),
        );
        await deletion;
        await tester.pumpAndSettle();
        expect(key.currentState!.value['title'], 'Published');
        expect(key.currentState!.hasLocalEdits, false);
        expect(DraftStore.read('convenience-test', 'trip:a'), isNull);
        expect(DraftStore.read('convenience-test', 'trip:b'), isNotNull);
        await tester.pumpWidget(const SizedBox());
        expect(DraftStore.read('convenience-test', 'trip:a'), isNull);
      });
    },
  );
}
