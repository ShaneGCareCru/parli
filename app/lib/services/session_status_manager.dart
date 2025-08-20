import 'dart:async';
import 'package:logging/logging.dart';
import 'realtime_session_manager.dart';

/// Manages session status tracking and notifications for dual Realtime sessions
class SessionStatusManager {
  static final _logger = Logger('SessionStatusManager');
  
  final StreamController<SessionStatus> _statusController = 
      StreamController<SessionStatus>.broadcast();
  
  SessionStatus _currentStatus = const SessionStatus(
    sessionAB: SessionState.disconnected,
    sessionBA: SessionState.disconnected,
  );

  /// Stream of session status updates
  Stream<SessionStatus> get status => _statusController.stream;

  /// Current session status
  SessionStatus get currentStatus => _currentStatus;

  /// Update session status and notify listeners
  void updateStatus(SessionStatus status) {
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
      _logger.fine('Status updated: $status');
    }
  }

  /// Update individual session state
  void updateSessionState(SessionDirection direction, SessionState state, {String? message}) {
    final status = SessionStatus(
      sessionAB: direction == SessionDirection.aToB ? state : _currentStatus.sessionAB,
      sessionBA: direction == SessionDirection.bToA ? state : _currentStatus.sessionBA,
      activeDirection: _currentStatus.activeDirection,
      message: message ?? _currentStatus.message,
    );
    updateStatus(status);
  }

  /// Update active translation direction
  void updateActiveDirection(SessionDirection? direction, {String? message}) {
    final status = SessionStatus(
      sessionAB: _currentStatus.sessionAB,
      sessionBA: _currentStatus.sessionBA,
      activeDirection: direction,
      message: message ?? _currentStatus.message,
    );
    updateStatus(status);
  }

  /// Check if both sessions are ready
  bool get areBothSessionsReady =>
      _currentStatus.sessionAB == SessionState.connected &&
      _currentStatus.sessionBA == SessionState.connected;

  /// Check if any session has error
  bool get hasAnyError =>
      _currentStatus.sessionAB == SessionState.error ||
      _currentStatus.sessionBA == SessionState.error;

  /// Close status manager and cleanup resources
  Future<void> close() async {
    if (!_statusController.isClosed) {
      await _statusController.close();
    }
  }
}