import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logging/logging.dart';
import 'webrtc_client.dart';
import 'token_service.dart';

/// Manages dual OpenAI Realtime API sessions for bidirectional translation
/// Maintains two persistent sessions: A→B (e.g., EN→ZH) and B→A (e.g., ZH→EN)
/// This prevents context switching overhead and enables true real-time translation
class RealtimeSessionManager {
  static final _logger = Logger('RealtimeSessionManager');
  
  // Dual WebRTC sessions for bidirectional translation
  WebRTCClient? _sessionAB;  // A→B translation (e.g., EN→ZH)
  WebRTCClient? _sessionBA;  // B→A translation (e.g., ZH→EN)
  
  // Token service for ephemeral authentication
  final TokenService _tokenService;
  
  // Session configuration
  final String _languageA;
  final String _languageB;
  
  // Stream subscriptions for session management
  StreamSubscription? _sessionABMessages;
  StreamSubscription? _sessionABState;
  StreamSubscription? _sessionBAMessages;
  StreamSubscription? _sessionBAState;
  
  // Stream controllers for unified interface
  final StreamController<TranslationMessage> _messageController = 
      StreamController<TranslationMessage>.broadcast();
  final StreamController<SessionStatus> _statusController = 
      StreamController<SessionStatus>.broadcast();
  final StreamController<MediaStream> _remoteStreamController = 
      StreamController<MediaStream>.broadcast();
  
  // Session state tracking
  SessionDirection? _activeDirection;
  bool _isInitializing = false;
  
  /// Initialize session manager with language pair
  /// 
  /// [languageA] - Source language (e.g., 'en')
  /// [languageB] - Target language (e.g., 'zh-CN')
  /// [tokenService] - Token service for authentication
  RealtimeSessionManager({
    required String languageA,
    required String languageB,
    TokenService? tokenService,
  }) : _languageA = languageA,
       _languageB = languageB,
       _tokenService = tokenService ?? TokenService();

  /// Stream of translation messages from both sessions
  Stream<TranslationMessage> get messages => _messageController.stream;

  /// Stream of session status updates
  Stream<SessionStatus> get status => _statusController.stream;

  /// Stream of remote audio streams for playback
  Stream<MediaStream> get remoteStreams => _remoteStreamController.stream;

  /// Current active translation direction
  SessionDirection? get activeDirection => _activeDirection;

  /// Whether both sessions are connected and ready
  bool get isReady => 
      _sessionAB?.isConnected == true && _sessionBA?.isConnected == true;

