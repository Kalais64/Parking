import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_service.dart';
import '../services/voice_command_processor.dart';
import '../services/audio_navigation_service.dart';
import '../services/location_service.dart';
import '../services/map_service.dart';
import '../models/parking_location.dart';

class VoiceIntegrationManager extends ChangeNotifier {
  late VoiceService _voiceService;
  late VoiceCommandProcessor _commandProcessor;
  late AudioNavigationService _audioNavigationService;
  late LocationService _locationService;
  late MapService _mapService;

  bool _isVoiceSystemInitialized = false;
  bool _isVoiceSearchActive = false;
  String _lastVoiceCommand = '';
  ParkingLocation? _lastFoundLocation;

  // Getters
  bool get isVoiceSystemInitialized => _isVoiceSystemInitialized;
  bool get isVoiceSearchActive => _isVoiceSearchActive;
  String get lastVoiceCommand => _lastVoiceCommand;
  ParkingLocation? get lastFoundLocation => _lastFoundLocation;
  VoiceService get voiceService => _voiceService;
  AudioNavigationService get audioNavigationService => _audioNavigationService;

  // Stream controllers for UI updates
  final StreamController<bool> _voiceSearchStateController = StreamController.broadcast();
  Stream<bool> get voiceSearchStateStream => _voiceSearchStateController.stream;

  final StreamController<ParkingLocation?> _foundLocationController = StreamController.broadcast();
  Stream<ParkingLocation?> get foundLocationStream => _foundLocationController.stream;

  Future<void> initialize(BuildContext context) async {
    if (_isVoiceSystemInitialized) return;

    try {
      // Initialize services
      _voiceService = Provider.of<VoiceService>(context, listen: false);
      _locationService = Provider.of<LocationService>(context, listen: false);
      _mapService = MapService(); // Static service

      // Initialize voice service
      await _voiceService.initialize();

      // Initialize command processor
      _commandProcessor = VoiceCommandProcessor(
        voiceService: _voiceService,
        locationService: _locationService,
        mapService: _mapService,
      );
      _commandProcessor.initialize();

      // Initialize audio navigation service
      _audioNavigationService = AudioNavigationService(
        voiceService: _voiceService,
        locationService: _locationService,
      );

      // Subscribe to voice commands
      _voiceService.commandStream.listen(_onVoiceCommandReceived);

      _isVoiceSystemInitialized = true;
      notifyListeners();

      // Play welcome message
      await _voiceService.playFeedback('Sistem suara siap digunakan. Tekan tombol mikrofon untuk mulai mencari tempat parkir.');
    } catch (e) {
      debugPrint('Failed to initialize voice system: $e');
      _isVoiceSystemInitialized = false;
      notifyListeners();
    }
  }

  void _onVoiceCommandReceived(VoiceCommandResult command) {
    _lastVoiceCommand = command.recognizedText;
    _isVoiceSearchActive = false;
    _voiceSearchStateController.add(false);
    notifyListeners();

    // Process the command result
    _processCommandResult(command);
  }

  Future<void> _processCommandResult(VoiceCommandResult command) async {
    try {
      // Handle different command types
      switch (command.command) {
        case NavigationCommand.findParking:
        case NavigationCommand.findMotorcycleParking:
        case NavigationCommand.findCarParking:
        case NavigationCommand.findNearestParking:
          await _handleParkingSearchCommand(command);
          break;
        case NavigationCommand.navigateToExit:
          await _handleExitNavigationCommand(command);
          break;
        case NavigationCommand.navigateToMall:
          await _handleMallNavigationCommand(command);
          break;
        case NavigationCommand.unknown:
          await _handleUnknownCommand(command);
          break;
      }
    } catch (e) {
      await _voiceService.playFeedback('Maaf, terjadi kesalahan saat memproses perintah Anda');
    }
  }

