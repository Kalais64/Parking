import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/voice_service.dart';
import '../services/location_service.dart';
import '../services/map_service.dart';
import '../models/parking_location.dart';

class VoiceCommandProcessor {
  final VoiceService _voiceService;
  final LocationService _locationService;
  final MapService _mapService;

  VoiceCommandProcessor({
    required VoiceService voiceService,
    required LocationService locationService,
    required MapService mapService,
  }) : _voiceService = voiceService,
       _locationService = locationService,
       _mapService = mapService;

  StreamSubscription? _commandSubscription;

  void initialize() {
    // Subscribe to voice command stream
    _commandSubscription = _voiceService.commandStream.listen(_processVoiceCommand);
  }

  void dispose() {
    _commandSubscription?.cancel();
  }

  Future<void> _processVoiceCommand(VoiceCommandResult command) async {
    try {
      switch (command.command) {
        case NavigationCommand.findParking:
          await _handleFindParking(command);
          break;
        case NavigationCommand.findMotorcycleParking:
          await _handleFindMotorcycleParking(command);
          break;
        case NavigationCommand.findCarParking:
          await _handleFindCarParking(command);
          break;
        case NavigationCommand.findNearestParking:
          await _handleFindNearestParking(command);
          break;
        case NavigationCommand.navigateToExit:
          await _handleNavigateToExit(command);
          break;
        case NavigationCommand.navigateToMall:
          await _handleNavigateToMall(command);
          break;
        case NavigationCommand.unknown:
          await _handleUnknownCommand(command);
          break;
      }
    } catch (e) {
      await _voiceService.playFeedback('Maaf, terjadi kesalahan saat memproses perintah Anda');
    }
  }

