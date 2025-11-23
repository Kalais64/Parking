import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/parking_location.dart';

class MapService {
  static const String _googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY_HERE';
  
  // Get Google Maps API Key
  static String get apiKey => _googleMapsApiKey;
  
  // Calculate distance between two points
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // Convert to kilometers
  }
  
  // Calculate walking time (assuming 5 km/h walking speed)
  static int calculateWalkingTime(double distanceKm) {
    return (distanceKm / 5 * 60).round(); // minutes
  }
  
  // Calculate driving time (assuming 30 km/h driving speed in city)
  static int calculateDrivingTime(double distanceKm) {
    return (distanceKm / 30 * 60).round(); // minutes
  }
  
  // Get directions between two points
  static Future<List<LatLng>> getDirections(LatLng origin, LatLng destination) async {
    // This would typically call Google Directions API
    // For now, return a straight line between the points
    return [origin, destination];
  }
  
  // Get nearby places using Google Places API
  static Future<List<dynamic>> getNearbyPlaces(LatLng location, String type, int radius) async {
    // This would typically call Google Places API
    // For now, return empty list - to be implemented with actual API
    return [];
  }
  
  // Get place details using Google Places API
  static Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    // This would typically call Google Places Details API
    // For now, return null - to be implemented with actual API
    return null;
  }
  
  // Geocode address to coordinates
  static Future<LatLng?> geocodeAddress(String address) async {
    // This would typically call Google Geocoding API
    // For now, return null - to be implemented with actual API
    return null;
  }
  
  // Reverse geocode coordinates to address
  static Future<String?> reverseGeocode(LatLng coordinates) async {
    // This would typically call Google Geocoding API
    // For now, return null - to be implemented with actual API
    return null;
  }
  
  // Get optimal route with waypoints
  static Future<List<LatLng>> getOptimalRoute(List<LatLng> waypoints) async {
    // This would typically call Google Directions API with waypoints
    // For now, return the waypoints as-is - to be implemented with actual API
    return waypoints;
  }
  
  // Check if location is within bounds
  static bool isLocationWithinBounds(LatLng location, LatLng northeast, LatLng southwest) {
    return location.latitude >= southwest.latitude && 
           location.latitude <= northeast.latitude &&
           location.longitude >= southwest.longitude && 
           location.longitude <= northeast.longitude;
  }
  
  // Get bounds from list of locations
  static Map<String, LatLng> getBoundsFromLocations(List<LatLng> locations) {
    if (locations.isEmpty) {
      return {
        'northeast': const LatLng(0, 0),
        'southwest': const LatLng(0, 0),
      };
    }
    
    double minLat = locations[0].latitude;
    double maxLat = locations[0].latitude;
    double minLng = locations[0].longitude;
    double maxLng = locations[0].longitude;
    
    for (final location in locations) {
      minLat = location.latitude < minLat ? location.latitude : minLat;
      maxLat = location.latitude > maxLat ? location.latitude : maxLat;
      minLng = location.longitude < minLng ? location.longitude : minLng;
      maxLng = location.longitude > maxLng ? location.longitude : maxLng;
    }
    
    return {
      'northeast': LatLng(maxLat, maxLng),
      'southwest': LatLng(minLat, minLng),
    };
  }
  
  // Filter parking locations by distance
  static List<ParkingLocation> filterByDistance(
    List<ParkingLocation> locations, 
    LatLng center, 
    double maxDistanceKm
  ) {
    return locations.where((location) {
      final distance = calculateDistance(
        center.latitude,
        center.longitude,
        location.coordinates.latitude,
        location.coordinates.longitude,
      );
      return distance <= maxDistanceKm;
    }).toList();
  }
  
  // Sort parking locations by distance
  static List<ParkingLocation> sortByDistance(
    List<ParkingLocation> locations, 
    LatLng center
  ) {
    final sortedLocations = List<ParkingLocation>.from(locations);
    sortedLocations.sort((a, b) {
      final distanceA = calculateDistance(
        center.latitude,
        center.longitude,
        a.coordinates.latitude,
        a.coordinates.longitude,
      );
      final distanceB = calculateDistance(
        center.latitude,
        center.longitude,
        b.coordinates.latitude,
        b.coordinates.longitude,
      );
      return distanceA.compareTo(distanceB);
    });
    return sortedLocations;
  }

  // Voice search integration methods
  
  // Search nearby parking locations with voice command support
  static Future<List<ParkingLocation>> searchNearbyParking({
    required double latitude,
    required double longitude,
    int radius = 2000, // meters
    String? vehicleType, // 'car', 'motorcycle', or null for all
    int maxResults = 10,
  }) async {
    // This would typically call your backend API or Google Places API
    // For now, return mock data that matches the voice search requirements
    
    final mockParkingLocations = _generateMockParkingLocations();
    final center = LatLng(latitude, longitude);
    
    // Filter by distance
    final nearbyLocations = filterByDistance(mockParkingLocations, center, radius / 1000);
    
    // Filter by vehicle type if specified
    final filteredLocations = vehicleType != null 
        ? nearbyLocations.where((location) => 
            location.vehicleType.toLowerCase() == vehicleType.toLowerCase() ||
            location.vehicleType == 'both'
          ).toList()
        : nearbyLocations;
    
    // Sort by distance and limit results
    final sortedLocations = sortByDistance(filteredLocations, center);
    return sortedLocations.take(maxResults).toList();
  }

  // Find nearest exit point
  static Future<ParkingLocation?> findNearestExit({
    required double latitude,
    required double longitude,
  }) async {
    final mockExits = _generateMockExitLocations();
    final center = LatLng(latitude, longitude);
    
    if (mockExits.isEmpty) return null;
    
    final sortedExits = sortByDistance(mockExits, center);
    return sortedExits.first;
  }

  // Search mall by name for voice commands
  static Future<ParkingLocation?> searchMallByName(String mallName) async {
    final mockMalls = _generateMockMallLocations();
    
    // Simple name matching (case insensitive)
    final matchingMall = mockMalls.firstWhere(
      (mall) => mall.name.toLowerCase().contains(mallName.toLowerCase()),
      orElse: () => mockMalls.first,
    );
    
    return matchingMall;
  }

  // Mock data generators for voice search functionality
  
  static List<ParkingLocation> _generateMockParkingLocations() {
    return [
      ParkingLocation(
        id: '1',
        name: 'Parkir Basement Mall Central',
        address: 'Jl. Sudirman No. 1, Jakarta',
        coordinates: const LatLng(-6.2088, 106.8456),
        status: ParkingStatus.available,
        totalCapacity: 500,
        availableSpots: 125,
        pricePerHour: 5000,
        vehicleType: 'both',
        parkingType: 'indoor',
        securityLevel: 'high',
        hasCctv: true,
        isWellLit: true,
        rating: 4.5,
        distance: 0.5,
      ),
      ParkingLocation(
        id: '2',
        name: 'Parkir Motor Thamrin',
        address: 'Jl. Thamrin No. 10, Jakarta',
        coordinates: const LatLng(-6.2112, 106.8478),
        status: ParkingStatus.available,
        totalCapacity: 200,
        availableSpots: 45,
        pricePerHour: 3000,
        vehicleType: 'motorcycle',
        parkingType: 'outdoor',
        securityLevel: 'medium',
        hasCctv: true,
        isWellLit: true,
        rating: 4.2,
        distance: 0.8,
      ),
      ParkingLocation(
        id: '3',
        name: 'Parkir Mobil Plaza Indonesia',
        address: 'Jl. MH Thamrin No. 28, Jakarta',
        coordinates: const LatLng(-6.2095, 106.8198),
        status: ParkingStatus.available,
        totalCapacity: 800,
        availableSpots: 234,
        pricePerHour: 8000,
        vehicleType: 'car',
        parkingType: 'indoor',
        securityLevel: 'high',
        hasCctv: true,
        isWellLit: true,
        rating: 4.8,
        distance: 1.2,
      ),
      ParkingLocation(
        id: '4',
        name: 'Parkir Pintu Keluar Timur',
        address: 'Jl. Gatot Subroto No. 1, Jakarta',
        coordinates: const LatLng(-6.2255, 106.8292),
        status: ParkingStatus.available,
        totalCapacity: 150,
        availableSpots: 67,
        pricePerHour: 4000,
        vehicleType: 'both',
        parkingType: 'outdoor',
        securityLevel: 'medium',
        hasCctv: true,
        isWellLit: true,
        rating: 4.1,
        distance: 2.1,
      ),
      ParkingLocation(
        id: '5',
        name: 'Parkir Terdekat Senayan',
        address: 'Jl. Asia Afrika No. 8, Jakarta',
        coordinates: const LatLng(-6.2189, 106.8024),
        status: ParkingStatus.available,
        totalCapacity: 300,
        availableSpots: 89,
        pricePerHour: 6000,
        vehicleType: 'both',
        parkingType: 'both',
        securityLevel: 'high',
        hasCctv: true,
        isWellLit: true,
        rating: 4.3,
        distance: 0.3,
      ),
    ];
  }

  static List<ParkingLocation> _generateMockExitLocations() {
    return [
      ParkingLocation(
        id: 'exit_1',
        name: 'Pintu Keluar Barat',
        address: 'Jl. Sudirman Exit Barat',
        coordinates: const LatLng(-6.2088, 106.8446),
        status: ParkingStatus.available,
        totalCapacity: 0,
        availableSpots: 0,
        pricePerHour: 0,
        vehicleType: 'both',
        parkingType: 'outdoor',
        securityLevel: 'low',
        hasCctv: false,
        isWellLit: true,
        distance: 0.2,
      ),
      ParkingLocation(
        id: 'exit_2',
        name: 'Pintu Keluar Timur',
        address: 'Jl. Gatot Subroto Exit Timur',
        coordinates: const LatLng(-6.2255, 106.8292),
        status: ParkingStatus.available,
        totalCapacity: 0,
        availableSpots: 0,
        pricePerHour: 0,
        vehicleType: 'both',
        parkingType: 'outdoor',
        securityLevel: 'low',
        hasCctv: false,
        isWellLit: true,
        distance: 1.8,
      ),
    ];
  }

  static List<ParkingLocation> _generateMockMallLocations() {
    return [
      ParkingLocation(
        id: 'mall_1',
        name: 'Mall Central',
        address: 'Jl. Sudirman No. 1, Jakarta',
        coordinates: const LatLng(-6.2088, 106.8456),
        status: ParkingStatus.available,
        totalCapacity: 500,
        availableSpots: 125,
        pricePerHour: 5000,
        vehicleType: 'both',
        parkingType: 'indoor',
        securityLevel: 'high',
        hasCctv: true,
        isWellLit: true,
        rating: 4.5,
        distance: 0.5,
      ),
      ParkingLocation(
        id: 'mall_2',
        name: 'Plaza Indonesia',
        address: 'Jl. MH Thamrin No. 28, Jakarta',
        coordinates: const LatLng(-6.2095, 106.8198),
        status: ParkingStatus.available,
        totalCapacity: 800,
        availableSpots: 234,
        pricePerHour: 8000,
        vehicleType: 'car',
        parkingType: 'indoor',
        securityLevel: 'high',
        hasCctv: true,
        isWellLit: true,
        rating: 4.8,
        distance: 1.2,
      ),
    ];
  }
}