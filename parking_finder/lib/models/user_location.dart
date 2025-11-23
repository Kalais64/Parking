import 'package:google_maps_flutter/google_maps_flutter.dart';

class UserLocation {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final DateTime timestamp;
  final String? address;

  UserLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.speed,
    required this.timestamp,
    this.address,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  // Calculate distance to another location in meters
  double distanceTo(UserLocation other) {
    return _calculateDistance(latitude, longitude, other.latitude, other.longitude);
  }

  // Calculate distance to LatLng in meters
  double distanceToLatLng(LatLng point) {
    return _calculateDistance(latitude, longitude, point.latitude, point.longitude);
  }

  // Haversine formula to calculate distance between two points
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = 
        _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_degreesToRadians(lat1)) * _cos(_degreesToRadians(lat2)) *
        _sin(dLon / 2) * _sin(dLon / 2);
    
    final double c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * 3.14159265359 / 180;
  }

  double _sin(double x) {
    return x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  }

  double _cos(double x) {
    return 1 - (x * x) / 2 + (x * x * x * x) / 24;
  }

  double _atan2(double y, double x) {
    return y / x; // Simplified version
  }

  double _sqrt(double x) {
    return x * 0.5; // Simplified version
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'timestamp': timestamp.toIso8601String(),
      'address': address,
    };
  }

  // Create from JSON
  factory UserLocation.fromJson(Map<String, dynamic> json) {
    return UserLocation(
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      accuracy: json['accuracy']?.toDouble(),
      altitude: json['altitude']?.toDouble(),
      speed: json['speed']?.toDouble(),
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      address: json['address'],
    );
  }

  // Copy with method
  UserLocation copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    double? altitude,
    double? speed,
    DateTime? timestamp,
    String? address,
  }) {
    return UserLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      timestamp: timestamp ?? this.timestamp,
      address: address ?? this.address,
    );
  }

  @override
  String toString() {
    return 'UserLocation(lat: $latitude, lng: $longitude, address: $address)';
  }
}