import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

enum VoiceState {
  idle,
  listening,
  processing,
  speaking,
  error,
}

enum NavigationCommand {
  findParking,
  navigateToExit,
  findMotorcycleParking,
  findCarParking,
  findNearestParking,
  navigateToMall,
  unknown,
}

class VoiceCommandResult {
  final NavigationCommand command;
  final String recognizedText;
  final String? location;
  final Map<String, dynamic>? metadata;

  VoiceCommandResult({
    required this.command,
    required this.recognizedText,
    this.location,
    this.metadata,
  });
}

class VoiceService extends ChangeNotifier {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  VoiceState _currentState = VoiceState.idle;
  String _lastRecognizedText = '';
  String _lastError = '';
  bool _isAvailable = false;
  bool _isListening = false;
  double _soundLevel = 0.0;

  // Getters
  VoiceState get currentState => _currentState;
  String get lastRecognizedText => _lastRecognizedText;
  String get lastError => _lastError;
  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;
  double get soundLevel => _soundLevel;

  // Stream controllers
  final StreamController<VoiceCommandResult> _commandController = StreamController.broadcast();
  Stream<VoiceCommandResult> get commandStream => _commandController.stream;

  final StreamController<double> _soundLevelController = StreamController.broadcast();
  Stream<double> get soundLevelStream => _soundLevelController.stream;

  Future<void> initialize() async {
    try {
      // Initialize Speech-to-Text
      _isAvailable = await _speechToText.initialize(
        onError: (errorNotification) {
          _handleSpeechError(errorNotification.errorMsg);
        },
        onStatus: (status) {
          _handleSpeechStatus(status);
        },
      );

      // Initialize Text-to-Speech
      await _initializeTTS();

      if (!_isAvailable) {
        _lastError = 'Speech recognition not available';
        _currentState = VoiceState.error;
        notifyListeners();
      }
    } catch (e) {
      _lastError = 'Failed to initialize voice service: $e';
      _currentState = VoiceState.error;
      notifyListeners();
    }
  }

