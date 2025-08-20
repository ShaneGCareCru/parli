import 'dart:async';
import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/transport_manager.dart';
import 'waveform_widget.dart';

enum PTTButtonState { idle, pressed, disabled }

enum PTTEvent { press, hold, release }

class PTTButton extends StatefulWidget {
  final String label;
  final bool isEnabled;
  final Function(PTTEvent) onEvent;
  final Color primaryColor;
  final Color disabledColor;
  final IconData? icon;
  final Duration holdThreshold;
  final TransportManager? transportManager;

  const PTTButton({
    super.key,
    required this.label,
    required this.onEvent,
    this.isEnabled = true,
    this.primaryColor = Colors.blue,
    this.disabledColor = Colors.grey,
    this.icon,
    this.holdThreshold = const Duration(milliseconds: 500),
    this.transportManager,
  });

  @override
  State<PTTButton> createState() => _PTTButtonState();
}

class _PTTButtonState extends State<PTTButton>
    with SingleTickerProviderStateMixin {
  PTTButtonState _buttonState = PTTButtonState.idle;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  Timer? _holdTimer;
  
  final AudioService _audioService = AudioService();
  double _currentAmplitude = 0.0;
  bool _isRecording = false;
  StreamSubscription<double>? _amplitudeSubscription;
  StreamSubscription<AudioCaptureState>? _audioStateSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _initializeAudioService();
  }
  
  void _initializeAudioService() async {
    try {
      final success = await _audioService.initialize();
      if (!success) {
        debugPrint('Failed to initialize AudioService');
        return;
      }
      
      _amplitudeSubscription = _audioService.amplitudeStream.listen((amplitude) {
        if (mounted) {
          setState(() {
            _currentAmplitude = amplitude;
          });
        }
      });
      
      _audioStateSubscription = _audioService.stateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isRecording = state == AudioCaptureState.recording;
          });
        }
      });
    } catch (e) {
      debugPrint('Error initializing AudioService: $e');
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _audioStateSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isEnabled) return;
    
    setState(() {
      _buttonState = PTTButtonState.pressed;
    });
    _animationController.forward();
    widget.onEvent(PTTEvent.press);
    
    // Start audio recording immediately on press
    _startRecording();
    
    // Start hold timer
    _holdTimer = Timer(widget.holdThreshold, () {
      if (_buttonState == PTTButtonState.pressed) {
        widget.onEvent(PTTEvent.hold);
      }
    });
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.isEnabled) return;
    
    _handleRelease();
  }

  void _handleTapCancel() {
    if (!widget.isEnabled) return;
    
    _handleRelease();
  }

  void _handleRelease() {
    _holdTimer?.cancel();
    setState(() {
      _buttonState = PTTButtonState.idle;
    });
    _animationController.reverse();
    
    // Stop audio recording on release and send to WebSocket
    _stopRecordingAndSend();
    
    widget.onEvent(PTTEvent.release);
  }
  
  void _startRecording() async {
    try {
      final success = await _audioService.startRecording();
      if (!success) {
        debugPrint('Failed to start recording');
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }
  
  void _stopRecordingAndSend() async {
    try {
      // Stop recording first
      await _audioService.stopRecording();
      
      // Get the recorded audio as PCM16 data
      final audioData = await _audioService.getRecordedAudioAsPCM16();
      
      if (audioData != null && audioData.isNotEmpty && widget.transportManager != null) {
        debugPrint('Sending ${audioData.length} bytes of audio data to transport manager');
        
        // Send audio data to the transport manager
        await widget.transportManager!.sendAudio(audioData);
        
        // Commit the audio buffer to trigger translation
        await widget.transportManager!.commitAudioBuffer();
        debugPrint('Audio buffer committed for translation');
      } else {
        debugPrint('No audio data to send or transport manager not available');
      }
    } catch (e) {
      debugPrint('Error stopping recording and sending audio: $e');
    }
  }

  Color get _currentColor {
    if (!widget.isEnabled) return widget.disabledColor;
    return _buttonState == PTTButtonState.pressed
        ? widget.primaryColor.withValues(alpha: 0.8)
        : widget.primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isEnabled ? _handleTapDown : null,
      onTapUp: widget.isEnabled ? _handleTapUp : null,
      onTapCancel: widget.isEnabled ? _handleTapCancel : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: _currentColor,
                shape: BoxShape.circle,
                boxShadow: widget.isEnabled
                    ? [
                        BoxShadow(
                          color: _currentColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null && !_isRecording)
                    Icon(
                      widget.icon,
                      color: Colors.white,
                      size: 32,
                    ),
                  if (_isRecording)
                    WaveformWidget(
                      amplitude: _currentAmplitude,
                      color: Colors.white,
                      height: 32,
                      width: 80,
                      isActive: _isRecording,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _isRecording ? "Recording..." : widget.label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}