  /// Initialize both translation sessions
  /// 
  /// Creates persistent WebRTC connections to OpenAI Realtime API
  /// for both translation directions to avoid context switching
  Future<void> initialize() async {
    if (_isInitializing) {
      throw StateError('Session manager already initializing');
    }
    
    _isInitializing = true;
    _logger.info('Initializing dual Realtime sessions ($_languageA↔$_languageB)');
    
    try {
      _updateStatus(SessionStatus(
        sessionAB: SessionState.connecting,
        sessionBA: SessionState.connecting,
        message: 'Establishing translation sessions...',
      ));

      // Get ephemeral token for both sessions
      final token = await _tokenService.getToken();
      _logger.info('Obtained ephemeral token for session initialization');

      // Initialize both sessions concurrently for optimal startup time
      await Future.wait([
        _initializeSessionAB(token),
        _initializeSessionBA(token),
      ]);

      _updateStatus(SessionStatus(
        sessionAB: SessionState.connected,
        sessionBA: SessionState.connected,
        message: 'Both translation sessions ready',
      ));

      _logger.info('Dual Realtime sessions initialized successfully');
      
    } catch (e) {
      _logger.severe('Failed to initialize Realtime sessions: $e');
      _updateStatus(SessionStatus(
        sessionAB: SessionState.error,
        sessionBA: SessionState.error,
        message: 'Session initialization failed: $e',
      ));
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// Initialize A→B translation session
  Future<void> _initializeSessionAB(String token) async {
    _logger.info('Initializing A→B session ($_languageA→$_languageB)');
    
    _sessionAB = WebRTCClient();
    
    // Set up message handling for A→B session
    _sessionABMessages = _sessionAB!.messages.listen((message) {
      _handleSessionMessage(message, SessionDirection.aToB);
    });
    
    // Monitor A→B connection state
    _sessionABState = _sessionAB!.connectionState.listen((state) {
      _handleSessionStateChange(state, SessionDirection.aToB);
    });
    
    // Connect with session-specific configuration
    await _sessionAB!.connect(token: token);
    
    // Configure session for A→B translation
    await _configureSession(_sessionAB!, _languageA, _languageB);
    
    // Set up remote stream handling
    final remoteStream = _sessionAB!.remoteStream;
    if (remoteStream != null) {
      _remoteStreamController.add(remoteStream);
    }
  }

  /// Initialize B→A translation session  
  Future<void> _initializeSessionBA(String token) async {
    _logger.info('Initializing B→A session ($_languageB→$_languageA)');
    
    _sessionBA = WebRTCClient();
    
    // Set up message handling for B→A session
    _sessionBAMessages = _sessionBA!.messages.listen((message) {
      _handleSessionMessage(message, SessionDirection.bToA);
    });
    
    // Monitor B→A connection state
    _sessionBAState = _sessionBA!.connectionState.listen((state) {
      _handleSessionStateChange(state, SessionDirection.bToA);
    });
    
    // Connect with session-specific configuration
    await _sessionBA!.connect(token: token);
    
    // Configure session for B→A translation
    await _configureSession(_sessionBA!, _languageB, _languageA);
    
    // Set up remote stream handling
    final remoteStream = _sessionBA!.remoteStream;
    if (remoteStream != null) {
      _remoteStreamController.add(remoteStream);
    }
  }

  /// Configure Realtime session for specific translation direction
  Future<void> _configureSession(
    WebRTCClient session, 
    String sourceLanguage, 
    String targetLanguage,
  ) async {
    _logger.info('Configuring session: $sourceLanguage→$targetLanguage');
    
    // Send session configuration to OpenAI Realtime API
    await session.sendMessage({
      'type': 'session.update',
      'session': {
        'modalities': ['text', 'audio'],
        'instructions': 'You are a real-time translator. Translate from $sourceLanguage to $targetLanguage. '
                      'Respond only with the translated content, no explanations or additional text.',
        'voice': 'alloy',
        'input_audio_format': 'pcm16',
        'output_audio_format': 'pcm16',
        'input_audio_transcription': {
          'model': 'whisper-1',
          'language': sourceLanguage,
        },
        'turn_detection': {
          'type': 'server_vad',
          'threshold': 0.5,
          'prefix_padding_ms': 300,
          'silence_duration_ms': 200,
        },
        'tools': [],
        'tool_choice': 'none',
        'temperature': 0.6,
        'max_response_output_tokens': 4096,
      },
    });
    
    _logger.fine('Session configured for $sourceLanguage→$targetLanguage translation');
  }

  /// Handle incoming messages from Realtime sessions
  void _handleSessionMessage(Map<String, dynamic> message, SessionDirection direction) {
    final messageType = message['type'] as String?;
    _logger.fine('Received message from ${direction.name} session: $messageType');
    
    // Forward message with direction context
    _messageController.add(TranslationMessage(
      direction: direction,
      type: messageType ?? 'unknown',
      data: message,
      timestamp: DateTime.now(),
    ));
  }

  /// Handle session state changes
  void _handleSessionStateChange(RTCPeerConnectionState state, SessionDirection direction) {
    _logger.info('${direction.name} session state changed: $state');
    
    final sessionState = _mapRTCStateToSessionState(state);
    
    // Update status with new session state
    final currentStatus = SessionStatus(
      sessionAB: direction == SessionDirection.aToB ? sessionState : 
                (_sessionAB?.isConnected == true ? SessionState.connected : SessionState.disconnected),
      sessionBA: direction == SessionDirection.bToA ? sessionState :
                (_sessionBA?.isConnected == true ? SessionState.connected : SessionState.disconnected),
      message: '${direction.name} session: ${state.toString().split('.').last}',
    );
    
    _updateStatus(currentStatus);
    
    // Handle connection failures
    if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
        state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
      _handleSessionFailure(direction);
    }
  }

  /// Map WebRTC state to session state
  SessionState _mapRTCStateToSessionState(RTCPeerConnectionState rtcState) {
    switch (rtcState) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        return SessionState.connected;
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        return SessionState.connecting;
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        return SessionState.error;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        return SessionState.disconnected;
      default:
        return SessionState.disconnected;
    }
  }

  /// Handle session connection failures
  Future<void> _handleSessionFailure(SessionDirection direction) async {
    _logger.warning('${direction.name} session failed, attempting reconnection');
    
    try {
      // Get fresh token for reconnection
      final token = await _tokenService.getToken();
      
      // Reconnect the failed session
      if (direction == SessionDirection.aToB) {
        await _reconnectSessionAB(token);
      } else {
        await _reconnectSessionBA(token);
      }
      
      _logger.info('${direction.name} session reconnected successfully');
      
    } catch (e) {
      _logger.severe('Failed to reconnect ${direction.name} session: $e');
      _updateStatus(SessionStatus(
        sessionAB: direction == SessionDirection.aToB ? SessionState.error : 
                  (_sessionAB?.isConnected == true ? SessionState.connected : SessionState.disconnected),
        sessionBA: direction == SessionDirection.bToA ? SessionState.error :
                  (_sessionBA?.isConnected == true ? SessionState.connected : SessionState.disconnected),
        message: 'Failed to reconnect ${direction.name} session',
      ));
    }
  }

