import 'dart:async';
import 'dart:io';
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
  final List<List<int>> _audioBuffer = [];

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

      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        final granted = await requestMicrophonePermission();
        if (!granted) return false;
      }

      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        bitRate: 128000,
        numChannels: 1,
      );

      // Generate temporary file path for recording
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      
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
    // Only start monitoring if there are active listeners
    if (_amplitudeController?.hasListener == true) {
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

  /// Start buffering audio data for later retrieval
  void startBuffering() {
    _audioBuffer.clear();
    debugPrint('Started audio buffering');
  }

  /// Stop buffering and return all captured audio data as PCM16
  List<int> stopBufferingAndGetAudio() {
    final allAudioData = <int>[];
    for (final chunk in _audioBuffer) {
      allAudioData.addAll(chunk);
    }
    final result = List<int>.from(allAudioData);
    _audioBuffer.clear();
    debugPrint('Stopped audio buffering, captured ${result.length} audio samples');
    return result;
  }

  /// Clear the audio buffer without returning data
  void clearBuffer() {
    _audioBuffer.clear();
    debugPrint('Audio buffer cleared');
  }

  /// Get recorded audio data as PCM16 from the last recording
  Future<Uint8List?> getRecordedAudioAsPCM16() async {
    if (_currentRecordingPath == null) {
      debugPrint('No recording path available');
      return null;
    }

    try {
      final file = File(_currentRecordingPath!);
      if (!await file.exists()) {
        debugPrint('Recording file does not exist: $_currentRecordingPath');
        return null;
      }

      // Read the WAV file bytes
      final audioBytes = await file.readAsBytes();
      debugPrint('Read ${audioBytes.length} bytes from recording file');

      // For WAV files, we need to skip the header (typically 44 bytes)
      // and extract the PCM data
      if (audioBytes.length < 44) {
        debugPrint('Audio file too small to contain valid WAV header');
        return null;
      }

      // Skip WAV header (44 bytes) and return PCM16 data
      final pcmData = audioBytes.sublist(44);
      debugPrint('Extracted ${pcmData.length} bytes of PCM16 data');
      
      return Uint8List.fromList(pcmData);
    } catch (e) {
      debugPrint('Error reading recorded audio: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    _stopAmplitudeMonitoring();
    
    if (_state == AudioCaptureState.recording) {
      await stopRecording();
    }
    
    await _recorder.dispose();
    
    // Check for active listeners before closing
    if (_stateController?.hasListener == true) {
      await _stateController?.close();
    }
    if (_audioDataController?.hasListener == true) {
      await _audioDataController?.close();
    }
    if (_amplitudeController?.hasListener == true) {
      await _amplitudeController?.close();
    }
    
    _stateController = null;
    _audioDataController = null;
    _amplitudeController = null;
  }
}