import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/services/trips_parser.dart';

const _fixture = '''// retained prefix
const tripsData = {
  netravati: {
    title: "Netravati Peak Trek",
    location: "Western Ghats, Karnataka",
    badge: "Weekend Trek",
    featured: true,
    price: "₹4000",
    image: "images/trips/netravati.jpg",
    distance: "15-20 km",
    elevation: "1,420 m",
    difficulty: "Moderate",
    bestTime: "Oct - Feb",
    duration: "2D/1N",
    availableDates: ["Jan 18-19, 2026", "Jan 25-26, 2026"],
    about: "Line one.\\nLine two.",
    highlights: ["Hidden waterfalls", "Night camping"],
    itinerary: [
      {day: "Day 0", title: "Departure", activities: ["Pickup", "Journey"]},
      {day: "Day 1", title: "Trek", activities: ["Breakfast", "Summit"]},
    ],
    includes: ["Transport", "Meals"],
    excludes: ["Personal expenses"],
    thingsToCarry: ["Shoes"],
    boardingLocations: [
      {name: "Majestic", landmark: "Metro", time: "9 PM", mapLink: "https://maps.test"},
    ],
    galleryImages: ["images/gallery/netravati/one.jpg"],
    groupSize: "15-20",
    isActive: true,
  },
  "nandi-hills": {
    title: "Nandi Hills Sunrise",
    location: "Bangalore Rural",
    badge: "Day Trip",
    featured: false,
    price: "₹1,499",
    image: "images/trips/nandi-hills.jpg",
    distance: "60 km",
    elevation: "1,478 m",
    difficulty: "Easy",
    bestTime: "Year round",
    duration: "1 Day",
    availableDates: [],
    about: "Sunrise trip.",
    highlights: [],
    itinerary: [],
    includes: [],
    excludes: [],
    thingsToCarry: [],
    boardingLocations: [],
    galleryImages: [],
    groupSize: "15-20",
    isActive: false,
  },
};
// retained suffix
function getTripData(id) { return tripsData[id]; }
''';

void main() {
  group('TripsParser characterization', () {
    test('parses identifiers, aliases, nested editor data, and defaults', () {
      final parsed = TripsParser.parseTripsDocument(_fixture);

      expect(parsed.isValid, isTrue, reason: parsed.errors.join('\n'));
      expect(parsed.trips, hasLength(2));
      final first = parsed.trips.first;
      expect(first['id'], 'netravati');
      expect(first['name'], first['title']);
      expect(first['destination'], first['location']);
      expect(first['date'], 'Jan 18-19, 2026');
      expect(first['priceNumeric'], 4000);
      expect(first['featured'], isTrue);
      expect(first['isActive'], isTrue);
      expect(first['itinerary'], hasLength(2));
      expect(first['inclusions'], ['Transport', 'Meals']);
      expect(first['exclusions'], ['Personal expenses']);
      expect(first['boardingLocations'], hasLength(1));
      expect(first['galleryImages'], hasLength(1));
      expect(parsed.trips.last['id'], 'nandi-hills');
      expect(parsed.trips.last['isActive'], isFalse);
    });

    test('source-preserving update retains helpers and all parsed values', () {
      final before = TripsParser.parseTripsDocument(_fixture);
      final write = TripsParser.replaceTripsDataObject(
        source: _fixture,
        trips: before.trips,
      );

      expect(write.success, isTrue, reason: write.error);
      final after = TripsParser.parseTripsDocument(write.content!);
      expect(after.isValid, isTrue, reason: after.errors.join('\n'));
      expect(after.trips, before.trips);
      expect(after.document!.prefix, before.document!.prefix);
      expect(after.document!.suffix, before.document!.suffix);
    });

    test('generator accepts numeric legacy values and quotes unsafe IDs', () {
      final generated = TripsParser.generateTripsDataJs([
        {
          ...TripsParser.parseTripsData(_fixture).first,
          'id': 'numeric-trip',
          'price': 1000,
          'groupSize': 20,
        },
      ]);

      expect(generated, contains('"numeric-trip":'));
      expect(generated, contains('price: "1000"'));
      expect(generated, contains('groupSize: "20"'));
    });
  });
}
