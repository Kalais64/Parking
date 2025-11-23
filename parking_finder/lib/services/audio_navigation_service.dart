import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/voice_service.dart';
import '../services/location_service.dart';
import '../models/parking_location.dart';
import '../models/user_location.dart';

class NavigationStep {
  final String instruction;
  final double distance; // in meters
  final Duration duration;
  final double latitude;
  final double longitude;
  final String? streetName;

  NavigationStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.latitude,
    required this.longitude,
    this.streetName,
  });
}

class AudioNavigationService extends ChangeNotifier {
  final VoiceService _voiceService;
  final LocationService _locationService;

  bool _isNavigating = false;
  ParkingLocation? _destination;
  List<NavigationStep> _navigationSteps = [];
  int _currentStepIndex = 0;
  Timer? _navigationTimer;
  StreamSubscription? _locationSubscription;

  // Audio guidance settings
  bool _isAudioEnabled = true;
  double _audioVolume = 0.8;
  String _language = 'id-ID';
  double _announcementDistance = 100.0; // meters before turn

  // Getters
  bool get isNavigating => _isNavigating;
  ParkingLocation? get destination => _destination;
  List<NavigationStep> get navigationSteps => _navigationSteps;
  NavigationStep? get currentStep => _currentStepIndex < _navigationSteps.length 
      ? _navigationSteps[_currentStepIndex] 
      : null;
  bool get isAudioEnabled => _isAudioEnabled;
  double get audioVolume => _audioVolume;
  String get language => _language;

  AudioNavigationService({
    required VoiceService voiceService,
    required LocationService locationService,
  }) : _voiceService = voiceService,
       _locationService = locationService;

  Future<void> startNavigation(ParkingLocation destination) async {
    if (_isNavigating) {
      await stopNavigation();
    }

    _destination = destination;
    _isNavigating = true;
    _currentStepIndex = 0;

    // Generate navigation steps (simplified for demo)
    await _generateNavigationSteps(destination);

    // Start location tracking
    await _startLocationTracking();

    // Play initial navigation instruction
    if (_navigationSteps.isNotEmpty) {
      await _playInitialInstruction();
    }

    notifyListeners();
  }

  Future<void> stopNavigation() async {
    _isNavigating = false;
    _destination = null;
    _navigationSteps.clear();
    _currentStepIndex = 0;

    // Stop location tracking
    await _stopLocationTracking();

    // Stop any ongoing audio
    await _voiceService.stopSpeaking();

    notifyListeners();
  }

  void toggleAudio() {
    _isAudioEnabled = !_isAudioEnabled;
    notifyListeners();
    
    if (_isAudioEnabled && _isNavigating) {
      _voiceService.playFeedback('Panduan audio diaktifkan');
    } else if (!_isAudioEnabled) {
      _voiceService.stopSpeaking();
    }
  }

  void setVolume(double volume) {
    _audioVolume = volume.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setLanguage(String language) {
    _language = language;
    notifyListeners();
  }

  Future<void> _generateNavigationSteps(ParkingLocation destination) async {
    // This is a simplified navigation step generation
    // In a real app, you would integrate with a routing service like Google Directions API
    
    try {
      final currentLocation = await _locationService.getCurrentLocation();
      if (currentLocation == null) {
        await _voiceService.playFeedback('Maaf, tidak dapat mendapatkan lokasi Anda saat ini');
        return;
      }
      
      // Calculate distance and basic route
      final distance = _calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        destination.coordinates.latitude,
        destination.coordinates.longitude,
      );

      final estimatedDuration = Duration(minutes: (distance / 500).round()); // Assume 500m per minute

      // Generate simplified steps
      _navigationSteps = [
        NavigationStep(
          instruction: 'Mulai navigasi ke ${destination.name}',
          distance: distance,
          duration: estimatedDuration,
          latitude: currentLocation.latitude,
          longitude: currentLocation.longitude,
        ),
        NavigationStep(
          instruction: 'Tetap di jalur ini',
          distance: distance * 0.7,
          duration: Duration(minutes: (estimatedDuration.inMinutes * 0.7).round()),
          latitude: currentLocation.latitude + (destination.coordinates.latitude - currentLocation.latitude) * 0.3,
          longitude: currentLocation.longitude + (destination.coordinates.longitude - currentLocation.longitude) * 0.3,
        ),
        NavigationStep(
          instruction: 'Anda mendekati tujuan',
          distance: distance * 0.3,
          duration: Duration(minutes: (estimatedDuration.inMinutes * 0.3).round()),
          latitude: currentLocation.latitude + (destination.coordinates.latitude - currentLocation.latitude) * 0.7,
          longitude: currentLocation.longitude + (destination.coordinates.longitude - currentLocation.longitude) * 0.7,
        ),
        NavigationStep(
          instruction: 'Anda telah sampai di ${destination.name}',
          distance: 0,
          duration: Duration.zero,
          latitude: destination.coordinates.latitude,
          longitude: destination.coordinates.longitude,
        ),
      ];
    } catch (e) {
      // Fallback to simple steps
      _navigationSteps = [
        NavigationStep(
          instruction: 'Navigasi ke ${destination.name}',
          distance: 1000, // Default 1km
          duration: const Duration(minutes: 5),
          latitude: destination.coordinates.latitude,
          longitude: destination.coordinates.longitude,
        ),
      ];
    }
  }

