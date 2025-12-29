# Trip Manager App - Flutter Mobile Application

## Project Overview
A Flutter mobile app (Android & iOS) for managing the Team Weekend Trekkers travel booking website. This is the mobile version of the Python desktop trip-manager.py admin tool.

## Tech Stack
- **Framework**: Flutter 3.x
- **State Management**: Provider
- **HTTP Client**: dio
- **Local Storage**: shared_preferences, hive
- **Image Handling**: image_picker, flutter_image_compress
- **GitHub Integration**: GitHub REST API via dio

## Architecture
Clean Architecture with feature-based folder structure:
```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── routes.dart
│   └── theme.dart
├── core/
│   ├── constants/
│   ├── services/
│   └── utils/
├── data/
│   ├── models/
│   └── repositories/
└── features/
    ├── trips/
    ├── featured/
    ├── photos/
    └── deploy/
```

## Data Models
- **Trip**: id, title, location, badge, price, image, duration, difficulty, availableDates, highlights, includes, excludes, itinerary
- **ItineraryDay**: day, title, activities
- **FeaturedTrips**: tripIds list

## Key Features
1. Trip CRUD operations
2. Date picker with range selection
3. Itinerary builder
4. Featured trips management
5. Photo upload to GitHub
6. Deploy changes to GitHub

## GitHub Integration
- Uses Personal Access Token for authentication
- Reads/writes to js/trips-data.js
- Commits and pushes changes

## UI Theme
Dark theme matching the desktop app:
- Background: #1a1a2e
- Card: #0f3460
- Accent: #e94560
- Text: #ffffff
