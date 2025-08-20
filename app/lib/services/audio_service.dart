import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

enum AudioCaptureState {
  idle,
  requestingPermission,
  permissionDenied,
  starting,
  recording,
  stopping,
  error
}

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  
  AudioCaptureState _state = AudioCaptureState.idle;
  StreamController<AudioCaptureState>? _stateController;
  StreamController<List<int>>? _audioDataController;
  StreamController<double>? _amplitudeController;
  
  String? _currentRecordingPath;
  Timer? _amplitudeTimer;

  Stream<AudioCaptureState> get stateStream => 
      _stateController?.stream ?? const Stream.empty();
  
  Stream<List<int>> get audioDataStream => 
      _audioDataController?.stream ?? const Stream.empty();
      
  Stream<double> get amplitudeStream => 
      _amplitudeController?.stream ?? const Stream.empty();

  AudioCaptureState get currentState => _state;

  Future<bool> initialize() async {
    try {
      _stateController ??= StreamController<AudioCaptureState>.broadcast();
      _audioDataController ??= StreamController<List<int>>.broadcast();
      _amplitudeController ??= StreamController<double>.broadcast();
      return true;
    } catch (e) {
      debugPrint('AudioService initialization failed: $e');
      return false;
    }
  }

  Future<bool> requestMicrophonePermission() async {
    _updateState(AudioCaptureState.requestingPermission);
    
    try {
      final status = await Permission.microphone.request();
      
      if (status.isGranted) {
        _updateState(AudioCaptureState.idle);
        return true;
      } else {
        _updateState(AudioCaptureState.permissionDenied);
        return false;
      }
    } catch (e) {
      debugPrint('Permission request failed: $e');
      _updateState(AudioCaptureState.error);
      return false;
    }
  }

  Future<bool> startRecording() async {
    if (_state != AudioCaptureState.idle) {
      debugPrint('Cannot start recording: current state is $_state');
      return false;
    }

    try {
      _updateState(AudioCaptureState.starting);

      final hasPermission = await Permission.microphone.isGranted;
      if (!hasPermission) {
        final granted = await requestMicrophonePermission();
        if (!granted) return false;
      }

      final isSupported = await _recorder.hasPermission();
      if (!isSupported) {
        debugPrint('Recording not supported or permission denied');
        _updateState(AudioCaptureState.permissionDenied);
        return false;
      }

      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        bitRate: 128000,
        numChannels: 1,
      );

      // Generate temporary file path for recording
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _recorder.start(config, path: path);
      _updateState(AudioCaptureState.recording);
      
      _startAmplitudeMonitoring();
      
      debugPrint('Audio recording started');
      return true;
      
    } catch (e) {
      debugPrint('Failed to start recording: $e');
      _updateState(AudioCaptureState.error);
      return false;
    }
  }

  Future<String?> stopRecording() async {
    if (_state != AudioCaptureState.recording) {
      debugPrint('Cannot stop recording: current state is $_state');
      return null;
    }

    try {
      _updateState(AudioCaptureState.stopping);
      _stopAmplitudeMonitoring();

      final path = await _recorder.stop();
      _updateState(AudioCaptureState.idle);
      
      if (path != null) {
        debugPrint('Audio recording stopped, saved to: $path');
        _currentRecordingPath = path;
        return path;
      }
      
      return null;
    } catch (e) {
      debugPrint('Failed to stop recording: $e');
      _updateState(AudioCaptureState.error);
      return null;
    }
  }

  void _startAmplitudeMonitoring() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) async {
        try {
          final amplitude = await _recorder.getAmplitude();
          final normalizedAmplitude = _normalizeAmplitude(amplitude.current);
          _amplitudeController?.add(normalizedAmplitude);
        } catch (e) {
          debugPrint('Failed to get amplitude: $e');
        }
      },
    );
  }

  void _stopAmplitudeMonitoring() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _amplitudeController?.add(0.0);
  }

  double _normalizeAmplitude(double amplitude) {
    const minDb = -60.0;
    const maxDb = 0.0;
    
    final clampedDb = amplitude.clamp(minDb, maxDb);
    return (clampedDb - minDb) / (maxDb - minDb);
  }

  void _updateState(AudioCaptureState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController?.add(_state);
      debugPrint('AudioService state changed to: $_state');
    }
  }

  String? get lastRecordingPath => _currentRecordingPath;

  Future<void> dispose() async {
    _stopAmplitudeMonitoring();
    
    if (_state == AudioCaptureState.recording) {
      await stopRecording();
    }
    
    await _recorder.dispose();
    
    await _stateController?.close();
    await _audioDataController?.close();
    await _amplitudeController?.close();
    
    _stateController = null;
    _audioDataController = null;
    _amplitudeController = null;
  }
}