  /// Reconnect A→B session
  Future<void> _reconnectSessionAB(String token) async {
    await _sessionABMessages?.cancel();
    await _sessionABState?.cancel();
    await _sessionAB?.close();
    
    await _initializeSessionAB(token);
  }

  /// Reconnect B→A session
  Future<void> _reconnectSessionBA(String token) async {
    await _sessionBAMessages?.cancel();
    await _sessionBAState?.cancel();
    await _sessionBA?.close();
    
    await _initializeSessionBA(token);
  }

  /// Start translation in specified direction
  /// 
  /// [direction] - Translation direction (A→B or B→A)
  /// Sets up audio capture for the active session
  Future<void> startTranslation(SessionDirection direction) async {
    if (!isReady) {
      throw StateError('Sessions not ready for translation');
    }
    
    _activeDirection = direction;
    _logger.info('Starting translation: ${direction.name}');
    
    // Start audio capture on the active session
    final activeSession = direction == SessionDirection.aToB ? _sessionAB! : _sessionBA!;
    await activeSession.startAudioCapture();
    
    _updateStatus(SessionStatus(
      sessionAB: _sessionAB?.isConnected == true ? SessionState.connected : SessionState.disconnected,
      sessionBA: _sessionBA?.isConnected == true ? SessionState.connected : SessionState.disconnected,
      activeDirection: direction,
      message: 'Translation active: ${direction.name}',
    ));
  }

  /// Stop active translation
  Future<void> stopTranslation() async {
    if (_activeDirection == null) return;
    
    _logger.info('Stopping translation');
    
    // Stop audio capture on both sessions
    await _sessionAB?.stopAudioCapture();
    await _sessionBA?.stopAudioCapture();
    
    _activeDirection = null;
    
    _updateStatus(SessionStatus(
      sessionAB: _sessionAB?.isConnected == true ? SessionState.connected : SessionState.disconnected,
      sessionBA: _sessionBA?.isConnected == true ? SessionState.connected : SessionState.disconnected,
      message: 'Translation stopped',
    ));
  }

  /// Send audio to active translation session
  Future<void> sendAudio(Uint8List audioData) async {
    if (_activeDirection == null) {
      throw StateError('No active translation session');
    }
    
    final activeSession = _activeDirection == SessionDirection.aToB ? _sessionAB! : _sessionBA!;
    await activeSession.sendAudio(audioData);
  }

  /// Send message to specific session
  Future<void> sendMessage(Map<String, dynamic> message, SessionDirection direction) async {
    final session = direction == SessionDirection.aToB ? _sessionAB : _sessionBA;
    if (session == null) {
      throw StateError('${direction.name} session not available');
    }
    
    await session.sendMessage(message);
  }

  /// Update session status and notify listeners
  void _updateStatus(SessionStatus status) {
    _statusController.add(status);
  }

  /// Close both sessions and cleanup resources
  Future<void> close() async {
    _logger.info('Closing Realtime session manager');
    
    try {
      // Cancel all subscriptions
      await _sessionABMessages?.cancel();
      await _sessionABState?.cancel();
      await _sessionBAMessages?.cancel();
      await _sessionBAState?.cancel();
      
      // Close both sessions
      await _sessionAB?.close();
      await _sessionBA?.close();
      
      // Clear references
      _sessionAB = null;
      _sessionBA = null;
      _activeDirection = null;
      
      // Close stream controllers
      await _messageController.close();
      await _statusController.close();
      await _remoteStreamController.close();
      
      // Dispose token service
      _tokenService.dispose();
      
      _logger.info('Realtime session manager closed successfully');
      
    } catch (e) {
      _logger.severe('Error closing session manager: $e');
      rethrow;
    }
  }
}

/// Translation direction for dual sessions
enum SessionDirection {
  aToB,  // A→B translation (e.g., EN→ZH)
  bToA,  // B→A translation (e.g., ZH→EN)
}

extension SessionDirectionExtension on SessionDirection {
  String get name {
    switch (this) {
      case SessionDirection.aToB:
        return 'A→B';
      case SessionDirection.bToA:
        return 'B→A';
    }
  }
}

/// Session connection states
enum SessionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Session status information
class SessionStatus {
  final SessionState sessionAB;
  final SessionState sessionBA;
  final SessionDirection? activeDirection;
  final String? message;
  
  const SessionStatus({
    required this.sessionAB,
    required this.sessionBA,
    this.activeDirection,
    this.message,
  });
  
  @override
  String toString() {
    return 'SessionStatus(AB: $sessionAB, BA: $sessionBA, active: $activeDirection)';
  }
}

/// Translation message with direction context
class TranslationMessage {
  final SessionDirection direction;
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  
  const TranslationMessage({
    required this.direction,
    required this.type,
    required this.data,
    required this.timestamp,
  });
  
  @override
  String toString() {
    return 'TranslationMessage(${direction.name}: $type)';
  }
}