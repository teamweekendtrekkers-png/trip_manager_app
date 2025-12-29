/// Trip model representing a travel package
class Trip {
  final String id;
  final String name;
  final String destination;
  final String description;
  final String date;
  final double price;
  final double? discountedPrice;
  final String imageUrl;
  final List<String> highlights;
  final List<ItineraryDay> itinerary;
  final List<String> inclusions;
  final List<String> exclusions;
  final String difficulty;
  final int groupSize;
  final String pickupPoint;
  final bool featured;

  Trip({
    required this.id,
    required this.name,
    required this.destination,
    required this.description,
    required this.date,
    required this.price,
    this.discountedPrice,
    required this.imageUrl,
    required this.highlights,
    required this.itinerary,
    required this.inclusions,
    required this.exclusions,
    required this.difficulty,
    required this.groupSize,
    required this.pickupPoint,
    this.featured = false,
  });

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      destination: map['destination'] ?? '',
      description: map['description'] ?? '',
      date: map['date'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      discountedPrice: map['discountedPrice']?.toDouble(),
      imageUrl: map['image'] ?? '',
      highlights: List<String>.from(map['highlights'] ?? []),
      itinerary: (map['itinerary'] as List<dynamic>?)
          ?.map((e) => ItineraryDay.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      inclusions: List<String>.from(map['inclusions'] ?? []),
      exclusions: List<String>.from(map['exclusions'] ?? []),
      difficulty: map['difficulty'] ?? 'Moderate',
      groupSize: map['groupSize'] ?? 20,
      pickupPoint: map['pickupPoint'] ?? '',
      featured: map['featured'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'destination': destination,
      'description': description,
      'date': date,
      'price': price,
      if (discountedPrice != null) 'discountedPrice': discountedPrice,
      'image': imageUrl,
      'highlights': highlights,
      'itinerary': itinerary.map((e) => e.toMap()).toList(),
      'inclusions': inclusions,
      'exclusions': exclusions,
      'difficulty': difficulty,
      'groupSize': groupSize,
      'pickupPoint': pickupPoint,
      'featured': featured,
    };
  }

  bool get hasDiscount => discountedPrice != null && discountedPrice! < price;

  double get discountPercentage {
    if (!hasDiscount) return 0;
    return ((price - discountedPrice!) / price * 100).roundToDouble();
  }
}

class ItineraryDay {
  final int day;
  final String title;
  final String description;

  ItineraryDay({
    required this.day,
    required this.title,
    required this.description,
  });

  factory ItineraryDay.fromMap(Map<String, dynamic> map) {
    return ItineraryDay(
      day: map['day'] ?? 1,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'title': title,
      'description': description,
    };
  }
}
