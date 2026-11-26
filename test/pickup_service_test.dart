import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trip_manager_app/services/pickup_service.dart';
import 'package:trip_manager_app/screens/pickup_manifest_screen.dart';

http.Response reply(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  testWidgets('shows the selected departure and submitted traveller details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PickupManifestScreen(
          initialDeparture: 'closed-trip',
          service: _FixturePickupService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Closed trek'), findsOneWidget);
    expect(find.text('3 travellers checked in'), findsOneWidget);
    expect(find.text('Fixture traveller · 3 travelling'), findsOneWidget);
    expect(find.text('9000000001'), findsOneWidget);
    expect(find.byTooltip('Call Fixture traveller'), findsOneWidget);
  });
  test(
    'signs in separately and loads the selected departure’s private list',
    () async {
      final service = PickupService(
        client: MockClient((request) async {
          if (request.url.path == '/pickup/config.json') {
            return reply({
              'url': 'https://rllukahyjluwcsttpcdl.supabase.co',
              'key': 'sb_publishable_test',
            });
          }
          expect(request.url.host, 'rllukahyjluwcsttpcdl.supabase.co');
          if (request.url.path == '/auth/v1/token') {
            expect(jsonDecode(request.body)['email'], 'organizer@example.test');
            return reply({
              'access_token': 'fixture-token',
              'refresh_token': 'fixture-refresh',
              'expires_in': 3600,
              'user': {
                'app_metadata': {'pickup_captain': true},
              },
            });
          }
          expect(request.headers['authorization'], 'Bearer fixture-token');
          if (request.url.path == '/rest/v1/pickup_departures') {
            return reply([
              {
                'slug': 'closed-trip',
                'title': 'Closed trek',
                'departure_date': '2026-11-23',
                'open': false,
              },
            ]);
          }
          if (request.url.path == '/auth/v1/logout') return reply({});
          expect(request.url.path, '/rest/v1/pickup_checkins');
          expect(request.url.queryParameters['departure'], 'eq.closed-trip');
          expect(request.url.queryParameters['updated_at'], 'not.is.null');
          return reply([
            {
              'lead_name': 'Fixture traveller',
              'phone': '9000000001',
              'party_size': 3,
              'stop': 'fixture',
            },
          ]);
        }),
      );
      await expectLater(service.checkIns('closed-trip'), throwsStateError);
      await service.signIn('organizer@example.test', 'fixture-password');
      expect((await service.departures()).single.open, isFalse);
      expect((await service.checkIns('closed-trip')).single['party_size'], 3);
      await service.signOut();
      expect(service.signedIn, isFalse);
      await expectLater(service.checkIns('closed-trip'), throwsStateError);
    },
  );
}

class _FixturePickupService extends PickupService {
  @override
  bool get signedIn => true;

  @override
  Future<List<PickupDeparture>> departures() async => [
    (
      slug: 'closed-trip',
      title: 'Closed trek',
      date: '2026-11-23',
      open: false,
    ),
    (slug: 'other-trip', title: 'Other trek', date: '2026-11-30', open: true),
  ];

  @override
  Future<List<Map<String, dynamic>>> stops(String slug) async => [
    if (slug == 'closed-trip')
      {'id': 'fixture', 'name': 'Majestic', 'pickup_time': '9 PM'},
  ];

  @override
  Future<List<Map<String, dynamic>>> checkIns(String slug) async => [
    if (slug == 'closed-trip')
      {
        'lead_name': 'Fixture traveller',
        'phone': '9000000001',
        'party_size': 3,
        'stop': 'fixture',
      },
  ];
}
