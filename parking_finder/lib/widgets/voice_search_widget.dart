import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_service.dart';

class VoiceSearchWidget extends StatefulWidget {
  final Function(VoiceCommandResult)? onCommandRecognized;
  final VoidCallback? onVoiceSearchStarted;
  final VoidCallback? onVoiceSearchCompleted;
  final bool showFloatingButton;
  final Color? primaryColor;
  final Color? accentColor;

  const VoiceSearchWidget({
    Key? key,
    this.onCommandRecognized,
    this.onVoiceSearchStarted,
    this.onVoiceSearchCompleted,
    this.showFloatingButton = true,
    this.primaryColor,
    this.accentColor,
  }) : super(key: key);

  @override
  State<VoiceSearchWidget> createState() => _VoiceSearchWidgetState();
}

class _VoiceSearchWidgetState extends State<VoiceSearchWidget>
    with SingleTickerProviderStateMixin {
  late VoiceService _voiceService;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;
  StreamSubscription? _commandSubscription;
  StreamSubscription? _soundLevelSubscription;

  bool _isListening = false;
  double _soundLevel = 0.0;
  String _recognizedText = '';
  String _statusText = 'Tekan untuk mulai';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeVoiceService();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _waveAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.linear,
      ),
    );

    _animationController.repeat(reverse: true);
  }

  void _initializeVoiceService() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _voiceService = Provider.of<VoiceService>(context, listen: false);
      
      // Listen to voice service state changes
      _voiceService.addListener(_onVoiceServiceChanged);
      
      // Subscribe to command stream
      _commandSubscription = _voiceService.commandStream.listen(_onCommandReceived);
      
      // Subscribe to sound level stream
      _soundLevelSubscription = _voiceService.soundLevelStream.listen(_onSoundLevelChanged);
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
      widget.onVoiceSearchCompleted?.call();
      
      // Provide audio feedback
      _voiceService.playFeedback('Saya menemukan ${command.recognizedText}');
    }
  }

  void _onSoundLevelChanged(double level) {
    if (mounted) {
      setState(() {
        _soundLevel = level;
      });
    }
  }

  Future<void> _handleVoiceButtonPressed() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    try {
      widget.onVoiceSearchStarted?.call();
      await _voiceService.startListening();
    } catch (e) {
      _showError('Gagal memulai pengenalan suara: $e');
    }
  }

  Future<void> _stopListening() async {
    try {
      await _voiceService.stopListening();
      widget.onVoiceSearchCompleted?.call();
    } catch (e) {
      _showError('Gagal menghentikan pengenalan suara: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.primaryColor ?? Theme.of(context).primaryColor;
    final accentColor = widget.accentColor ?? Theme.of(context).colorScheme.secondary;

    if (widget.showFloatingButton) {
      return _buildFloatingButton(primaryColor, accentColor);
    } else {
      return _buildInlineButton(primaryColor, accentColor);
    }
  }

  Widget _buildFloatingButton(Color primaryColor, Color accentColor) {
    return FloatingActionButton(
      onPressed: _handleVoiceButtonPressed,
      backgroundColor: _isListening ? accentColor : primaryColor,
      elevation: 8,
      child: _buildButtonContent(),
    );
  }

  Widget _buildInlineButton(Color primaryColor, Color accentColor) {
    return GestureDetector(
      onTap: _handleVoiceButtonPressed,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isListening ? accentColor : primaryColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: _buildButtonContent(),
      ),
    );
  }

  Widget _buildButtonContent() {
    if (_isListening) {
      return Stack(
        alignment: Alignment.center,
        children: [
          // Waveform animation
          AnimatedBuilder(
            animation: _waveAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(40, 40),
                painter: WaveformPainter(
                  animationValue: _waveAnimation.value,
                  soundLevel: _soundLevel,
                  color: Colors.white,
                ),
              );
            },
          ),
          // Pulsing circle
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              );
            },
          ),
          // Microphone icon
          const Icon(
            Icons.mic,
            color: Colors.white,
            size: 24,
          ),
        ],
      );
    } else {
      return const Icon(
        Icons.mic_none,
        color: Colors.white,
        size: 32,
      );
    }
  }

  @override
  void dispose() {
    _commandSubscription?.cancel();
    _soundLevelSubscription?.cancel();
    _voiceService.removeListener(_onVoiceServiceChanged);
    _animationController.dispose();
    super.dispose();
  }
}

class WaveformPainter extends CustomPainter {
  final double animationValue;
  final double soundLevel;
  final Color color;

  WaveformPainter({
    required this.animationValue,
    required this.soundLevel,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadius = size.width / 2;

    // Draw multiple concentric circles with varying opacity
    for (int i = 1; i <= 3; i++) {
      final radius = (maxRadius / 3) * i;
      final opacity = (1.0 - (i - 1) / 3) * (0.3 + (soundLevel / 100) * 0.7);
      
      paint.color = color.withValues(alpha: opacity);
      
      canvas.drawCircle(
        Offset(centerX, centerY),
        radius,
        paint,
      );
    }

    // Draw wave lines
    final waveCount = 5;
    final waveHeight = size.height / 4;
    
    for (int i = 0; i < waveCount; i++) {
      final path = Path();
      final y = centerY - waveHeight + (i * waveHeight / 2);
      
      path.moveTo(0, y);
      
      for (double x = 0; x <= size.width; x += 2) {
        final waveOffset = (x / size.width) * 2 * math.pi;
        final waveY = y + math.sin(waveOffset + animationValue) * (soundLevel / 10);
        path.lineTo(x, waveY);
      }
      
      paint.color = color.withValues(alpha: 0.6 - (i * 0.1));
      paint.strokeWidth = 1;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return animationValue != oldDelegate.animationValue ||
           soundLevel != oldDelegate.soundLevel;
  }
}