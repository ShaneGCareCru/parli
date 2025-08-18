import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logging/logging.dart';

/// WebSocket client for OpenAI Realtime API connections
/// Provides fallback transport for environments with WebRTC restrictions
class WebSocketClient {
  static final _logger = Logger('WebSocketClient');
  
  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  
  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Uint8List> _audioController = 
      StreamController<Uint8List>.broadcast();
  final StreamController<WebSocketConnectionState> _stateController = 
      StreamController<WebSocketConnectionState>.broadcast();
  
  /// Stream of incoming messages from OpenAI Realtime API
  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  
  /// Stream of incoming audio data
  Stream<Uint8List> get audioData => _audioController.stream;
  
  /// Stream of connection state changes
  Stream<WebSocketConnectionState> get connectionState => _stateController.stream;
  
  WebSocketConnectionState _currentState = WebSocketConnectionState.disconnected;
  
  /// Current connection state
  WebSocketConnectionState get state => _currentState;
  
  /// Whether client is connected and ready
  bool get isConnected => _currentState == WebSocketConnectionState.connected;
  
  String? _token;
  Uri? _serverUri;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  /// Connect to OpenAI Realtime API via WebSocket
  /// 
  /// [token] - Ephemeral token from token service
  /// [serverUrl] - WebSocket server URL (defaults to OpenAI Realtime API)
  Future<void> connect({
    required String token,
    String? serverUrl,
  }) async {
    _token = token;
    _serverUri = Uri.parse(serverUrl ?? 'wss://api.openai.com/v1/realtime');
    
    await _performConnection();
  }
  
  /// Internal connection logic with retry capability
  Future<void> _performConnection() async {
    try {
      _logger.info('Connecting to WebSocket server: $_serverUri');
      _updateState(WebSocketConnectionState.connecting);
      
      // Connect to WebSocket (headers would be added via URL params or connection setup)
      // Note: WebSocket headers implementation depends on the specific server setup
      _channel = WebSocketChannel.connect(_serverUri!);
      
      // Listen for messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
      );
      
      // Start heartbeat to keep connection alive
      _startHeartbeat();
      
      _updateState(WebSocketConnectionState.connected);
      _reconnectAttempts = 0;
      
      _logger.info('WebSocket connected successfully');
      
      // Send initial session configuration
      await _sendSessionConfig();
      
    } catch (e) {
      _logger.severe('WebSocket connection failed: $e');
      _updateState(WebSocketConnectionState.error);
      await _scheduleReconnect();
    }
  }
  
  /// Handle incoming WebSocket messages
  void _handleMessage(dynamic data) {
    try {
      final message = json.decode(data as String);
      _logger.fine('Received message: ${message['type']}');
      
      // Handle different message types
      switch (message['type']) {
        case 'response.audio.delta':
          _handleAudioDelta(message);
          break;
        case 'session.created':
        case 'session.updated':
          _logger.info('Session ${message['type']}: ${message['session']['id']}');
          break;
        case 'error':
          _logger.warning('Server error: ${message['error']}');
          break;
      }
      
      _messageController.add(message);
    } catch (e) {
      _logger.warning('Failed to parse incoming message: $e');
    }
  }
  
  /// Handle audio delta messages
  void _handleAudioDelta(Map<String, dynamic> message) {
    if (message['delta'] != null) {
      try {
        final audioBytes = base64Decode(message['delta']);
        _audioController.add(audioBytes);
        _logger.fine('Received audio delta: ${audioBytes.length} bytes');
      } catch (e) {
        _logger.warning('Failed to decode audio delta: $e');
      }
    }
  }
  
  /// Handle WebSocket errors
  void _handleError(error) {
    _logger.severe('WebSocket error: $error');
    _updateState(WebSocketConnectionState.error);
    _scheduleReconnect();
  }
  
  /// Handle WebSocket disconnection
  void _handleDisconnection() {
    _logger.info('WebSocket disconnected');
    _stopHeartbeat();
    _updateState(WebSocketConnectionState.disconnected);
    _scheduleReconnect();
  }
  
  /// Update connection state and notify listeners
  void _updateState(WebSocketConnectionState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _stateController.add(newState);
    }
  }
  
  /// Schedule automatic reconnection with exponential backoff
  Future<void> _scheduleReconnect() async {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _logger.severe('Max reconnection attempts reached, giving up');
      _updateState(WebSocketConnectionState.failed);
      return;
    }
    
    _reconnectAttempts++;
    final delay = Duration(seconds: 2 << (_reconnectAttempts - 1)); // Exponential backoff
    
    _logger.info('Scheduling reconnection attempt $_reconnectAttempts in ${delay.inSeconds}s');
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_currentState != WebSocketConnectionState.connected) {
        _performConnection();
      }
    });
  }
  
  /// Send initial session configuration
  Future<void> _sendSessionConfig() async {
    await sendMessage({
      'type': 'session.update',
      'session': {
        'modalities': ['text', 'audio'],
        'instructions': 'You are a helpful voice translator for business travelers.',
        'voice': 'coral',
        'input_audio_format': 'pcm16',
        'output_audio_format': 'pcm16',
        'input_audio_transcription': {
          'model': 'whisper-1',
        },
        'turn_detection': {
          'type': 'server_vad',
          'threshold': 0.5,
          'prefix_padding_ms': 300,
          'silence_duration_ms': 500,
        },
      },
    });
  }
  
  /// Start heartbeat timer to keep connection alive
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (isConnected) {
        sendMessage({'type': 'ping'}).catchError((error) {
          _logger.warning('Heartbeat failed: $error');
        });
      }
    });
  }
  
  /// Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
  
  /// Send message to OpenAI Realtime API
  Future<void> sendMessage(Map<String, dynamic> message) async {
    if (!isConnected) {
      throw StateError('WebSocket not connected');
    }
    
    try {
      final messageJson = json.encode(message);
      _channel!.sink.add(messageJson);
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
      throw StateError('WebSocket not connected');
    }
    
    try {
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
  
  /// Commit audio buffer (end of turn)
  Future<void> commitAudioBuffer() async {
    await sendMessage({
      'type': 'input_audio_buffer.commit',
    });
    _logger.fine('Audio buffer committed');
  }
  
  /// Clear audio buffer
  Future<void> clearAudioBuffer() async {
    await sendMessage({
      'type': 'input_audio_buffer.clear',
    });
    _logger.fine('Audio buffer cleared');
  }
  
  /// Generate response from current conversation state
  Future<void> generateResponse() async {
    await sendMessage({
      'type': 'response.create',
      'response': {
        'modalities': ['text', 'audio'],
        'instructions': 'Please translate the input to the target language.',
      },
    });
    _logger.fine('Response generation requested');
  }
  
  /// Close WebSocket connection and cleanup resources
  Future<void> close() async {
    _logger.info('Closing WebSocket connection');
    
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    
    _updateState(WebSocketConnectionState.disconnected);
    
    await _channel?.sink.close();
    _channel = null;
    
    await _messageController.close();
    await _audioController.close();
    await _stateController.close();
    
    _logger.info('WebSocket connection closed successfully');
  }
}

/// WebSocket connection states
enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  error,
  failed,
}