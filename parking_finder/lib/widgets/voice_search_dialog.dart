import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_service.dart';
import 'voice_search_widget.dart';

class VoiceSearchDialog extends StatefulWidget {
  final Function(VoiceCommandResult)? onCommandRecognized;

  const VoiceSearchDialog({
    Key? key,
    this.onCommandRecognized,
  }) : super(key: key);

  @override
  State<VoiceSearchDialog> createState() => _VoiceSearchDialogState();
}

class _VoiceSearchDialogState extends State<VoiceSearchDialog>
    with SingleTickerProviderStateMixin {
  late VoiceService _voiceService;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _statusText = 'Tekan untuk mulai';
  String _recognizedText = '';
  bool _isListening = false;
  StreamSubscription? _commandSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeVoiceService();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();
  }

  void _initializeVoiceService() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _voiceService = Provider.of<VoiceService>(context, listen: false);
      _voiceService.addListener(_onVoiceServiceChanged);
      
      // Subscribe to command stream
      _commandSubscription = _voiceService.commandStream.listen(_onCommandReceived);
    });
  }

  void _onVoiceServiceChanged() {
    if (mounted) {
      setState(() {
        _isListening = _voiceService.isListening;
        _recognizedText = _voiceService.lastRecognizedText;
        
        // Update status text based on current state
        switch (_voiceService.currentState) {
          case VoiceState.listening:
            _statusText = 'Mendengarkan...';
            break;
          case VoiceState.processing:
            _statusText = 'Memproses...';
            break;
          case VoiceState.speaking:
            _statusText = 'Berbicara...';
            break;
          case VoiceState.error:
            _statusText = 'Error: ${_voiceService.lastError}';
            break;
          default:
            _statusText = 'Tekan untuk mulai';
        }
      });
    }
  }

  void _onCommandReceived(VoiceCommandResult command) {
    if (mounted) {
      widget.onCommandRecognized?.call(command);
      
      // Provide audio feedback
      _voiceService.playFeedback('Saya menemukan ${command.recognizedText}');
      
      // Close dialog after successful recognition
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).primaryColor.withValues(alpha: 0.95),
                    Theme.of(context).colorScheme.secondary.withValues(alpha: 0.95),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  const Text(
                    'Voice Search',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gunakan suara untuk mencari lokasi parkir',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Voice button
                  VoiceSearchWidget(
                    showFloatingButton: false,
                    onVoiceSearchStarted: () {
                      // Handle search started
                    },
                    onVoiceSearchCompleted: () {
                      // Handle search completed
                    },
                    primaryColor: Colors.white,
                    accentColor: Colors.amber,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Status text
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _statusText,
                      key: ValueKey(_statusText),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Recognized text
                  if (_recognizedText.isNotEmpty) ...[
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        key: ValueKey(_recognizedText),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Hasil:',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _recognizedText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Example commands
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Contoh perintah:',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildCommandExample('"Cari parkir terdekat"'),
                        _buildCommandExample('"Navigasi ke pintu keluar"'),
                        _buildCommandExample('"Dimana area parkir motor?"'),
                        _buildCommandExample('"Arahkan ke Mall Central Gate"'),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Close button
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCommandExample(String command) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            Icons.mic,
            size: 14,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Text(
            command,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commandSubscription?.cancel();
    _voiceService.removeListener(_onVoiceServiceChanged);
    _animationController.dispose();
    super.dispose();
  }
}