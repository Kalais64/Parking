import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_navigation_service.dart';
import '../services/voice_service.dart';

class NavigationControlWidget extends StatefulWidget {
  const NavigationControlWidget({Key? key}) : super(key: key);

  @override
  State<NavigationControlWidget> createState() => _NavigationControlWidgetState();
}

class _NavigationControlWidgetState extends State<NavigationControlWidget> {
  late AudioNavigationService _navigationService;
  late VoiceService _voiceService;
  StreamSubscription? _navigationSubscription;

  bool _isNavigating = false;
  bool _isAudioEnabled = true;
  double _volume = 0.8;
  String _currentInstruction = '';
  double _remainingDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationService = Provider.of<AudioNavigationService>(context, listen: false);
      _voiceService = Provider.of<VoiceService>(context, listen: false);
      
      // Listen to navigation state changes
      _navigationService.addListener(_onNavigationStateChanged);
      
      // Set initial values
      _onNavigationStateChanged();
    });
  }

  void _onNavigationStateChanged() {
    if (mounted) {
      setState(() {
        _isNavigating = _navigationService.isNavigating;
        _isAudioEnabled = _navigationService.isAudioEnabled;
        _volume = _navigationService.audioVolume;
        
        final navInfo = _navigationService.getRemainingNavigationInfo();
        _remainingDistance = navInfo['distance'] as double;
        
        final currentStep = _navigationService.currentStep;
        _currentInstruction = currentStep?.instruction ?? '';
      });
    }
  }

  @override
  void dispose() {
    _navigationService.removeListener(_onNavigationStateChanged);
    _navigationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isNavigating) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Navigasi Aktif',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => _stopNavigation(),
                tooltip: 'Hentikan navigasi',
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Current instruction
          if (_currentInstruction.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _currentInstruction,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Distance and controls
          Row(
            children: [
              // Distance info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_remainingDistance.toStringAsFixed(0)} meter',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'sisa perjalanan',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Control buttons
              Row(
                children: [
                  // Repeat instruction
                  IconButton(
                    icon: const Icon(Icons.repeat, color: Colors.white),
                    onPressed: () => _repeatInstruction(),
                    tooltip: 'Ulangi instruksi',
                  ),
                  
                  // Toggle audio
                  IconButton(
                    icon: Icon(
                      _isAudioEnabled ? Icons.volume_up : Icons.volume_off,
                      color: Colors.white,
                    ),
                    onPressed: () => _toggleAudio(),
                    tooltip: _isAudioEnabled ? 'Matikan suara' : 'Nyalakan suara',
                  ),
                  
                  // Volume control
                  PopupMenuButton<double>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (value) => _setVolume(value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 0.3,
                        child: Text('Volume Rendah'),
                      ),
                      const PopupMenuItem(
                        value: 0.6,
                        child: Text('Volume Sedang'),
                      ),
                      const PopupMenuItem(
                        value: 0.9,
                        child: Text('Volume Tinggi'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _stopNavigation() {
    _navigationService.stopNavigation();
    _voiceService.playFeedback('Navigasi dihentikan');
  }

  void _repeatInstruction() {
    _navigationService.repeatCurrentInstruction();
  }

  void _toggleAudio() {
    _navigationService.toggleAudio();
    final message = _isAudioEnabled ? 'Panduan audio dimatikan' : 'Panduan audio dinyalakan';
    _voiceService.playFeedback(message);
  }

  void _setVolume(double volume) {
    _navigationService.setVolume(volume);
    _voiceService.playFeedback('Volume diatur ke ${(volume * 100).round()}%');
  }
}