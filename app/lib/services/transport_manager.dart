import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logging/logging.dart';
import 'webrtc_client.dart';
import 'websocket_client.dart';

/// Manages transport selection between WebRTC (primary) and WebSocket (fallback)
/// Handles automatic failover and manual transport switching
class TransportManager {
  static final _logger = Logger('TransportManager');
  
  WebRTCClient? _webrtcClient;
  WebSocketClient? _websocketClient;
  
  TransportType _activeTransport = TransportType.none;
  TransportType _preferredTransport = TransportType.webrtc;
  
  // Secure token storage with expiration tracking
  String? _currentToken;
  DateTime? _tokenExpiry;
  StreamSubscription? _webrtcMessageSub;
  StreamSubscription? _webrtcAudioSub;
  StreamSubscription? _webrtcStateSub;
  StreamSubscription? _websocketMessageSub;
  StreamSubscription? _websocketAudioSub;
  StreamSubscription? _websocketStateSub;
  
  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Uint8List> _audioController = 
      StreamController<Uint8List>.broadcast();
  final StreamController<TransportStatus> _statusController = 
      StreamController<TransportStatus>.broadcast();
  
  /// Stream of incoming messages from active transport
  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  
  /// Stream of incoming audio data from active transport
  Stream<Uint8List> get audioData => _audioController.stream;
  
  /// Stream of transport status changes
  Stream<TransportStatus> get status => _statusController.stream;
  
  /// Current active transport type
  TransportType get activeTransport => _activeTransport;
  
  /// Current preferred transport type
  TransportType get preferredTransport => _preferredTransport;
  
  /// Whether any transport is connected
  bool get isConnected => _activeTransport != TransportType.none;

  /// Initialize and connect using optimal transport
  /// 
  /// [token] - Ephemeral token from token service
  /// [preferWebSocket] - Force WebSocket usage (for travel mode)
  Future<void> connect({
    required String token,
    bool preferWebSocket = false,
  }) async {
    _logger.info('Connecting with transport manager');
    
    // Store token with 5-minute expiration for failover use (per CLAUDE.md)
    _currentToken = token;
    _tokenExpiry = DateTime.now().add(const Duration(minutes: 5));
    
    _preferredTransport = preferWebSocket ? TransportType.webSocket : TransportType.webrtc;
    
    // Try preferred transport first
    bool connected = await _tryConnect(_preferredTransport, token);
    
    // Fall back to alternative transport if preferred fails
    if (!connected) {
      final fallbackTransport = _preferredTransport == TransportType.webrtc 
          ? TransportType.webSocket 
          : TransportType.webrtc;
      
      _logger.info('Preferred transport failed, trying fallback: $fallbackTransport');
      connected = await _tryConnect(fallbackTransport, token);
    }
    
    if (!connected) {
      _updateStatus(TransportStatus(
        activeTransport: TransportType.none,
        state: TransportState.failed,
        error: 'All transport methods failed',
      ));
      throw Exception('Failed to establish connection with any transport');
    }
  }
  
  /// Attempt connection with specific transport type
  Future<bool> _tryConnect(TransportType transport, String token) async {
    try {
      _logger.info('Attempting connection with $transport');
      
      _updateStatus(TransportStatus(
        activeTransport: transport,
        state: TransportState.connecting,
      ));
      
      switch (transport) {
        case TransportType.webrtc:
          await _connectWebRTC(token);
          break;
        case TransportType.webSocket:
          await _connectWebSocket(token);
          break;
        case TransportType.none:
          return false;
      }
      
      _activeTransport = transport;
      _updateStatus(TransportStatus(
        activeTransport: transport,
        state: TransportState.connected,
      ));
      
      _logger.info('Successfully connected with $transport');
      return true;
      
    } catch (e) {
      _logger.warning('Failed to connect with $transport: $e');
      _updateStatus(TransportStatus(
        activeTransport: transport,
        state: TransportState.error,
        error: e.toString(),
      ));
      return false;
    }
  }
  
  /// Connect using WebRTC
  Future<void> _connectWebRTC(String token) async {
    _webrtcClient = WebRTCClient();
    
    // Set up message forwarding with proper subscription management
    _webrtcMessageSub = _webrtcClient!.messages.listen(_messageController.add);
    _webrtcAudioSub = _webrtcClient!.audioData.listen(_audioController.add);
    
    // Monitor connection state for failover
    _webrtcStateSub = _webrtcClient!.connectionState.listen((state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _logger.warning('WebRTC connection lost, attempting WebSocket failover');
        _failoverToWebSocket();
      }
    });
    
