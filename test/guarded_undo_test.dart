import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/providers/trips_provider.dart';
import 'trips_provider_publication_test.dart' as fixtures;

void main() {
  test('deletion undo restores its trip but cannot undo a later edit', () async {
    final service = fixtures.FakeGitHubService()
      ..queueSnapshot([fixtures.trip('a'), fixtures.trip('b')], tripsSha: 't1', featuredSha: 'f1');
    final provider = TripsProvider(service.settings, serviceFactory: (_) => service);
    await provider.loadTrips();
    provider.deleteTrip(provider.getTripIndexById('a')!);
    final firstToken = provider.undoToken;
    expect(provider.undoIfCurrent(firstToken), true);
    expect(provider.getTripById('a'), isNotNull);
    expect(provider.undoIfCurrent(firstToken), false);
    provider.deleteTrip(provider.getTripIndexById('a')!);
    final secondToken = provider.undoToken;
    provider.updateTrip(0, {...provider.trips.first, 'title': 'Later edit'});
    expect(provider.undoIfCurrent(secondToken), false);
    expect(provider.getTripById('a'), isNull);
    expect(provider.trips.first['title'], 'Later edit');
    provider.dispose();
  });
}
