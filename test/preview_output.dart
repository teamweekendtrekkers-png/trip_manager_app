import '../lib/services/trips_parser.dart';

void main() {
  final trip = {
    "id": "test-trip",
    "title": "Test Trip",
    "location": "Test Location", 
    "price": "₹5000",
    "badge": "Trek",
    "image": "images/trips/test.jpg",
    "difficulty": "Moderate",
    "distance": "10 km",
    "elevation": "1000 m",
    "bestTime": "Oct-Feb",
    "duration": "2D/1N",
    "availableDates": ["Jan 1-2"],
    "about": "Test description",
    "highlights": ["View", "Trek"],
    "itinerary": [
      {"day": "Day 1", "title": "Trek", "activities": ["6AM - Start", "12PM - Summit"]}
    ],
    "inclusions": ["Transport"],
    "exclusions": ["Food"],
    "groupSize": "20",
  };
  
  print(TripsParser.generateTripsDataJs([trip]));
}
