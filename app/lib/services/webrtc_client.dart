import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logging/logging.dart';

/// WebRTC client for OpenAI Realtime API connections
/// Provides low-latency audio transport as primary connection method
/// 
/// Supports both production signaling with OpenAI Realtime API and mock mode
/// for development/testing. Mock mode can be enabled via environment variable
/// ENABLE_WEBRTC_MOCK_SIGNALING=true or by setting enableMockSignaling parameter.
class WebRTCClient {
  static final _logger = Logger('WebRTCClient');
  
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  // Feature flag for mock signaling (development/testing)
  final bool _enableMockSignaling;
  
  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Uint8List> _audioController = 
      StreamController<Uint8List>.broadcast();
  final StreamController<RTCPeerConnectionState> _stateController = 
      StreamController<RTCPeerConnectionState>.broadcast();

  /// Create WebRTC client with optional mock signaling for development
  /// 
  /// [enableMockSignaling] - Enable mock signaling for development/testing
  /// If not specified, checks ENABLE_WEBRTC_MOCK_SIGNALING environment variable
  WebRTCClient({bool? enableMockSignaling}) 
      : _enableMockSignaling = enableMockSignaling ?? 
          const String.fromEnvironment('ENABLE_WEBRTC_MOCK_SIGNALING', defaultValue: 'false') == 'true';
  
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
      
      // Perform OpenAI Realtime API signaling
      await _performRealtimeSignaling(offer, token);
      
      _logger.info('WebRTC connection to OpenAI Realtime API established');
      
    } catch (e) {
      _logger.severe('Failed to initialize WebRTC connection: $e');
      rethrow;
    }
  }
  
  /// Perform OpenAI Realtime API WebRTC signaling
  /// 
  /// Exchanges SDP offer/answer and ICE candidates with OpenAI's signaling server
  /// This enables direct WebRTC connection to the Realtime API
  Future<void> _performRealtimeSignaling(RTCSessionDescription offer, String token) async {
    _logger.info('Starting OpenAI Realtime API signaling');
    
    try {
      // Send offer to OpenAI Realtime API signaling endpoint
      final signalingResponse = await _sendSignalingRequest(offer, token);
      
      // Set remote description from OpenAI's answer
      final answer = RTCSessionDescription(
        signalingResponse['answer'],
        signalingResponse['type'],
      );
      await _peerConnection!.setRemoteDescription(answer);
      
      // Exchange ICE candidates if provided
      if (signalingResponse.containsKey('ice_candidates')) {
        final candidates = signalingResponse['ice_candidates'] as List;
        for (final candidateData in candidates) {
          final candidate = RTCIceCandidate(
            candidateData['candidate'],
            candidateData['sdpMid'],
            candidateData['sdpMLineIndex'],
          );
          await _peerConnection!.addCandidate(candidate);
        }
      }
      
      _logger.info('OpenAI Realtime API signaling completed successfully');
      
    } catch (e) {
      _logger.severe('OpenAI Realtime API signaling failed: $e');
      rethrow;
    }
  }
  
  /// Send signaling request to OpenAI Realtime API
  /// 
  /// Uses mock signaling when _enableMockSignaling is true, otherwise
  /// attempts to connect to actual OpenAI Realtime API signaling endpoint
  Future<Map<String, dynamic>> _sendSignalingRequest(
    RTCSessionDescription offer, 
    String token,
  ) async {
    if (_enableMockSignaling) {
      return _sendMockSignalingRequest(offer, token);
    } else {
      return _sendProductionSignalingRequest(offer, token);
    }
  }

  /// Send mock signaling request for development/testing
  Future<Map<String, dynamic>> _sendMockSignalingRequest(
    RTCSessionDescription offer, 
    String token,
  ) async {
    _logger.warning('Using mock signaling for development - WebRTC will not actually connect');
    
    // Simulate signaling delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Return mock signaling response
    return {
      'type': 'answer',
      'answer': '''v=0
o=- 0 0 IN IP4 127.0.0.1
s=OpenAI Realtime API Mock
t=0 0
a=group:BUNDLE audio
m=audio 9 UDP/TLS/RTP/SAVPF 111
c=IN IP4 0.0.0.0
a=rtcp:9 IN IP4 0.0.0.0
a=ice-ufrag:mock
a=ice-pwd:mockpassword
a=fingerprint:sha-256 00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00
a=setup:active
a=mid:audio
a=sendrecv
a=rtcp-mux
a=rtpmap:111 opus/48000/2''',
      'ice_candidates': [
        {
          'candidate': 'candidate:1 1 UDP 2130706431 127.0.0.1 9 typ host',
          'sdpMid': 'audio',
          'sdpMLineIndex': 0,
        }
      ],
    };
  }

  /// Send production signaling request to OpenAI Realtime API
  Future<Map<String, dynamic>> _sendProductionSignalingRequest(
    RTCSessionDescription offer, 
    String token,
  ) async {
    _logger.info('Connecting to OpenAI Realtime API signaling server');
    
    // TODO: Implement actual OpenAI Realtime API signaling when endpoint is available
    // This should make HTTP request to OpenAI's signaling endpoint with:
    // - Authorization: Bearer $token
    // - Content-Type: application/json
    // - Body: { "type": "offer", "sdp": offer.sdp }
    
    throw UnimplementedError(
      'Production OpenAI Realtime API signaling not yet implemented. '
      'Enable mock signaling for development: ENABLE_WEBRTC_MOCK_SIGNALING=true'
    );
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
      _logger.fine('ICE candidate generated');
      // ICE candidates are now handled during initial signaling exchange
      // Additional candidates during the session could be sent to OpenAI here
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
  /// Currently sends via data channel - will be optimized to use audio tracks
  Future<void> sendAudio(Uint8List audioData) async {
    if (_dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) {
      throw StateError('WebRTC data channel not open');
    }
    
    try {
      // TODO (Performance): Send via audio track instead of data channel
      // For optimal latency, audio should flow through WebRTC media pipeline
      // rather than data channel. Current approach works but adds latency.
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