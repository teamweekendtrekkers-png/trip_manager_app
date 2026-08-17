import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/providers/trips_provider.dart';
import 'package:trip_manager_app/services/github_service.dart';
import 'package:trip_manager_app/services/trips_parser.dart';

const tripsPath = 'js/trips-data.js';
const featuredPath = 'js/featured-trips.js';

Map<String, dynamic> trip(
  String id, {
  String? title,
  String price = '₹1,000',
  bool featured = false,
  List<String> dates = const ['Aug 14-16, 2026'],
}) => {
  'id': id,
  'title': title ?? id,
  'name': title ?? id,
  'location': 'Karnataka',
  'destination': 'Karnataka',
  'price': price,
  'featured': featured,
  'availableDates': dates,
  'isActive': true,
};

String tripsSource(
  List<Map<String, dynamic>> trips, {
  String marker = 'SOURCE',
}) => '${TripsParser.generateTripsDataJs(trips)}\n// $marker TRIPS SUFFIX\n';

String featuredSource(
  List<Map<String, dynamic>> trips, {
  String marker = 'SOURCE',
}) =>
    '${TripsParser.generateFeaturedTripsJs(trips)}\n// $marker FEATURED SUFFIX\n';

class AtomicCall {
  final Map<String, String> files;
  final Map<String, String?> expectedBlobShas;
  final String commitMessage;

  AtomicCall({
    required this.files,
    required this.expectedBlobShas,
    required this.commitMessage,
  });
}

class FakeGitHubService extends GitHubService {
  final Queue<GitHubFileResult> tripsResponses = Queue();
  final Queue<GitHubFileResult> featuredResponses = Queue();
  final Queue<GitHubCommitResult> commitResponses = Queue();
  final List<AtomicCall> atomicCalls = [];
  var commitNumber = 0;

  FakeGitHubService()
    : super(
        settings: AppSettings(
          githubToken: 'test',
          repositoryOwner: 'owner',
          repositoryName: 'repo',
          branch: 'main',
          tripsDataPath: tripsPath,
        ),
      );

  void queueSnapshot(
    List<Map<String, dynamic>> trips, {
    required String tripsSha,
    required String featuredSha,
    String marker = 'SOURCE',
    List<Map<String, dynamic>>? companionTrips,
  }) {
    tripsResponses.add(
      GitHubFileResult(
        content: tripsSource(trips, marker: marker),
        sha: tripsSha,
        success: true,
      ),
    );
    featuredResponses.add(
      GitHubFileResult(
        content: featuredSource(companionTrips ?? trips, marker: marker),
        sha: featuredSha,
        success: true,
      ),
    );
  }

  @override
  Future<GitHubFileResult> fetchTripsData() async {
    if (tripsResponses.isEmpty) {
      throw StateError('No queued trips response');
    }
    return tripsResponses.removeFirst();
  }

  @override
  Future<GitHubFileResult> fetchFile(String filePath) async {
    expect(filePath, featuredPath);
    if (featuredResponses.isEmpty) {
      throw StateError('No queued featured response');
    }
    return featuredResponses.removeFirst();
  }

  @override
  Future<GitHubCommitResult> commitFilesAtomically({
    required Map<String, String> files,
    required Map<String, String?> expectedBlobShas,
    required String commitMessage,
  }) async {
    atomicCalls.add(
      AtomicCall(
        files: Map.of(files),
        expectedBlobShas: Map.of(expectedBlobShas),
        commitMessage: commitMessage,
      ),
    );
    if (commitResponses.isNotEmpty) return commitResponses.removeFirst();
    commitNumber++;
    return GitHubCommitResult(
      success: true,
      commitSha: 'commit-$commitNumber',
      baseCommitSha: 'head-$commitNumber',
      fileBlobShas: {
        tripsPath: 'new-trips-$commitNumber',
        featuredPath: 'new-featured-$commitNumber',
      },
    );
  }
}

TripsProvider providerFor(FakeGitHubService service) =>
    TripsProvider(service.settings, serviceFactory: (_) => service);