  Future<void> _initializeTTS() async {
    try {
      // Configure TTS settings
      await _flutterTts.setLanguage('id-ID'); // Indonesian as default
      await _flutterTts.setSpeechRate(0.5); // Slower speech for navigation
      await _flutterTts.setVolume(0.8);
      await _flutterTts.setPitch(1.0);

      // Set completion callback
      _flutterTts.setCompletionHandler(() {
        _currentState = VoiceState.idle;
        notifyListeners();
      });

      // Set error handler
      _flutterTts.setErrorHandler((message) {
        _lastError = 'TTS Error: $message';
        _currentState = VoiceState.error;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('TTS initialization error: $e');
    }
  }

  Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (e) {
      _lastError = 'Permission request failed: $e';
      _currentState = VoiceState.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> startListening() async {
    if (!_isAvailable) {
      await initialize();
    }

    if (!_isAvailable) {
      _lastError = 'Speech recognition not available';
      _currentState = VoiceState.error;
      notifyListeners();
      return;
    }

    // Check microphone permission
    final hasPermission = await requestMicrophonePermission();
    if (!hasPermission) {
      _lastError = 'Microphone permission denied';
      _currentState = VoiceState.error;
      notifyListeners();
      return;
    }

    try {
      _currentState = VoiceState.listening;
      _lastRecognizedText = '';
      _lastError = '';
      notifyListeners();

      await _speechToText.listen(
        onResult: (result) {
          _handleSpeechResult(result);
        },
        onSoundLevelChange: (level) {
          _soundLevel = level;
          _soundLevelController.add(level);
          notifyListeners();
        },
        listenFor: const Duration(seconds: 17), // Max listening duration
        pauseFor: const Duration(seconds: 3), // Pause detection
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.search, // Optimized for search queries
      );

      _isListening = true;
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to start listening: $e';
      _currentState = VoiceState.error;
      _isListening = false;
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
      _soundLevel = 0.0;
      _currentState = VoiceState.idle;
      notifyListeners();
    }
  }

  void _handleSpeechResult(result) {
    if (result.finalResult) {
      _lastRecognizedText = result.recognizedWords;
      _currentState = VoiceState.processing;
      notifyListeners();

      // Process the voice command
      _processVoiceCommand(_lastRecognizedText);
      
      _isListening = false;
      _soundLevel = 0.0;
      notifyListeners();
    } else if (result.recognizedWords.isNotEmpty) {
      // Update with partial results for real-time feedback
      _lastRecognizedText = result.recognizedWords;
      notifyListeners();
    }
  }

  void _handleSpeechError(String error) {
    _lastError = error;
    _currentState = VoiceState.error;
    _isListening = false;
    _soundLevel = 0.0;
    notifyListeners();
  }

  void _handleSpeechStatus(String status) {
    debugPrint('Speech recognition status: $status');
  }

  void _processVoiceCommand(String text) {
    try {
      final command = _parseVoiceCommand(text);
      final result = VoiceCommandResult(
        command: command,
        recognizedText: text,
        location: _extractLocation(text),
        metadata: _buildCommandMetadata(text, command),
      );

      _commandController.add(result);
      _currentState = VoiceState.idle;
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to process command: $e';
      _currentState = VoiceState.error;
      notifyListeners();
    }
  }

  NavigationCommand _parseVoiceCommand(String text) {
    final lowerText = text.toLowerCase();

    // Parking-related commands
    if (lowerText.contains('cari parkir') || 
        lowerText.contains('find parking') ||
        lowerText.contains('parkir terdekat')) {
      return NavigationCommand.findParking;
    }

    if (lowerText.contains('parkir motor') || 
        lowerText.contains('motorcycle parking')) {
      return NavigationCommand.findMotorcycleParking;
    }

    if (lowerText.contains('parkir mobil') || 
        lowerText.contains('car parking')) {
      return NavigationCommand.findCarParking;
    }

    if (lowerText.contains('pintu keluar') || 
        lowerText.contains('exit') ||
        lowerText.contains('keluar parkir')) {
      return NavigationCommand.navigateToExit;
    }

    if (lowerText.contains('arahkan') || 
        lowerText.contains('navigate') ||
        lowerText.contains('menuju')) {
      return NavigationCommand.navigateToMall;
    }

    if (lowerText.contains('terdekat') || 
        lowerText.contains('nearest') ||
        lowerText.contains('dekat')) {
      return NavigationCommand.findNearestParking;
    }

    return NavigationCommand.unknown;
  }

  String? _extractLocation(String text) {
    // Extract location names from voice commands
    final patterns = [
      r'arahkan saya ke (.+)',
      r'navigate to (.+)',
      r'mall (.+)',
      r'lokasi (.+)',
      r'area (.+)',
    ];

    for (final pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(text);
      if (match != null && match.groupCount > 0) {
        return match.group(1)?.trim();
      }
    }

    return null;
  }

  Map<String, dynamic> _buildCommandMetadata(String text, NavigationCommand command) {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'confidence': _speechToText.lastRecognizedWords.isNotEmpty ? 0.8 : 0.0,
      'language': 'id-ID',
      'commandType': command.toString().split('.').last,
    };
  }

  // Text-to-Speech Methods
  Future<void> speak(String text, {String language = 'id-ID'}) async {
    try {
      if (_currentState == VoiceState.speaking) {
        await stopSpeaking();
      }

      _currentState = VoiceState.speaking;
      notifyListeners();

      await _flutterTts.setLanguage(language);
      await _flutterTts.speak(text);
    } catch (e) {
      _lastError = 'Failed to speak: $e';
      _currentState = VoiceState.error;
      notifyListeners();
    }
  }

  Future<void> setLanguage(String language) async {
    try {
      await _flutterTts.setLanguage(language);
    } catch (e) {
      _lastError = 'Failed to set language: $e';
      _currentState = VoiceState.error;
      notifyListeners();
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _flutterTts.stop();
      _currentState = VoiceState.idle;
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping TTS: $e');
    }
  }

  // Navigation Audio Guidance
  Future<void> playNavigationInstruction(String instruction, {double? distance}) async {
    String audioText = instruction;
    
    if (distance != null) {
      if (distance < 50) {
        audioText = 'Anda telah sampai di lokasi tujuan';
      } else if (distance < 100) {
        audioText = '$instruction ${distance.round()} meter lagi';
      } else {
        audioText = '$instruction ${(distance / 100).round() / 10} kilometer lagi';
      }
    }

    await speak(audioText);
  }

  // Voice feedback for user actions
  Future<void> playFeedback(String message) async {
    if (_currentState == VoiceState.idle) {
      await speak(message);
    }
  }

  // Dispose method
  @override
  void dispose() {
    _speechToText.cancel();
    _flutterTts.stop();
    _commandController.close();
    _soundLevelController.close();
    super.dispose();
  }
}