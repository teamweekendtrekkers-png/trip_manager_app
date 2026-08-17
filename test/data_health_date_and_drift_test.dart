import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/providers/trips_provider.dart';
import 'package:trip_manager_app/screens/data_health_screen.dart';
import 'package:trip_manager_app/services/github_service.dart';
import 'package:trip_manager_app/services/trips_parser.dart';

void main() {
  Map<String, dynamic> validTrip({
    String id = 'misty-hills',
    List<dynamic> availableDates = const <dynamic>[],
    bool featured = false,
  }) {
    return <String, dynamic>{
      'id': id,
      'title': 'Misty Hills Trek',
      'location': 'Western Ghats',
      'price': '₹999',
      'image': 'images/trips/misty-hills.jpg',
      'featured': featured,
      'isActive': true,
      'availableDates': availableDates,
      'highlights': <String>['Sunrise views'],
      'itinerary': <Map<String, dynamic>>[
        <String, dynamic>{
          'day': 'Day 1',
          'title': 'Trek',
          'activities': <String>['Walk to the summit'],
        },
      ],
      'inclusions': <String>['Transport'],
      'exclusions': <String>['Personal expenses'],
    };
  }

  Widget buildSubject(TripsProvider provider) {
    return ChangeNotifierProvider<TripsProvider>.value(
      value: provider,
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const DataHealthScreen(),
      ),
    );
  }

  testWidgets('uses exact parsing and reports canonical duplicate ranges', (
    tester,
  ) async {
    final provider = TripsProvider(AppSettings());
    provider.addTrip(
      validTrip(
        availableDates: <dynamic>[
          'Aug 14–16, 2026',
          'Aug 14-16, 2026',
          'Dec 27-29.2026',
          'not a date',
          123,
        ],
      ),
    );

    await tester.pumpWidget(buildSubject(provider));
    await tester.pumpAndSettle();

    expect(find.text('Duplicate Date Range'), findsOneWidget);
    expect(find.text('Invalid Trip Date'), findsNWidgets(2));
    expect(find.textContaining('Aug 14-16, 2026'), findsOneWidget);
    expect(find.textContaining('Dec 27-29.2026'), findsNothing);
  });

  testWidgets('allows an empty date list', (tester) async {
    final provider = TripsProvider(AppSettings());
    provider.addTrip(validTrip());

    await tester.pumpWidget(buildSubject(provider));
    await tester.pumpAndSettle();

    expect(find.text('All Clear!'), findsOneWidget);
    expect(find.text('No issues found!'), findsOneWidget);
    expect(find.text('Invalid Trip Date'), findsNothing);
  });

  testWidgets('explains featured companion drift and lists sorted IDs', (
    tester,
  ) async {
    final trips = <Map<String, dynamic>>[
      validTrip(id: 'zulu-trip', featured: true),
      validTrip(id: 'alpha-trip'),
    ];
    final service = _FakeGitHubService(
      tripsResult: GitHubFileResult(
        content: TripsParser.generateTripsDataJs(trips),
        sha: 'trips-sha',
        success: true,
      ),
      featuredResult: GitHubFileResult(
        content: 'const featuredTripIds = ["alpha-trip"];',
        sha: 'featured-sha',
        success: true,
      ),
    );
    final provider = TripsProvider(
      AppSettings(),
      serviceFactory: (_) => service,
    );
    await provider.loadTrips();

    expect(provider.hasFeaturedDrift, isTrue);
    await tester.pumpWidget(buildSubject(provider));
    await tester.pumpAndSettle();

    expect(find.text('Featured Trips Out of Sync'), findsOneWidget);
    expect(find.textContaining('alpha-trip, zulu-trip'), findsOneWidget);
    expect(find.textContaining('embedded `featured` value'), findsOneWidget);
    expect(find.textContaining('next atomic save'), findsOneWidget);
  });

  testWidgets('surfaces an exposed provider load error', (tester) async {
    final service = _FakeGitHubService(
      tripsResult: GitHubFileResult(
        content: '',
        sha: '',
        success: false,
        error: 'Repository schema could not be loaded',
      ),
    );
    final provider = TripsProvider(
      AppSettings(),
      serviceFactory: (_) => service,
    );
    await provider.loadTrips();

    await tester.pumpWidget(buildSubject(provider));
    await tester.pumpAndSettle();

    expect(find.text('Trip Data Error'), findsOneWidget);
    expect(find.text('Repository schema could not be loaded'), findsOneWidget);
  });

  testWidgets('surfaces schema validation errors exposed by the provider', (
    tester,
  ) async {
    final service = _FakeGitHubService(
      tripsResult: GitHubFileResult(
        content: 'const tripsData = {',
        sha: 'malformed-trips-sha',
        success: true,
      ),
      featuredResult: GitHubFileResult(
        content: 'const featuredTripIds = [];',
        sha: 'featured-sha',
        success: true,
      ),
    );
    final provider = TripsProvider(
      AppSettings(),
      serviceFactory: (_) => service,
    );
    await provider.loadTrips();

    expect(provider.publicationErrors, isNotEmpty);
    await tester.pumpWidget(buildSubject(provider));
    await tester.pumpAndSettle();

    expect(find.text('Trip Data Error'), findsOneWidget);
    expect(find.textContaining('Publishing blocked'), findsOneWidget);
    expect(find.textContaining('trips-data.js'), findsOneWidget);
  });

  testWidgets('does not scan partial trips with known-field type errors', (
    tester,
  ) async {
    final service = _FakeGitHubService(
      tripsResult: GitHubFileResult(
        content: '''const tripsData = {
  alpha: {
    title: "Alpha",
    location: "Karnataka",
    price: "₹999",
    image: "images/trips/alpha.jpg",
    highlights: "not-a-list",
    itinerary: "not-a-list",
    galleryImages: "not-a-list"
  }
};''',
        sha: 'wrong-types-sha',
        success: true,
      ),
      featuredResult: GitHubFileResult(
        content: 'const featuredTripIds = [];',
        sha: 'featured-sha',
        success: true,
      ),
    );
    final provider = TripsProvider(
      AppSettings(),
      serviceFactory: (_) => service,
    );
    await provider.loadTrips();

    expect(provider.publicationErrors, isNotEmpty);
    await tester.pumpWidget(buildSubject(provider));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Trip Data Error'), findsOneWidget);
    expect(find.textContaining('highlights'), findsOneWidget);
    expect(find.byTooltip('Auto-fix this issue'), findsNothing);
  });

  testWidgets('disables every auto-fix while provider work is in flight', (
    tester,
  ) async {
    final pending = Completer<GitHubFileResult>();
    final service = _PendingGitHubService(pending.future);
    final provider = TripsProvider(
      AppSettings(),
      serviceFactory: (_) => service,
    );
    provider.addTrip(<String, dynamic>{...validTrip(), 'price': '₹1000'});
    provider.markChangesSaved();

    final load = provider.loadTrips();
    await tester.pump();
    expect(provider.isLoading, isTrue);

    try {
      await tester.pumpWidget(buildSubject(provider));
      await tester.pump();

      expect(find.text('Price Missing Comma'), findsOneWidget);
      final fixAllFinder = find.ancestor(
        of: find.textContaining('Auto-Fixable Issues'),
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        ),
      );
      final fixAll = tester.widget<ButtonStyleButton>(fixAllFinder);
      final fixOne = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Auto-fix this issue'),
          matching: find.byType(IconButton),
        ),
      );
      final rescan = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Re-scan'),
          matching: find.byType(IconButton),
        ),
      );
      expect(fixAll.onPressed, isNull);
      expect(fixOne.onPressed, isNull);
      expect(rescan.onPressed, isNull);
      expect(provider.trips.single['price'], '₹1000');
    } finally {
      pending.complete(
        GitHubFileResult(
          content: '',
          sha: '',
          success: false,
          error: 'Expected pending-load failure',
        ),
      );
      await load;
    }
  });
}

class _FakeGitHubService extends GitHubService {
  _FakeGitHubService({required this.tripsResult, this.featuredResult})
    : super(settings: AppSettings());

  final GitHubFileResult tripsResult;
  final GitHubFileResult? featuredResult;

  @override
  Future<GitHubFileResult> fetchTripsData() async => tripsResult;

  @override
  Future<GitHubFileResult> fetchFile(String filePath) async =>
      featuredResult ??
      GitHubFileResult(
        content: '',
        sha: '',
        success: false,
        error: 'No fake response for $filePath',
      );
}

final class _PendingGitHubService extends GitHubService {
  _PendingGitHubService(this.pending) : super(settings: AppSettings());

  final Future<GitHubFileResult> pending;

  @override
  Future<GitHubFileResult> fetchTripsData() => pending;
}