  Future<void> _startLocationTracking() async {
    // Track location every 5 seconds
    _navigationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkNavigationProgress();
    });

    // Also listen to location stream for more frequent updates
    _locationSubscription = _locationService.locationStream.listen((location) {
      _updateNavigationWithLocation(location);
    });
  }

  Future<void> _stopLocationTracking() async {
    _navigationTimer?.cancel();
    _navigationTimer = null;
    
    await _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  void _checkNavigationProgress() {
    if (!_isNavigating || _navigationSteps.isEmpty) return;

    final currentStep = _navigationSteps[_currentStepIndex];
    
    // Check if we should announce the next instruction
    if (currentStep.distance <= _announcementDistance && _currentStepIndex < _navigationSteps.length - 1) {
      _announceNextInstruction();
    }

    // Check if we've arrived
    if (_currentStepIndex >= _navigationSteps.length - 1) {
      _onArrival();
    }
  }

  void _updateNavigationWithLocation(UserLocation currentLocation) {
    if (!_isNavigating || _navigationSteps.isEmpty) return;

    // Update distances to next steps
    for (int i = _currentStepIndex; i < _navigationSteps.length; i++) {
      final step = _navigationSteps[i];
      final distance = _calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        step.latitude,
        step.longitude,
      );

      // Update step distance
      _navigationSteps[i] = NavigationStep(
        instruction: step.instruction,
        distance: distance,
        duration: step.duration,
        latitude: step.latitude,
        longitude: step.longitude,
        streetName: step.streetName,
      );
    }

    // Check if we've passed the current step
    if (_currentStepIndex < _navigationSteps.length - 1) {
      final nextStep = _navigationSteps[_currentStepIndex + 1];
      final distanceToNext = _calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        nextStep.latitude,
        nextStep.longitude,
      );

      if (distanceToNext < 20) { // 20 meters threshold
        _currentStepIndex++;
        _announceNextInstruction();
        notifyListeners();
      }
    }
  }

  Future<void> _playInitialInstruction() async {
    if (!_isAudioEnabled) return;

    final currentStep = _navigationSteps[_currentStepIndex];
    await _voiceService.playNavigationInstruction(
      currentStep.instruction,
      distance: currentStep.distance,
    );
  }

  Future<void> _announceNextInstruction() async {
    if (!_isAudioEnabled) return;

    if (_currentStepIndex < _navigationSteps.length) {
      final currentStep = _navigationSteps[_currentStepIndex];
      
      // Customize instruction based on distance
      String instruction = currentStep.instruction;
      
      if (currentStep.distance < 50) {
        instruction = 'Anda telah sampai di tujuan';
      } else if (currentStep.distance < 100) {
        instruction = currentStep.instruction.replaceAll('Anda mendekati', 'Sekarang dekat dengan');
      }

      await _voiceService.playNavigationInstruction(
        instruction,
        distance: currentStep.distance,
      );
    }
  }

  Future<void> _onArrival() async {
    if (_isAudioEnabled) {
      await _voiceService.playFeedback('Anda telah sampai di tujuan. Navigasi selesai.');
    }
    
    // Stop navigation after a short delay
    Future.delayed(const Duration(seconds: 3), () {
      if (_isNavigating) {
        stopNavigation();
      }
    });
  }

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

  // Public method to manually trigger instruction
  Future<void> repeatCurrentInstruction() async {
    if (_isNavigating && _currentStepIndex < _navigationSteps.length) {
      await _announceNextInstruction();
    }
  }

  // Get remaining distance and time
  Map<String, dynamic> getRemainingNavigationInfo() {
    if (!_isNavigating || _navigationSteps.isEmpty) {
      return {
        'distance': 0.0,
        'duration': Duration.zero,
        'stepsRemaining': 0,
      };
    }

    double totalDistance = 0;
    Duration totalDuration = Duration.zero;

    for (int i = _currentStepIndex; i < _navigationSteps.length; i++) {
      totalDistance += _navigationSteps[i].distance;
      totalDuration += _navigationSteps[i].duration;
    }

    return {
      'distance': totalDistance,
      'duration': totalDuration,
      'stepsRemaining': _navigationSteps.length - _currentStepIndex,
    };
  }
}