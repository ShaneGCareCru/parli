import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logging/logging.dart';

/// WebRTC client for OpenAI Realtime API connections
/// Provides low-latency audio transport as primary connection method
class WebRTCClient {
  static final _logger = Logger('WebRTCClient');
  
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Uint8List> _audioController = 
      StreamController<Uint8List>.broadcast();
  final StreamController<RTCPeerConnectionState> _stateController = 
      StreamController<RTCPeerConnectionState>.broadcast();
  
  /// Stream of incoming messages from OpenAI Realtime API
  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  
  /// Stream of incoming audio data
  Stream<Uint8List> get audioData => _audioController.stream;
  
  /// Stream of connection state changes
  Stream<RTCPeerConnectionState> get connectionState => _stateController.stream;
  
  /// Current connection state
  RTCPeerConnectionState get state => 
      _peerConnection?.connectionState ?? RTCPeerConnectionState.RTCPeerConnectionStateNew;
  
  /// Whether client is connected and ready
  bool get isConnected => 
      state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;

  /// Access to remote media stream (for audio playback)
  MediaStream? get remoteStream => _remoteStream;

  /// Initialize WebRTC connection to OpenAI Realtime API
  /// 
  /// [token] - Ephemeral token from token service
  /// [iceServers] - Optional custom ICE servers (defaults to Google STUN)
  Future<void> connect({
    required String token,
    List<Map<String, String>>? iceServers,
  }) async {
    try {
      _logger.info('Initializing WebRTC connection to OpenAI Realtime API');
      
      // Create peer connection with ICE configuration
      final config = {
        'iceServers': iceServers ?? [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      };
      
      _peerConnection = await createPeerConnection(config);
      
      // Set up event handlers
      _setupEventHandlers();
      
      // Create data channel for Realtime API communication
      _dataChannel = await _peerConnection!.createDataChannel(
        'realtime',
        RTCDataChannelInit()
          ..ordered = true
          ..protocol = 'realtime-api',
      );
      
      _setupDataChannelHandlers();
      
      // Create and set local offer
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      
      // Note: In real implementation, offer would be sent to OpenAI signaling server
      // and answer would be received and set as remote description
      // This is a skeleton implementation for PAR-15 acceptance criteria
      
      _logger.info('WebRTC connection initialized successfully');
      
    } catch (e) {
      _logger.severe('Failed to initialize WebRTC connection: $e');
      rethrow;
    }
  }
  
  /// Setup peer connection event handlers
  void _setupEventHandlers() {
    _peerConnection!.onConnectionState = (state) {
      _logger.info('WebRTC connection state changed: $state');
      _stateController.add(state);
    };
    
    _peerConnection!.onAddStream = (stream) {
      _logger.info('Remote stream added');
      _remoteStream = stream;
      
      // Extract audio data from remote stream
      if (stream.getAudioTracks().isNotEmpty) {
        final audioTrack = stream.getAudioTracks().first;
        // Note: In real implementation, audio data extraction would happen here
        _logger.info('Remote audio track received: ${audioTrack.id}');
      }
    };
    
    _peerConnection!.onRemoveStream = (stream) {
      _logger.info('Remote stream removed');
      _remoteStream = null;
    };
    
    _peerConnection!.onIceCandidate = (candidate) {
      _logger.fine('ICE candidate generated: ${candidate.candidate}');
      // Note: In real implementation, candidate would be sent to signaling server
    };
  }
  
  /// Setup data channel event handlers
  void _setupDataChannelHandlers() {
    _dataChannel!.onMessage = (message) {
      try {
        final data = json.decode(message.text);
        _logger.fine('Received message: ${data['type']}');
        _messageController.add(data);
      } catch (e) {
        _logger.warning('Failed to parse incoming message: $e');
      }
    };
    
    _dataChannel!.onDataChannelState = (state) {
      _logger.info('Data channel state changed: $state');
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _logger.info('Data channel opened');
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        _logger.info('Data channel closed');
      }
    };
  }
  
  /// Send message to OpenAI Realtime API
  Future<void> sendMessage(Map<String, dynamic> message) async {
    if (_dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) {
      throw StateError('Data channel not open');
    }
    
    try {
      final messageJson = json.encode(message);
      await _dataChannel!.send(RTCDataChannelMessage(messageJson));
      _logger.fine('Sent message: ${message['type']}');
    } catch (e) {
      _logger.severe('Failed to send message: $e');
      rethrow;
    }
  }
  
  /// Send audio data to OpenAI Realtime API
  /// 
  /// [audioData] - PCM16 audio data
  Future<void> sendAudio(Uint8List audioData) async {
    if (!isConnected) {
      throw StateError('WebRTC connection not established');
    }
    
    try {
      // Note: In real implementation, audio would be sent through audio track
      // This is a placeholder for PAR-15 acceptance criteria
      await sendMessage({
        'type': 'input_audio_buffer.append',
        'audio': base64Encode(audioData),
      });
      
      _logger.fine('Sent audio data: ${audioData.length} bytes');
    } catch (e) {
      _logger.severe('Failed to send audio data: $e');
      rethrow;
    }
  }
  
  /// Start audio capture from device microphone
  Future<void> startAudioCapture() async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'sampleRate': 16000, // OpenAI Realtime API requirement
          'channelCount': 1,   // Mono audio
        },
        'video': false,
      });
      
      // Add local stream to peer connection
      if (_peerConnection != null) {
        await _peerConnection!.addStream(_localStream!);
      }
      
      _logger.info('Audio capture started');
    } catch (e) {
      _logger.severe('Failed to start audio capture: $e');
      rethrow;
    }
  }
  
  /// Stop audio capture
  Future<void> stopAudioCapture() async {
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) => track.stop());
      _localStream = null;
      _logger.info('Audio capture stopped');
    }
  }
  
  /// Close WebRTC connection and cleanup resources
  Future<void> close() async {
    _logger.info('Closing WebRTC connection');
    
    try {
      await stopAudioCapture();
      
      _dataChannel?.close();
      _dataChannel = null;
      
      await _peerConnection?.close();
      _peerConnection = null;
      
      _remoteStream = null;
      
      await _messageController.close();
      await _audioController.close();
      await _stateController.close();
      
      _logger.info('WebRTC connection closed successfully');
    } catch (e) {
      _logger.severe('Error closing WebRTC connection: $e');
      rethrow;
    }
  }
}