  Future<void> _handleParkingSearchCommand(VoiceCommandResult command) async {
    try {
      final currentLocation = await _locationService.getCurrentLocation();
      if (currentLocation == null) {
        await _voiceService.playFeedback('Maaf, tidak dapat mendapatkan lokasi Anda saat ini');
        return;
      }
      
      String? vehicleType;
      if (command.command == NavigationCommand.findMotorcycleParking) {
        vehicleType = 'motorcycle';
      } else if (command.command == NavigationCommand.findCarParking) {
        vehicleType = 'car';
      }

      final parkingLocations = await MapService.searchNearbyParking(
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
        radius: 2000,
        vehicleType: vehicleType,
        maxResults: 5,
      );

      if (parkingLocations.isEmpty) {
        await _voiceService.playFeedback('Maaf, tidak ditemukan tempat parkir di sekitar Anda');
        return;
      }

      // Find the nearest parking location
      final nearestParking = parkingLocations.first;
      final distance = _calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        nearestParking.coordinates.latitude,
        nearestParking.coordinates.longitude,
      );

      // Store the found location
      _lastFoundLocation = nearestParking;
      _foundLocationController.add(nearestParking);

      // Provide audio feedback
      await _voiceService.playFeedback(
        'Menemukan ${parkingLocations.length} tempat parkir. '
        'Yang terdekat adalah ${nearestParking.name} sejauh ${distance.round()} meter'
      );

      // Optionally start navigation
      await Future.delayed(const Duration(seconds: 2));
      await _startNavigationToLocation(nearestParking);

    } catch (e) {
      await _voiceService.playFeedback('Maaf, tidak dapat menemukan tempat parkir saat ini');
    }
  }

  Future<void> _handleExitNavigationCommand(VoiceCommandResult command) async {
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

      _lastFoundLocation = exitLocation;
      _foundLocationController.add(exitLocation);

      await _voiceService.playFeedback(
        'Pintu keluar terdekat adalah ${exitLocation.name} sejauh ${distance.round()} meter'
      );

      await Future.delayed(const Duration(seconds: 2));
      await _startNavigationToLocation(exitLocation);

    } catch (e) {
      await _voiceService.playFeedback('Maaf, tidak dapat menemukan pintu keluar saat ini');
    }
  }

  Future<void> _handleMallNavigationCommand(VoiceCommandResult command) async {
    final location = command.location;
    
    if (location == null || location.isEmpty) {
      await _voiceService.playFeedback('Maaf, saya tidak menangkap nama mall yang Anda maksud');
      return;
    }

    try {
      final mallLocation = await MapService.searchMallByName(location);

      if (mallLocation == null) {
        await _voiceService.playFeedback('Maaf, tidak ditemukan mall dengan nama $location');
        return;
      }

      final currentLocation = await _locationService.getCurrentLocation();
      if (currentLocation == null) {
        await _voiceService.playFeedback('Maaf, tidak dapat mendapatkan lokasi Anda saat ini');
        return;
      }
      final distance = _calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        mallLocation.coordinates.latitude,
        mallLocation.coordinates.longitude,
      );

      _lastFoundLocation = mallLocation;
      _foundLocationController.add(mallLocation);

      await _voiceService.playFeedback(
        'Menemukan ${mallLocation.name} sejauh ${distance.round()} meter'
      );

      await Future.delayed(const Duration(seconds: 2));
      await _startNavigationToLocation(mallLocation);

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

  Future<void> _startNavigationToLocation(ParkingLocation location) async {
    try {
      await _audioNavigationService.startNavigation(location);
      
      // Provide navigation feedback
      await _voiceService.playFeedback(
        'Memulai navigasi ke ${location.name}. Ikuti panduan audio untuk sampai ke tujuan.'
      );
    } catch (e) {
      await _voiceService.playFeedback('Maaf, tidak dapat memulai navigasi saat ini');
    }
  }

  // Public methods for UI interaction
  Future<void> startVoiceSearch() async {
    if (!_isVoiceSystemInitialized) {
      await _voiceService.playFeedback('Sistem suara belum siap. Silakan coba lagi.');
      return;
    }

    _isVoiceSearchActive = true;
    _voiceSearchStateController.add(true);
    notifyListeners();

    await _voiceService.startListening();
  }

  Future<void> stopVoiceSearch() async {
    _isVoiceSearchActive = false;
    _voiceSearchStateController.add(false);
    notifyListeners();

    await _voiceService.stopListening();
  }

  void toggleAudioNavigation() {
    _audioNavigationService.toggleAudio();
  }

  void setAudioVolume(double volume) {
    _audioNavigationService.setVolume(volume);
  }

  void setLanguage(String language) {
    _voiceService.setLanguage(language);
    _audioNavigationService.setLanguage(language);
  }

  // Utility method
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
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

  @override
  void dispose() {
    _commandProcessor.dispose();
    _voiceSearchStateController.close();
    _foundLocationController.close();
    super.dispose();
  }
}