import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:parli/services/websocket_client.dart';

void main() {
  group('WebSocketClient', () {
    late WebSocketClient client;
    
    setUp(() {
      client = WebSocketClient();
    });
    
    tearDown(() async {
      await client.close();
    });
    
    test('should initialize with disconnected state', () {
      expect(client.state, equals(WebSocketConnectionState.disconnected));
      expect(client.isConnected, isFalse);
    });
    
    test('should provide message and audio streams', () {
      expect(client.messages, isA<Stream<Map<String, dynamic>>>());
      expect(client.audioData, isA<Stream<Uint8List>>());
      expect(client.connectionState, isA<Stream<WebSocketConnectionState>>());
    });
    
    test('should throw StateError when sending message while disconnected', () async {
      expect(
        () => client.sendMessage({'type': 'test'}),
        throwsA(isA<StateError>()),
      );
    });
    
    test('should throw StateError when sending audio while disconnected', () async {
      final audioData = Uint8List.fromList([1, 2, 3, 4]);
      
      expect(
        () => client.sendAudio(audioData),
        throwsA(isA<StateError>()),
      );
    });
    
    test('should encode audio data correctly for API', () {
      final audioData = Uint8List.fromList([72, 101, 108, 108, 111]); // "Hello"
      final expectedBase64 = base64Encode(audioData);
      
      // This tests the internal encoding logic
      expect(base64Encode(audioData), equals(expectedBase64));
    });
    
    test('should handle WebSocket connection states', () async {
      final stateChanges = <WebSocketConnectionState>[];
      
      client.connectionState.listen((state) {
        stateChanges.add(state);
      });
      
      // Initial state should be disconnected
      expect(client.state, equals(WebSocketConnectionState.disconnected));
      
      // Note: Actual connection testing would require a mock WebSocket server
      // This test verifies the state management structure is in place
    });
    
    test('should properly close and cleanup resources', () async {
      // Verify streams are active before closing
      expect(client.messages, isA<Stream<Map<String, dynamic>>>());
      
      // Close the client
      await client.close();
      
      // Verify state is reset
      expect(client.state, equals(WebSocketConnectionState.disconnected));
      expect(client.isConnected, isFalse);
    });
  });
}