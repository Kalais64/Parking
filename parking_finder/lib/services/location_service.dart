import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as location_pkg;
import '../models/user_location.dart';
import '../constants/app_constants.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final location_pkg.Location _location = location_pkg.Location();
  final StreamController<UserLocation> _locationController = StreamController<UserLocation>.broadcast();
  Timer? _locationTimer;
  UserLocation? _currentLocation;

  // Stream of location updates
  Stream<UserLocation> get locationStream => _locationController.stream;
  
  // Current location getter
  UserLocation? get currentLocation => _currentLocation;

  // Initialize location service
  Future<bool> initialize() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          return false;
        }
      }

      location_pkg.PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == location_pkg.PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != location_pkg.PermissionStatus.granted) {
          return false;
        }
      }

      return true;
    } catch (e) {
      // Error initializing location service
      debugPrint('Error initializing location service: $e');
      return false;
    }
  }

  // Check if location services are enabled and permissions granted
  Future<bool> checkLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      // Error checking location permission
      debugPrint('Error checking location permission: $e');
      return false;
    }
  }

  // Get current location once
  Future<UserLocation?> getCurrentLocation() async {
    try {
      bool hasPermission = await checkLocationPermission();
      if (!hasPermission) {
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _currentLocation = UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        speed: position.speed,
        timestamp: DateTime.now(),
      );

      return _currentLocation;
    } catch (e) {
      // Error getting current location
      debugPrint('Error getting current location: $e');
      return null;
    }
  }

  // Start continuous location updates
  Future<void> startLocationUpdates() async {
    try {
      bool hasPermission = await checkLocationPermission();
      if (!hasPermission) {
        return;
      }

      // Get initial location
      await getCurrentLocation();
      if (_currentLocation != null) {
        _locationController.add(_currentLocation!);
      }

      // Start timer for periodic updates
    _locationTimer = Timer.periodic(
      Duration(milliseconds: AppConstants.locationUpdateInterval.toInt()),
      (timer) async {
        await _updateLocation();
      },
    );

      // Also listen to geolocator position stream
      Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: AppConstants.locationDistanceFilter.toInt(),
        ),
      ).listen((Position position) {
        _currentLocation = UserLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          altitude: position.altitude,
          speed: position.speed,
          timestamp: DateTime.now(),
        );
        _locationController.add(_currentLocation!);
      });

    } catch (e) {
      // Error starting location updates
      debugPrint('Error starting location updates: $e');
    }
  }

  // Stop location updates
  void stopLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  // Update location manually
  Future<void> _updateLocation() async {
    try {
      UserLocation? location = await getCurrentLocation();
      if (location != null && _locationController.hasListener) {
        _locationController.add(location);
      }
    } catch (e) {
      // Error updating location
      debugPrint('Error updating location: $e');
    }
  }

  // Calculate distance between two points
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  // Check if location is within radius
  bool isWithinRadius(double centerLat, double centerLng, double targetLat, double targetLng, double radius) {
    double distance = calculateDistance(centerLat, centerLng, targetLat, targetLng);
    return distance <= radius;
  }

  // Dispose resources
  void dispose() {
    stopLocationUpdates();
    _locationController.close();
  }
}