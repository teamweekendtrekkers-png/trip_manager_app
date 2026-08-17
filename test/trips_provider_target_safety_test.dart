import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/models/app_settings.dart';
import 'package:trip_manager_app/providers/trips_provider.dart';
import 'package:trip_manager_app/services/github_service.dart';
import 'package:trip_manager_app/services/trips_parser.dart';

const _tripsPath = 'js/trips-data.js';

Map<String, dynamic> _trip(
  String id, {
  required String title,
  String price = '₹1,000',
}) => <String, dynamic>{
  'id': id,
  'title': title,
  'name': title,
  'location': 'Karnataka',
  'destination': 'Karnataka',
  'price': price,
  'featured': false,
  'isActive': true,
  'availableDates': <String>[],
};

AppSettings _settings(String repository) => AppSettings(
  githubToken: 'test-token',
  repositoryOwner: 'owner',
  repositoryName: repository,
  branch: 'main',
  tripsDataPath: _tripsPath,
);

void main() {
  group('TripsProvider target and reload safety', () {
    test(
      'a stale load cannot win or leave loading stuck after target change',
      () async {
        final delayed = Completer<GitHubFileResult>();
        final oldService = _MutableGitHubService(
          trips: <Map<String, dynamic>>[_trip('old', title: 'Old target')],
        )..nextTripsFetch = delayed.future;
        final newService = _MutableGitHubService(
          trips: <Map<String, dynamic>>[_trip('new', title: 'New target')],
        );
        final services = <String, _MutableGitHubService>{
          'old-repo': oldService,
          'new-repo': newService,
        };
        final provider = TripsProvider(
          _settings('old-repo'),
          serviceFactory: (settings) => services[settings.repositoryName]!,
        );

        final staleLoad = provider.loadTrips();
        await Future<void>.delayed(Duration.zero);
        expect(provider.isLoading, isTrue);

        provider.updateSettings(_settings('new-repo'));
        expect(provider.isLoading, isFalse);
        await provider.loadTrips();
        expect(provider.trips.single['id'], 'new');
        expect(provider.isLoading, isFalse);

        delayed.complete(oldService.fileResult());
        await staleLoad;

        expect(provider.trips.single['id'], 'new');
        expect(provider.isLoading, isFalse);
        expect(provider.currentSha, newService.tripsSha);
      },
    );

    test(
      'repository switch blocks stale overwrite until explicit reload',
      () async {
        final oldService = _MutableGitHubService(
          trips: <Map<String, dynamic>>[_trip('old', title: 'Old target')],
        );
        final newService = _MutableGitHubService(
          trips: <Map<String, dynamic>>[_trip('new', title: 'New target')],
        );
        final services = <String, _MutableGitHubService>{
          'old-repo': oldService,
          'new-repo': newService,
        };
        final provider = TripsProvider(
          _settings('old-repo'),
          serviceFactory: (settings) => services[settings.repositoryName]!,
        );
        await provider.loadTrips();
        provider.updateTrip(0, <String, dynamic>{
          ...provider.trips.single,
          'title': 'Unsaved old-target edit',
          'name': 'Unsaved old-target edit',
        });

        provider.updateSettings(_settings('new-repo'));
        final overwrite = await provider.forceSaveTrips();

        expect(overwrite.success, isFalse);
        expect(overwrite.error, contains('Reload trips before publishing'));
        expect(newService.atomicCommitCalls, 0);
        expect(provider.trips.single['id'], 'old');
        expect(provider.hasUnsavedChanges, isTrue);

        final reloaded = await provider.reloadDiscardingLocalChanges();
        expect(reloaded, isTrue);
        expect(provider.trips.single['id'], 'new');
        expect(provider.hasUnsavedChanges, isFalse);
      },
    );

    test('target change cancels a save before any old-target commit', () async {
      final delayed = Completer<GitHubFileResult>();
      final oldService = _MutableGitHubService(
        trips: <Map<String, dynamic>>[_trip('old', title: 'Old target')],
      );
      final newService = _MutableGitHubService(
        trips: <Map<String, dynamic>>[_trip('new', title: 'New target')],
      );
      final services = <String, _MutableGitHubService>{
        'old-repo': oldService,
        'new-repo': newService,
      };
      final provider = TripsProvider(
        _settings('old-repo'),
        serviceFactory: (settings) => services[settings.repositoryName]!,
      );
      await provider.loadTrips();
      provider.updateTrip(0, <String, dynamic>{
        ...provider.trips.single,
        'title': 'Unsaved old-target edit',
        'name': 'Unsaved old-target edit',
      });
      oldService.nextTripsFetch = delayed.future;

      final save = provider.saveTrips();
      await Future<void>.delayed(Duration.zero);
      expect(provider.isLoading, isTrue);
      provider.updateSettings(_settings('new-repo'));
      delayed.complete(oldService.fileResult());
      final result = await save;

      expect(result.success, isFalse);
      expect(result.error, contains('Repository settings changed'));
      expect(oldService.atomicCommitCalls, 0);
      expect(newService.atomicCommitCalls, 0);
      expect(provider.isLoading, isFalse);
      expect(provider.hasUnsavedChanges, isTrue);
    });

    test(
      'credential-only update keeps the loaded snapshot and local work',
      () async {
        final service = _MutableGitHubService(
          trips: <Map<String, dynamic>>[_trip('a', title: 'Original')],
        );
        final provider = TripsProvider(
          _settings('repo'),
          serviceFactory: (_) => service,
        );
        await provider.loadTrips();
        provider.updateTrip(0, <String, dynamic>{
          ...provider.trips.single,
          'title': 'Local title',
          'name': 'Local title',
        });

        provider.updateSettings(
          _settings('repo').copyWith(githubToken: 'replacement-token'),
        );

        expect(provider.hasCompleteRemoteSnapshot, isTrue);
        expect(provider.hasUnsavedChanges, isTrue);
        expect(provider.trips.single['title'], 'Local title');
        expect(await provider.refreshTrips(), isTrue);
        expect(provider.trips.single['title'], 'Local title');
      },
    );

    test('force save is rejected before any target has been loaded', () async {
      final service = _MutableGitHubService(
        trips: <Map<String, dynamic>>[_trip('remote', title: 'Remote')],
      );
      final provider = TripsProvider(
        _settings('repo'),
        serviceFactory: (_) => service,
      );

      final result = await provider.forceSaveTrips();

      expect(result.success, isFalse);
      expect(result.error, contains('No complete remote snapshot'));
      expect(service.fetchTripsCalls, 0);
      expect(service.atomicCommitCalls, 0);
    });

    test('routine refresh merges while explicit reload discards', () async {
      final service = _MutableGitHubService(
        trips: <Map<String, dynamic>>[
          _trip('a', title: 'Original', price: '₹1,000'),
        ],
      );
      final provider = TripsProvider(
        _settings('repo'),
        serviceFactory: (_) => service,
      );
      await provider.loadTrips();
      provider.updateTrip(0, <String, dynamic>{
        ...provider.trips.single,
        'title': 'Local title',
        'name': 'Local title',
      });
      service.replaceTrips(<Map<String, dynamic>>[
        _trip('a', title: 'Original', price: '₹2,000'),
      ]);

      // The raw load entry point refuses to discard dirty state.
      final fetchesBeforeBlockedLoad = service.fetchTripsCalls;
      await provider.loadTrips();
      expect(provider.trips.single['title'], 'Local title');
      expect(service.fetchTripsCalls, fetchesBeforeBlockedLoad);

      expect(await provider.refreshTrips(), isTrue);
      expect(provider.trips.single['title'], 'Local title');
      expect(provider.trips.single['price'], '₹2,000');
      expect(provider.hasUnsavedChanges, isTrue);

      provider.updateTrip(0, <String, dynamic>{
        ...provider.trips.single,
        'title': 'Second local title',
        'name': 'Second local title',
      });
      service.replaceTrips(<Map<String, dynamic>>[
        _trip('a', title: 'Remote replacement', price: '₹3,000'),
      ]);

      expect(await provider.reloadDiscardingLocalChanges(), isTrue);
      expect(provider.trips.single['title'], 'Remote replacement');
      expect(provider.trips.single['price'], '₹3,000');
      expect(provider.hasUnsavedChanges, isFalse);
    });
  });
}