  Future<void> _handleFindParking(VoiceCommandResult command) async {
    await _voiceService.playFeedback('Mencari tempat parkir untuk Anda...');
    
    try {
      final currentLocation = await _locationService.getCurrentLocation();
      if (currentLocation == null) {
        await _voiceService.playFeedback('Maaf, tidak dapat mendapatkan lokasi Anda saat ini');
        return;
      }
      final parkingLocations = await MapService.searchNearbyParking(
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
        radius: 2000, // 2km radius
      );

      if (parkingLocations.isEmpty) {
        await _voiceService.playFeedback('Maaf, tidak ditemukan tempat parkir di sekitar Anda');
        return;
      }

      // Find the nearest parking
      final nearestParking = parkingLocations.first;
      final distance = _calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        nearestParking.coordinates.latitude,
        nearestParking.coordinates.longitude,
      );

      await _voiceService.playFeedback(
        'Menemukan ${parkingLocations.length} tempat parkir. '
        'Yang terdekat adalah ${nearestParking.name} sejauh ${distance.round()} meter'
      );

      // Trigger navigation to the nearest parking
      _triggerNavigation(nearestParking);

    } catch (e) {
      await _voiceService.playFeedback('Maaf, tidak dapat menemukan tempat parkir saat ini');
    }
  }

  Future<void> _handleFindMotorcycleParking(VoiceCommandResult command) async {
    await _voiceService.playFeedback('Mencari tempat parkir motor untuk Anda...');
    
    try {
      final currentLocation = await _locationService.getCurrentLocation();
      if (currentLocation == null) {
        await _voiceService.playFeedback('Maaf, tidak dapat mendapatkan lokasi Anda saat ini');
        return;
      }
      final parkingLocations = await MapService.searchNearbyParking(
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
        radius: 2000,
        vehicleType: 'motorcycle',
      );

      if (parkingLocations.isEmpty) {
        await _voiceService.playFeedback('Maaf, tidak ditemukan tempat parkir motor di sekitar Anda');
        return;
      }

      final nearestParking = parkingLocations.first;
      final distance = _calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        nearestParking.coordinates.latitude,
        nearestParking.coordinates.longitude,
      );

      await _voiceService.playFeedback(
        'Menemukan ${parkingLocations.length} tempat parkir motor. '
        'Yang terdekat adalah ${nearestParking.name} sejauh ${distance.round()} meter'
      );

      _triggerNavigation(nearestParking);

    } catch (e) {
      await _voiceService.playFeedback('Maaf, tidak dapat menemukan tempat parkir motor saat ini');
    }
  }

  Future<void> _handleFindCarParking(VoiceCommandResult command) async {
    await _voiceService.playFeedback('Mencari tempat parkir mobil untuk Anda...');
    
    try {
      final currentLocation = await _locationService.getCurrentLocation();
      if (currentLocation == null) {
        await _voiceService.playFeedback('Maaf, tidak dapat mendapatkan lokasi Anda saat ini');
        return;
      }
      final parkingLocations = await MapService.searchNearbyParking(
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
        radius: 2000,
        vehicleType: 'car',
      );

      if (parkingLocations.isEmpty) {
        await _voiceService.playFeedback('Maaf, tidak ditemukan tempat parkir mobil di sekitar Anda');
        return;
      }

      final nearestParking = parkingLocations.first;
      final distance = _calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        nearestParking.coordinates.latitude,
        nearestParking.coordinates.longitude,
      );

      await _voiceService.playFeedback(
        'Menemukan ${parkingLocations.length} tempat parkir mobil. '
        'Yang terdekat adalah ${nearestParking.name} sejauh ${distance.round()} meter'
      );

      _triggerNavigation(nearestParking);

    } catch (e) {
      await _voiceService.playFeedback('Maaf, tidak dapat menemukan tempat parkir mobil saat ini');
    }
  }

  Future<void> _handleFindNearestParking(VoiceCommandResult command) async {
    await _voiceService.playFeedback('Mencari tempat parkir terdekat untuk Anda...');
    
    try {
      final currentLocation = await _locationService.getCurrentLocation();
      if (currentLocation == null) {
        await _voiceService.playFeedback('Maaf, tidak dapat mendapatkan lokasi Anda saat ini');
        return;
      }
      final parkingLocations = await MapService.searchNearbyParking(
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
        radius: 1000, // 1km radius for nearest search
      );

      if (parkingLocations.isEmpty) {
        await _voiceService.playFeedback('Maaf, tidak ditemukan tempat parkir di sekitar Anda');
        return;
      }

      final nearestParking = parkingLocations.first;
      final distance = _calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        nearestParking.coordinates.latitude,
        nearestParking.coordinates.longitude,
      );

      await _voiceService.playFeedback(
        'Tempat parkir terdekat adalah ${nearestParking.name} sejauh ${distance.round()} meter'
      );

      _triggerNavigation(nearestParking);

    } catch (e) {
      await _voiceService.playFeedback('Maaf, tidak dapat menemukan tempat parkir terdekat saat ini');
    }
  }

  Future<void> _handleNavigateToExit(VoiceCommandResult command) async {
    await _voiceService.playFeedback('Mencari pintu keluar terdekat untuk Anda...');
    
    try {
      final currentLocation = await _locationService.getCurrentLocation();
      if (currentLocation == null) {
        await _voiceService.playFeedback('Maaf, tidak dapat mendapatkan lokasi Anda saat ini');
        return;
      }
      final exitLocation = await MapService.findNearestExit(
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
      );

      if (exitLocation == null) {
        await _voiceService.playFeedback('Maaf, tidak ditemukan pintu keluar di sekitar Anda');
        return;
      }

      final distance = _calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        exitLocation.coordinates.latitude,
        exitLocation.coordinates.longitude,
      );

      await _voiceService.playFeedback(
        'Pintu keluar terdekat adalah ${exitLocation.name} sejauh ${distance.round()} meter'
      );

      _triggerNavigation(exitLocation);

    } catch (e) {
      await _voiceService.playFeedback('Maaf, tidak dapat menemukan pintu keluar saat ini');
    }
  }

  Future<void> _handleNavigateToMall(VoiceCommandResult command) async {
    final location = command.location;
    
    if (location == null || location.isEmpty) {
      await _voiceService.playFeedback('Maaf, saya tidak menangkap nama mall yang Anda maksud');
      return;
    }

    await _voiceService.playFeedback('Mencari $location untuk Anda...');
    
    try {
      final currentLocation = await _locationService.getCurrentLocation();
      if (currentLocation == null) {
        await _voiceService.playFeedback('Maaf, tidak dapat mendapatkan lokasi Anda saat ini');
        return;
      }
      final mallLocation = await MapService.searchMallByName(location);

      if (mallLocation == null) {
        await _voiceService.playFeedback('Maaf, tidak ditemukan mall dengan nama $location');
        return;
      }

      final distance = _calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        mallLocation.coordinates.latitude,
        mallLocation.coordinates.longitude,
      );

      await _voiceService.playFeedback(
        'Menemukan ${mallLocation.name} sejauh ${distance.round()} meter'
      );

      _triggerNavigation(mallLocation);

    } catch (e) {
      await _voiceService.playFeedback('Maaf, tidak dapat menemukan $location saat ini');
    }
  }

  Future<void> _handleUnknownCommand(VoiceCommandResult command) async {
    await _voiceService.playFeedback(
      'Maaf, saya tidak mengerti perintah "${command.recognizedText}". '
      'Coba katakan "cari parkir", "parkir motor", atau "navigasi ke pintu keluar"'
    );
  }

  void _triggerNavigation(ParkingLocation destination) {
    // This would integrate with your existing navigation system
    // For now, we'll provide audio feedback about the navigation
    _voiceService.playNavigationInstruction(
      'Memulai navigasi ke ${destination.name}',
      distance: null,
    );
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Haversine formula to calculate distance between two points
    const earthRadius = 6371000; // meters
    
    final lat1Rad = lat1 * math.pi / 180;
    final lat2Rad = lat2 * math.pi / 180;
    final deltaLat = (lat2 - lat1) * math.pi / 180;
    final deltaLon = (lon2 - lon1) * math.pi / 180;
    
    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
              math.cos(lat1Rad) * math.cos(lat2Rad) *
              math.sin(deltaLon / 2) * math.sin(deltaLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
}