    await _webrtcClient!.connect(token: token);
  }
  
  /// Connect using WebSocket
  Future<void> _connectWebSocket(String token) async {
    _websocketClient = WebSocketClient();
    
    // Set up message forwarding with proper subscription management
    _websocketMessageSub = _websocketClient!.messages.listen(_messageController.add);
    _websocketAudioSub = _websocketClient!.audioData.listen(_audioController.add);
    
    // Monitor connection state for failover
    _websocketStateSub = _websocketClient!.connectionState.listen((state) {
      if (state == WebSocketConnectionState.failed) {
        _logger.severe('WebSocket connection failed permanently');
        _updateStatus(TransportStatus(
          activeTransport: TransportType.webSocket,
          state: TransportState.failed,
          error: 'WebSocket connection failed',
        ));
      } else if (state == WebSocketConnectionState.error) {
        _logger.warning('WebSocket connection error - may recover');
        _updateStatus(TransportStatus(
          activeTransport: TransportType.webSocket,
          state: TransportState.error,
          error: 'WebSocket connection error',
        ));
      }
    });
    
    await _websocketClient!.connect(token: token);
  }
  
  /// Automatic failover from WebRTC to WebSocket
  Future<void> _failoverToWebSocket() async {
    if (_activeTransport == TransportType.webSocket) {
      return; // Already using WebSocket
    }
    
    _logger.info('Performing automatic failover to WebSocket');
    
    try {
      // Check token availability and expiration
      if (_currentToken == null || _tokenExpiry == null) {
        throw StateError('No token available for failover');
      }
      
      if (DateTime.now().isAfter(_tokenExpiry!)) {
        throw StateError('Token expired, cannot perform failover. New token required.');
      }
      
      await _connectWebSocket(_currentToken!);
      
      // Close WebRTC connection and cleanup subscriptions
      await _webrtcStateSub?.cancel();
      await _webrtcMessageSub?.cancel();
      await _webrtcAudioSub?.cancel();
      await _webrtcClient?.close();
      _webrtcClient = null;
      _webrtcStateSub = null;
      _webrtcMessageSub = null;
      _webrtcAudioSub = null;
      
      _activeTransport = TransportType.webSocket;
      _updateStatus(TransportStatus(
        activeTransport: TransportType.webSocket,
        state: TransportState.connected,
        failedOver: true,
      ));
      
      _logger.info('Failover to WebSocket completed successfully');
      
    } catch (e) {
      _logger.severe('Failover to WebSocket failed: $e');
      _updateStatus(TransportStatus(
        activeTransport: TransportType.none,
        state: TransportState.failed,
        error: 'Failover failed: $e',
      ));
    }
  }
  
  /// Manually switch to preferred transport
  Future<void> switchTransport(TransportType targetTransport) async {
    if (_activeTransport == targetTransport) {
      _logger.info('Already using $targetTransport');
      return;
    }
    
    _logger.info('Manually switching to $targetTransport');
    
    // This would require re-authentication and connection setup
    // Implementation depends on token management strategy
    throw UnimplementedError('Manual transport switching not yet implemented');
  }
  
  /// Send message through active transport
  Future<void> sendMessage(Map<String, dynamic> message) async {
    switch (_activeTransport) {
      case TransportType.webrtc:
        await _webrtcClient?.sendMessage(message);
        break;
      case TransportType.webSocket:
        await _websocketClient?.sendMessage(message);
        break;
      case TransportType.none:
        throw StateError('No active transport connection');
    }
  }
  
  /// Send audio through active transport
  Future<void> sendAudio(Uint8List audioData) async {
    switch (_activeTransport) {
      case TransportType.webrtc:
        await _webrtcClient?.sendAudio(audioData);
        break;
      case TransportType.webSocket:
        await _websocketClient?.sendAudio(audioData);
        break;
      case TransportType.none:
        throw StateError('No active transport connection');
    }
  }
  
  /// Start audio capture (WebRTC only)
  Future<void> startAudioCapture() async {
    if (_activeTransport == TransportType.webrtc) {
      await _webrtcClient?.startAudioCapture();
    } else {
      _logger.warning('Audio capture not available with current transport: $_activeTransport');
    }
  }
  
  /// Stop audio capture (WebRTC only)
  Future<void> stopAudioCapture() async {
    await _webrtcClient?.stopAudioCapture();
  }
  
  /// Update transport status and notify listeners
  void _updateStatus(TransportStatus status) {
    _statusController.add(status);
  }
  
  /// Close all connections and cleanup
  Future<void> close() async {
    _logger.info('Closing transport manager');
    
    // Cancel all stream subscriptions
    await _webrtcStateSub?.cancel();
    await _webrtcMessageSub?.cancel();
    await _webrtcAudioSub?.cancel();
    await _websocketStateSub?.cancel();
    await _websocketMessageSub?.cancel();
    await _websocketAudioSub?.cancel();
    
    // Close clients
    await _webrtcClient?.close();
    await _websocketClient?.close();
    
    // Clear references and securely clear token
    _webrtcClient = null;
    _websocketClient = null;
    _webrtcStateSub = null;
    _webrtcMessageSub = null;
    _webrtcAudioSub = null;
    _websocketStateSub = null;
    _websocketMessageSub = null;
    _websocketAudioSub = null;
    
    // Securely clear token and expiry
    _currentToken = null;
    _tokenExpiry = null;
    _activeTransport = TransportType.none;
    
    await _messageController.close();
    await _audioController.close();
    await _statusController.close();
    
    _logger.info('Transport manager closed');
  }
}

/// Available transport types
enum TransportType {
  none,
  webrtc,
  webSocket,
}

/// Transport connection states
enum TransportState {
  disconnected,
  connecting,
  connected,
  error,
  failed,
}

/// Transport status information
class TransportStatus {
  final TransportType activeTransport;
  final TransportState state;
  final String? error;
  final bool failedOver;
  
  const TransportStatus({
    required this.activeTransport,
    required this.state,
    this.error,
    this.failedOver = false,
  });
  
  @override
  String toString() {
    return 'TransportStatus(transport: $activeTransport, state: $state, failedOver: $failedOver)';
  }
}