final class _MutableGitHubService extends GitHubService {
  _MutableGitHubService({required List<Map<String, dynamic>> trips})
    : _trips = trips,
      super(settings: _settings('fake-service'));

  List<Map<String, dynamic>> _trips;
  Future<GitHubFileResult>? nextTripsFetch;
  int fetchTripsCalls = 0;
  int atomicCommitCalls = 0;
  int _revision = 1;

  String get tripsSha => 'trips-sha-$_revision';
  String get featuredSha => 'featured-sha-$_revision';

  void replaceTrips(List<Map<String, dynamic>> trips) {
    _trips = trips;
    _revision++;
  }

  GitHubFileResult fileResult() => GitHubFileResult(
    content: TripsParser.generateTripsDataJs(_trips),
    sha: tripsSha,
    success: true,
  );

  @override
  Future<GitHubFileResult> fetchTripsData() {
    fetchTripsCalls++;
    final pending = nextTripsFetch;
    nextTripsFetch = null;
    return pending ?? Future<GitHubFileResult>.value(fileResult());
  }

  @override
  Future<GitHubFileResult> fetchFile(String filePath) async => GitHubFileResult(
    content: TripsParser.generateFeaturedTripsJs(_trips),
    sha: featuredSha,
    success: true,
  );

  @override
  Future<GitHubCommitResult> commitFilesAtomically({
    required Map<String, String> files,
    required Map<String, String?> expectedBlobShas,
    required String commitMessage,
  }) async {
    atomicCommitCalls++;
    return GitHubCommitResult(
      success: true,
      commitSha: 'commit-$atomicCommitCalls',
      fileBlobShas: <String, String>{
        for (final path in files.keys) path: 'blob-$path-$atomicCommitCalls',
      },
    );
  }
}