void main() {
  group('TripsProvider safe publication', () {
    test('load keeps embedded featured canonical and reports drift', () async {
      final service = FakeGitHubService()
        ..queueSnapshot(
          [trip('a', featured: true)],
          tripsSha: 'trips-1',
          featuredSha: 'featured-1',
          companionTrips: [trip('a', featured: false)],
        );
      final provider = providerFor(service);

      await provider.loadTrips();

      expect(provider.error, isNull);
      expect(provider.canPublish, isTrue);
      expect(provider.trips.single['featured'], isTrue);
      expect(provider.featuredDriftIds, {'a'});
      expect(provider.currentSha, 'trips-1');
      expect(provider.currentFeaturedSha, 'featured-1');
    });

    test('reports order-only featured companion drift', () async {
      final embedded = [trip('a', featured: true), trip('b', featured: true)];
      final service = FakeGitHubService()
        ..queueSnapshot(
          embedded,
          tripsSha: 'trips-1',
          featuredSha: 'featured-1',
          companionTrips: [embedded[1], embedded[0]],
        );
      final provider = providerFor(service);

      await provider.loadTrips();

      expect(provider.hasFeaturedDrift, isTrue);
      expect(provider.featuredDriftIds, {'a', 'b'});
    });

    test('validates both source documents on load and blocks save', () async {
      final service = FakeGitHubService();
      service.tripsResponses.add(
        GitHubFileResult(
          content: 'const tripsData = {a: {title: "A", unknownField: true}};',
          sha: 'trips-1',
          success: true,
        ),
      );
      service.featuredResponses.add(
        GitHubFileResult(
          content: 'const featuredTripIds = ["a"];',
          sha: 'featured-1',
          success: true,
        ),
      );
      final provider = providerFor(service);

      await provider.loadTrips();
      final save = await provider.saveTrips();

      expect(provider.canPublish, isFalse);
      expect(provider.publicationErrors.join('\n'), contains('unknownField'));
      expect(provider.error, contains('Publishing blocked'));
      expect(save.success, isFalse);
      expect(service.atomicCalls, isEmpty);
    });

    test('rejects a malformed featured companion on load', () async {
      final service = FakeGitHubService();
      service.tripsResponses.add(
        GitHubFileResult(
          content: tripsSource([trip('a')]),
          sha: 'trips-1',
          success: true,
        ),
      );
      service.featuredResponses.add(
        GitHubFileResult(
          content: 'const featuredTripIds = ["a";',
          sha: 'featured-1',
          success: true,
        ),
      );
      final provider = providerFor(service);

      await provider.loadTrips();

      expect(provider.canPublish, isFalse);
      expect(
        provider.publicationErrors.join('\n'),
        contains('featured-trips.js'),
      );
      expect(provider.error, contains('malformed or unterminated'));
    });

    test(
      'overwrite and merge require a complete validated base snapshot',
      () async {
        final service = FakeGitHubService();
        final provider = providerFor(service)..addTrip(trip('local-only'));

        final overwrite = await provider.forceSaveTrips();
        final merge = await provider.pullAndMerge();

        expect(overwrite.success, isFalse);
        expect(overwrite.error, contains('complete remote snapshot'));
        expect(merge.success, isFalse);
        expect(merge.error, contains('complete remote snapshot'));
        expect(service.atomicCalls, isEmpty);
        expect(service.tripsResponses, isEmpty);
      },
    );

    test('saves two source-preserved files in one atomic commit', () async {
      final base = [trip('a', featured: true)];
      final service = FakeGitHubService()
        ..queueSnapshot(
          base,
          tripsSha: 'trips-loaded',
          featuredSha: 'featured-loaded',
          marker: 'LOADED',
        )
        ..queueSnapshot(
          base,
          tripsSha: 'trips-latest',
          featuredSha: 'featured-latest',
          marker: 'LATEST',
        );
      final provider = providerFor(service);
      await provider.loadTrips();
      provider.updateTrip(0, {
        ...provider.trips.single,
        'title': 'Locally changed',
        'name': 'Locally changed',
      });

      final result = await provider.saveTrips(commitMessage: 'Atomic update');

      expect(result.success, isTrue, reason: result.error);
      expect(result.commitSha, 'commit-1');
      expect(service.atomicCalls, hasLength(1));
      final call = service.atomicCalls.single;
      expect(call.files.keys, {tripsPath, featuredPath});
      expect(call.expectedBlobShas, {
        tripsPath: 'trips-latest',
        featuredPath: 'featured-latest',
      });
      expect(call.commitMessage, 'Atomic update');
      expect(call.files[tripsPath], endsWith('// LATEST TRIPS SUFFIX\n'));
      expect(call.files[featuredPath], endsWith('// LATEST FEATURED SUFFIX\n'));
      expect(
        TripsParser.parseTripsData(call.files[tripsPath]!).single['title'],
        'Locally changed',
      );
      expect(provider.hasUnsavedChanges, isFalse);
      expect(provider.currentSha, 'new-trips-1');
      expect(provider.currentFeaturedSha, 'new-featured-1');
    });

    test('publishes an intentional deletion without recovering it', () async {
      final base = [trip('delete-me'), trip('keep-me')];
      final service = FakeGitHubService()
        ..queueSnapshot(
          base,
          tripsSha: 'trips-loaded',
          featuredSha: 'featured-loaded',
        )
        ..queueSnapshot(
          base,
          tripsSha: 'trips-latest',
          featuredSha: 'featured-latest',
        );
      final provider = providerFor(service);
      await provider.loadTrips();
      provider.deleteTrip(provider.getTripIndexById('delete-me')!);

      final result = await provider.saveTrips();

      expect(result.success, isTrue, reason: result.error);
      final published = TripsParser.parseTripsData(
        service.atomicCalls.single.files[tripsPath]!,
      );
      expect(published.map((value) => value['id']), ['keep-me']);
      expect(provider.intentionalDeletedIds, isEmpty);
    });

    test('automatically merges edits to non-overlapping fields', () async {
      final base = [trip('a', title: 'Original', price: '₹1,000')];
      final remote = [trip('a', title: 'Original', price: '₹2,000')];
      final service = FakeGitHubService()
        ..queueSnapshot(
          base,
          tripsSha: 'trips-loaded',
          featuredSha: 'featured-loaded',
        )
        ..queueSnapshot(
          remote,
          tripsSha: 'trips-latest',
          featuredSha: 'featured-latest',
        );
      final provider = providerFor(service);
      await provider.loadTrips();
      provider.updateTrip(0, {
        ...provider.trips.single,
        'title': 'Local title',
        'name': 'Local title',
      });

      final result = await provider.saveTrips();

      expect(result.success, isTrue, reason: result.error);
      final published = TripsParser.parseTripsData(
        service.atomicCalls.single.files[tripsPath]!,
      ).single;
      expect(published['title'], 'Local title');
      expect(published['price'], '₹2,000');
    });

    test('pullAndMerge uses the same field-aware three-way merge', () async {
      final base = [trip('a', title: 'Original', price: '₹1,000')];
      final remote = [trip('a', title: 'Original', price: '₹2,000')];
      final service = FakeGitHubService()
        ..queueSnapshot(
          base,
          tripsSha: 'trips-loaded',
          featuredSha: 'featured-loaded',
        )
        ..queueSnapshot(
          remote,
          tripsSha: 'trips-latest',
          featuredSha: 'featured-latest',
        );
      final provider = providerFor(service);
      await provider.loadTrips();
      provider.updateTrip(0, {
        ...provider.trips.single,
        'title': 'Local title',
        'name': 'Local title',
      });

      final result = await provider.pullAndMerge();

      expect(result.success, isTrue, reason: result.error);
      expect(provider.trips.single['title'], 'Local title');
      expect(provider.trips.single['price'], '₹2,000');
      expect(provider.currentSha, 'trips-latest');
      expect(provider.currentFeaturedSha, 'featured-latest');
      expect(provider.hasUnsavedChanges, isTrue);
      expect(service.atomicCalls, isEmpty);
    });

    test('blocks a true same-field conflict with details', () async {
      final base = [trip('a', title: 'Original')];
      final service = FakeGitHubService()
        ..queueSnapshot(
          base,
          tripsSha: 'trips-loaded',
          featuredSha: 'featured-loaded',
        )
        ..queueSnapshot(
          [trip('a', title: 'Remote title')],
          tripsSha: 'trips-latest',
          featuredSha: 'featured-latest',
        );
      final provider = providerFor(service);
      await provider.loadTrips();
      provider.updateTrip(0, {
        ...provider.trips.single,
        'title': 'Local title',
        'name': 'Local title',
      });

      final result = await provider.saveTrips();

      expect(result.success, isFalse);
      expect(result.hasConflict, isTrue);
      expect(result.error, contains('Trip "a" field "title"'));
      expect(service.atomicCalls, isEmpty);
      expect(provider.hasUnsavedChanges, isTrue);
    });

    test('surfaces a branch race without clearing local edits', () async {
      final base = [trip('a')];
      final service = FakeGitHubService()
        ..queueSnapshot(
          base,
          tripsSha: 'trips-loaded',
          featuredSha: 'featured-loaded',
        )
        ..queueSnapshot(
          base,
          tripsSha: 'trips-latest',
          featuredSha: 'featured-latest',
        );
      service.commitResponses.add(
        GitHubCommitResult(
          success: false,
          hasConflict: true,
          error: 'The branch changed while publishing.',
        ),
      );
      final provider = providerFor(service);
      await provider.loadTrips();
      provider.toggleFeatured(0);

      final result = await provider.saveTrips();

      expect(result.success, isFalse);
      expect(result.hasConflict, isTrue);
      expect(provider.hasConflict, isTrue);
      expect(provider.hasUnsavedChanges, isTrue);
      expect(provider.trips.single['featured'], isTrue);
    });

    test(
      'retries after a temporarily malformed remote without losing local work',
      () async {
        final base = [trip('a', title: 'Original')];
        final service = FakeGitHubService()
          ..queueSnapshot(
            base,
            tripsSha: 'trips-loaded',
            featuredSha: 'featured-loaded',
          );
        service.tripsResponses.add(
          GitHubFileResult(
            content:
                'const tripsData = {a: {title: "Broken", unknownField: 1}};',
            sha: 'trips-malformed',
            success: true,
          ),
        );
        service.featuredResponses.add(
          GitHubFileResult(
            content: 'const featuredTripIds = [];',
            sha: 'featured-malformed',
            success: true,
          ),
        );
        service.queueSnapshot(
          base,
          tripsSha: 'trips-repaired',
          featuredSha: 'featured-repaired',
        );
        final provider = providerFor(service);
        await provider.loadTrips();
        provider.updateTrip(0, {
          ...provider.trips.single,
          'title': 'Local survives',
          'name': 'Local survives',
        });

        final blocked = await provider.saveTrips();

        expect(blocked.success, isFalse);
        expect(blocked.error, contains('unknownField'));
        expect(provider.hasUnsavedChanges, isTrue);
        expect(provider.trips.single['title'], 'Local survives');
        expect(provider.canPublish, isTrue);
        expect(service.atomicCalls, isEmpty);

        final retried = await provider.saveTrips();

        expect(retried.success, isTrue, reason: retried.error);
        expect(service.atomicCalls, hasLength(1));
        expect(
          TripsParser.parseTripsData(
            service.atomicCalls.single.files[tripsPath]!,
          ).single['title'],
          'Local survives',
        );
      },
    );

    test(
      'overwrite uses latest spans and SHAs but a normal atomic commit',
      () async {
        final service = FakeGitHubService()
          ..queueSnapshot(
            [trip('a', title: 'Base')],
            tripsSha: 'trips-loaded',
            featuredSha: 'featured-loaded',
          )
          ..queueSnapshot(
            [trip('a', title: 'Remote')],
            tripsSha: 'trips-overwrite',
            featuredSha: 'featured-overwrite',
            marker: 'OVERWRITE-LATEST',
          );
        final provider = providerFor(service);
        await provider.loadTrips();
        provider.updateTrip(0, {
          ...provider.trips.single,
          'title': 'Local wins',
          'name': 'Local wins',
        });

        final result = await provider.forceSaveTrips(
          commitMessage: 'Confirmed overwrite',
        );

        expect(result.success, isTrue, reason: result.error);
        final call = service.atomicCalls.single;
        expect(call.expectedBlobShas, {
          tripsPath: 'trips-overwrite',
          featuredPath: 'featured-overwrite',
        });
        expect(call.commitMessage, 'Confirmed overwrite');
        expect(
          call.files[tripsPath],
          endsWith('// OVERWRITE-LATEST TRIPS SUFFIX\n'),
        );
        expect(
          TripsParser.parseTripsData(call.files[tripsPath]!).single['title'],
          'Local wins',
        );
      },
    );
  });
}
