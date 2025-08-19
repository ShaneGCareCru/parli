import 'package:flutter/material.dart';
import '../widgets/ptt_button.dart';
import '../services/transport_manager.dart';
import '../services/token_service.dart';
import '../services/notification_service.dart';

class PTTScreen extends StatefulWidget {
  final String languageA;
  final String languageB;
  final TokenService? tokenService; // Add dependency injection
  
  const PTTScreen({
    super.key,
    this.languageA = "English",
    this.languageB = "中文",
    this.tokenService, // Optional for backward compatibility
  });

  @override
  State<PTTScreen> createState() => _PTTScreenState();
}

class _PTTScreenState extends State<PTTScreen> {
  bool _isButtonAEnabled = true;
  bool _isButtonBEnabled = true;
  String _lastEvent = "No events yet";
  
  // Transport manager for connection handling
  TransportManager? _transportManager;
  String _connectionStatus = "Disconnected";
  int _retryAttempts = 0;
  static const int _maxRetryAttempts = 5;

  @override
  void initState() {
    super.initState();
    _initializeConnection();
  }

  @override
  void dispose() {
    _transportManager?.close();
    super.dispose();
  }

  /// Initialize transport manager and attempt connection
  Future<void> _initializeConnection() async {
    try {
      setState(() {
        _connectionStatus = "Connecting...";
      });

      // Use dependency injection with fallback to default
      final tokenService = widget.tokenService ?? TokenService();
      _transportManager = TransportManager(tokenService: tokenService);
      
      // Listen to connection status updates with error handling
      _transportManager!.status.listen(
        (status) {
          if (mounted) {
            setState(() {
              _connectionStatus = _getStatusString(status);
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _connectionStatus = "Status error: $error";
            });
          }
        },
      );

      // Attempt connection with token refresh
      await _transportManager!.connect();
      
      // Reset retry attempts on successful connection
      _retryAttempts = 0;
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionStatus = "Connection failed";
        });
        
        // Handle token service errors with user-visible notifications
        if (e is TokenServiceException) {
          NotificationService.showTokenError(
            context, 
            e, 
            onRetry: _retryConnection,
          );
        } else {
          NotificationService.showInfo(context, 'Connection failed: $e');
        }
      }
    }
  }

  /// Retry connection with exponential backoff
  Future<void> _retryConnection() async {
    if (_retryAttempts >= _maxRetryAttempts) {
      NotificationService.showInfo(
        context, 
        'Maximum retry attempts reached. Please check your connection.',
      );
      return;
    }

    _retryAttempts++;
    final delay = Duration(seconds: (2 << _retryAttempts).clamp(2, 30));
    
    setState(() {
      _connectionStatus = "Retrying in ${delay.inSeconds}s (attempt $_retryAttempts)...";
    });
    
    await Future.delayed(delay);
    await _initializeConnection();
  }

  /// Convert transport status to user-friendly string
  String _getStatusString(TransportStatus status) {
    switch (status.state) {
      case TransportState.connecting:
        return "Connecting (${status.activeTransport.name})...";
      case TransportState.connected:
        final transportName = status.activeTransport == TransportType.webrtc 
            ? "WebRTC" : "WebSocket";
        final failover = status.failedOver ? " (failover)" : "";
        return "Connected ($transportName)$failover";
      case TransportState.error:
        return "Error: ${status.error ?? 'Unknown error'}";
      case TransportState.failed:
        return "Failed: ${status.error ?? 'Connection failed'}";
      case TransportState.disconnected:
        return "Disconnected";
    }
  }

  void _handleButtonAEvent(PTTEvent event) {
    setState(() {
      // Fix: Use event.name instead of fragile string parsing
      _lastEvent = "Button A (${widget.languageA} → ${widget.languageB}): ${event.name}";
      if (event == PTTEvent.press) {
        _isButtonBEnabled = false;
      } else if (event == PTTEvent.release) {
        _isButtonBEnabled = true;
      }
    });
    
    _logEvent("Button A", event);
  }

  void _handleButtonBEvent(PTTEvent event) {
    setState(() {
      // Fix: Use event.name instead of fragile string parsing
      _lastEvent = "Button B (${widget.languageB} → ${widget.languageA}): ${event.name}";
      if (event == PTTEvent.press) {
        _isButtonAEnabled = false;
      } else if (event == PTTEvent.release) {
        _isButtonAEnabled = true;
      }
    });
    
    _logEvent("Button B", event);
  }

  void _logEvent(String buttonName, PTTEvent event) {
    debugPrint("$buttonName event: ${event.toString()}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parli - Voice Translator'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Translation Mode',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(widget.languageA, style: const TextStyle(fontSize: 16)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Icon(Icons.swap_horiz, size: 24),
                        ),
                        Text(widget.languageB, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Hold to Speak',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                      Column(
                        children: [
                          PTTButton(
                            label: widget.languageA,
                            onEvent: _handleButtonAEvent,
                            isEnabled: _isButtonAEnabled,
                            primaryColor: Colors.blue,
                            icon: Icons.mic,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'To ${widget.languageB}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          PTTButton(
                            label: widget.languageB,
                            onEvent: _handleButtonBEvent,
                            isEnabled: _isButtonBEnabled,
                            primaryColor: Colors.green,
                            icon: Icons.mic,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'To ${widget.languageA}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status: $_connectionStatus',
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Debug Info',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last Event: $_lastEvent',
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Button A Enabled: $_isButtonAEnabled',
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                    Text(
                      'Button B Enabled: $_isButtonBEnabled',
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}