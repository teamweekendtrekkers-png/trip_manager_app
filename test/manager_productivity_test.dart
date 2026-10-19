import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:trip_manager_app/services/draft_store.dart';
import 'package:trip_manager_app/services/workspace_changes.dart';
import 'package:trip_manager_app/widgets/local_draft.dart';
import 'package:trip_manager_app/providers/trips_provider.dart';
import 'package:trip_manager_app/services/trips_parser.dart';
import 'trips_provider_publication_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Recoverable drafts', () {
    late Directory directory;
    setUp(() async {
      directory = await Directory(
        'build/test-drafts',
      ).create(recursive: true).then((d) => d.createTemp('vault-'));
      Hive.init(directory.path);
      await DraftStore.init();
    });
    tearDown(() async {
      await DraftStore.close();
      await directory.delete(recursive: true);
    });
    test('trip workspace survives restart and remains unpublished', () async {
      final base = [fixtures.trip('a', title: 'Original')],
          service = fixtures.FakeGitHubService()
            ..queueSnapshot(base, tripsSha: 't1', featuredSha: 'f1');
      final p = TripsProvider(
        service.settings,
        serviceFactory: (_) => service,
        persistentDrafts: true,
      );
      await p.loadTrips();
      p.updateTrip(0, {
        ...p.trips.single,
        'title': 'Recovered title',
        'name': 'Recovered title',
      });
      expect(p.isDraftSaved, false);
      await p.flushDraft();
      expect(p.isDraftSaved, true);
      p.updateTrip(0, {...p.trips.single, 'location': 'New location'});
      expect(p.isDraftSaved, false);
      await p.flushDraft();
      expect(p.isDraftSaved, true);
      p.dispose();
      final remote = fixtures.FakeGitHubService()
        ..queueSnapshot(base, tripsSha: 't1', featuredSha: 'f1');
      final restored = TripsProvider(
        remote.settings,
        serviceFactory: (_) => remote,
        persistentDrafts: true,
      );
      await restored.loadTrips();
      expect(restored.trips.single['title'], 'Recovered title');
      expect(restored.hasUnsavedChanges, true);
      expect(remote.atomicCalls, isEmpty);
      restored.dispose();
    });
    test(
      'remote conflict keeps the saved draft on disk until explicitly reviewed',
      () async {
        final service = fixtures.FakeGitHubService()
          ..queueSnapshot(
            [fixtures.trip('a', title: 'Original')],
            tripsSha: 't1',
            featuredSha: 'f1',
          );
        final p = TripsProvider(
          service.settings,
          serviceFactory: (_) => service,
          persistentDrafts: true,
        );
        await p.loadTrips();
        p.updateTrip(0, {
          ...p.trips.single,
          'title': 'Local edit',
          'name': 'Local edit',
        });
        await p.flushDraft();
        p.dispose();
        final remote = fixtures.FakeGitHubService()
          ..queueSnapshot(
            [fixtures.trip('a', title: 'Remote edit')],
            tripsSha: 't2',
            featuredSha: 'f2',
          );
        final restored = TripsProvider(
          remote.settings,
          serviceFactory: (_) => remote,
          persistentDrafts: true,
        );
        await restored.loadTrips();
        await restored.flushDraft();
        expect(restored.draftError, contains('needs review'));
        expect(
          DraftStore.read(
            restored.draftScope,
            'workspace',
          )!['data']['trips'][0]['title'],
          'Local edit',
        );
        restored.dispose();
      },
    );
    test(
      'switching repositories immediately retains the pending old draft',
      () async {
        final service = fixtures.FakeGitHubService()
          ..queueSnapshot(
            [fixtures.trip('a', title: 'Original')],
            tripsSha: 't1',
            featuredSha: 'f1',
          );
        final p = TripsProvider(
          service.settings,
          serviceFactory: (_) => service,
          persistentDrafts: true,
        );
        await p.loadTrips();
        final originalScope = p.draftScope;
        p.updateTrip(0, {
          ...p.trips.single,
          'title': 'Pending edit',
          'name': 'Pending edit',
        });
        p.updateSettings(service.settings.copyWith(branch: 'another-branch'));
        final newScope = p.draftScope;
        p.dispose();
        await DraftStore.close();
        await DraftStore.init();
        expect(
          DraftStore.read(
            originalScope,
            'workspace',
          )!['data']['trips'][0]['title'],
          'Pending edit',
        );
        expect(DraftStore.read(newScope, 'workspace'), isNull);
        expect(service.atomicCalls, isEmpty);
      },
    );
    test(
      'trip editor history exposes only that trip from workspace versions',
      () async {
        final scope = DraftStore.scope(fixtures.FakeGitHubService().settings);
        await DraftStore.remember(scope, 'workspace', {
          'trips': [
            fixtures.trip('a', title: 'A'),
            fixtures.trip('b', title: 'B'),
          ],
        }, 'Published version');
        final versions = DraftStore.tripVersions(scope, 'a');
        expect(versions.single['data']['title'], 'A');
        expect(versions.single['label'], 'Published version');
        expect(DraftStore.tripVersions(scope, 'missing'), isEmpty);
        expect(DraftStore.tripVersions('another repository', 'a'), isEmpty);
      },
    );
    test('repository and branch scopes never share drafts', () async {
      final settings = fixtures.FakeGitHubService().settings;
      await DraftStore.write(DraftStore.scope(settings), 'homepage', {
        'draft': {'title': 'Private draft'},
      });
      expect(
        DraftStore.read(
          DraftStore.scope(settings.copyWith(branch: 'other')),
          'homepage',
        ),
        isNull,
      );
      expect(
        DraftStore.scope(settings.copyWith(githubToken: 'different')),
        DraftStore.scope(settings),
      );
    });
  });
  test(
    'selective publishing retains unfinished edits and publishes only chosen trip',
    () async {
      final base = [
        fixtures.trip('a', title: 'A'),
        fixtures.trip('b', title: 'B'),
      ];
      final service = fixtures.FakeGitHubService()
        ..queueSnapshot(base, tripsSha: 't1', featuredSha: 'f1')
        ..queueSnapshot(base, tripsSha: 't1', featuredSha: 'f1');
      final p = fixtures.providerFor(service);
      await p.loadTrips();
      p.updateTrip(0, {...p.trips[0], 'title': 'Ready A', 'name': 'Ready A'});
      p.updateTrip(1, {
        ...p.trips[1],
        'title': 'Unfinished B',
        'name': 'Unfinished B',
      });
      final result = await p.saveTrips(selectedTripIds: {'a'});
      expect(result.success, true, reason: result.error);
      final published = TripsParser.parseTripsData(
        service.atomicCalls.single.files[fixtures.tripsPath]!,
      );
      expect(published.first['title'], 'Ready A');
      expect(published.last['title'], 'B');
      expect(p.trips.last['title'], 'Unfinished B');
      expect(p.changes.keys, {'b'});
      expect(p.hasUnsavedChanges, true);
      p.dispose();
    },
  );
  test(
    'unselected deletion stays a draft after publishing another trip',
    () async {
      final base = [
        fixtures.trip('a', title: 'A'),
        fixtures.trip('b', title: 'B'),
      ];
      final service = fixtures.FakeGitHubService()
        ..queueSnapshot(base, tripsSha: 't1', featuredSha: 'f1')
        ..queueSnapshot(base, tripsSha: 't1', featuredSha: 'f1');
      final p = fixtures.providerFor(service);
      await p.loadTrips();
      p.updateTrip(0, {...p.trips[0], 'title': 'Ready A', 'name': 'Ready A'});
      p.deleteTrip(1);
      expect((await p.saveTrips(selectedTripIds: {'a'})).success, true);
      expect(
        TripsParser.parseTripsData(
          service.atomicCalls.single.files[fixtures.tripsPath]!,
        ),
        hasLength(2),
      );
      expect(p.intentionalDeletedIds, {'b'});
      expect(p.changes.keys, {'b'});
      p.dispose();
    },
  );
  test(
    'bulk edits and duplication are undoable drafts with safe visibility',
    () async {
      final service = fixtures.FakeGitHubService()
        ..queueSnapshot(
          [fixtures.trip('a', title: 'A'), fixtures.trip('b', title: 'B')],
          tripsSha: 't1',
          featuredSha: 'f1',
        );
      final p = fixtures.providerFor(service);
      await p.loadTrips();
      final previous = p.trips[1]['availableDates'];
      p.applyBulkDates({'a'}, 'Oct 16-18, 2026');
      expect(p.trips[0]['availableDates'], contains('Oct 16-18, 2026'));
      expect(p.trips[1]['availableDates'], previous);
      p.undo();
      expect(p.changes, isEmpty);
      final id = p.duplicateTrip('a');
      final copy = p.getTripById(id!)!;
      expect(copy['isActive'], false);
      expect(copy['featured'], false);
      expect(copy['availableDates'], isEmpty);
      expect(copy['publicSlug'], id);
      expect(copy.containsKey('previousSlugs'), false);
      p.undo();
      expect(p.trips, hasLength(2));
      expect(service.atomicCalls, isEmpty);
      p.dispose();
    },
  );
  test(
    'configuration recovery merges independent changes but blocks conflicting lists',
    () {
      final base = {
            'hero': {'title': 'Original'},
            'reviews': ['A'],
          },
          local = {
            'hero': {'title': 'Local'},
            'reviews': ['A'],
          },
          remote = {
            'hero': {'title': 'Original'},
            'reviews': ['A', 'B'],
          };
      expect(recoverDocument(base, local, remote), {
        'hero': {'title': 'Local'},
        'reviews': ['A', 'B'],
      });
      expect(
        () => recoverDocument(base, {
          'hero': {'title': 'Local'},
          'reviews': ['C'],
        }, remote),
        throwsStateError,
      );
      expect(WorkspaceChanges.diff(base, local).single.path, 'hero.title');
    },
  );
}
