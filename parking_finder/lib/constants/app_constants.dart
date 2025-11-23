class AppConstants {
  // App Info
  static const String appName = 'Parking Finder';
  static const String appVersion = '1.0.0';
  
  // API Configuration
  static const String baseUrl = 'https://api.parkingfinder.com';
  static const int apiTimeout = 30; // seconds
  
  // Map Configuration
  static const double defaultZoom = 15.0;
  static const double minZoom = 10.0;
  static const double maxZoom = 20.0;
  static const double searchRadius = 2000; // meters
  
  // Location Configuration
  static const double locationUpdateInterval = 5000; // milliseconds
  static const double locationDistanceFilter = 10; // meters
  
  // Parking Status
  static const String statusAvailable = 'available';
  static const String statusGettingFull = 'getting_full';
  static const String statusFull = 'full';
  
  // Default Coordinates (Jakarta)
  static const double defaultLatitude = -6.2088;
  static const double defaultLongitude = 106.8456;
  
  // Cache Keys
  static const String keyUserLocation = 'user_location';
  static const String keyFavoriteSpots = 'favorite_spots';
  static const String keyUserProfile = 'user_profile';
  static const String keyParkingHistory = 'parking_history';
  
  // Notification Settings
  static const String channelId = 'parking_reminder';
  static const String channelName = 'Parking Reminders';
  static const String channelDescription = 'Notifications for parking reminders';
}