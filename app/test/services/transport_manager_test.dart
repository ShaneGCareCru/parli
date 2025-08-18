import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:parli/services/transport_manager.dart';

void main() {
  group('TransportManager', () {
    late TransportManager manager;
    
    setUp(() {
      manager = TransportManager();
    });
    
    tearDown(() async {
      await manager.close();
    });
    
    test('should initialize with no active transport', () {
      expect(manager.activeTransport, equals(TransportType.none));
      expect(manager.preferredTransport, equals(TransportType.webrtc));
      expect(manager.isConnected, isFalse);
    });
    
    test('should provide message and audio streams', () {
      expect(manager.messages, isA<Stream<Map<String, dynamic>>>());
      expect(manager.audioData, isA<Stream<Uint8List>>());
      expect(manager.status, isA<Stream<TransportStatus>>());
    });
    
    test('should throw StateError when sending message without connection', () async {
      expect(
        () => manager.sendMessage({'type': 'test'}),
        throwsA(isA<StateError>()),
      );
    });
    
    test('should throw StateError when sending audio without connection', () async {
      final audioData = Uint8List.fromList([1, 2, 3, 4]);
      
      expect(
        () => manager.sendAudio(audioData),
        throwsA(isA<StateError>()),
      );
    });
    
    test('should handle transport status changes', () async {
      final statusChanges = <TransportStatus>[];
      
      manager.status.listen((status) {
        statusChanges.add(status);
      });
      
      // Verify initial state
      expect(manager.activeTransport, equals(TransportType.none));
      
      // Note: Actual connection testing would require mock implementations
      // This test verifies the status management structure is in place
    });
    
    test('TransportStatus should contain correct information', () {
      const status = TransportStatus(
        activeTransport: TransportType.webrtc,
        state: TransportState.connected,
        failedOver: true,
      );
      
      expect(status.activeTransport, equals(TransportType.webrtc));
      expect(status.state, equals(TransportState.connected));
      expect(status.failedOver, isTrue);
      expect(status.error, isNull);
    });
    
    test('should properly close and cleanup resources', () async {
      // Verify streams are active before closing
      expect(manager.messages, isA<Stream<Map<String, dynamic>>>());
      
      // Close the manager
      await manager.close();
      
      // Verify state is reset
      expect(manager.activeTransport, equals(TransportType.none));
      expect(manager.isConnected, isFalse);
    });
  });
  
  group('TransportType enum', () {
    test('should have correct values', () {
      expect(TransportType.values.length, equals(3));
      expect(TransportType.values, contains(TransportType.none));
      expect(TransportType.values, contains(TransportType.webrtc));
      expect(TransportType.values, contains(TransportType.webSocket));
    });
  });
  
  group('TransportState enum', () {
    test('should have correct values', () {
      expect(TransportState.values.length, equals(5));
      expect(TransportState.values, contains(TransportState.disconnected));
      expect(TransportState.values, contains(TransportState.connecting));
      expect(TransportState.values, contains(TransportState.connected));
      expect(TransportState.values, contains(TransportState.error));
      expect(TransportState.values, contains(TransportState.failed));
    });
  });
  
  group('Enhanced Error Handling', () {
    test('should handle connection failures gracefully', () async {
      final failureManager = TransportManager();
      
      try {
        // Test with completely invalid token/URL
        await failureManager.connect(token: 'invalid-token');
        // If no exception is thrown, we still need to verify proper handling
        expect(failureManager.activeTransport, isNot(equals(TransportType.none)));
      } catch (e) {
        // Expected behavior - connection should fail with invalid token
        expect(e, isA<Exception>());
        expect(e.toString(), contains('Failed to establish connection'));
      }
      
      await failureManager.close();
    });
    
    test('should validate transport switching logic', () async {
      final switchingManager = TransportManager();
      
      expect(switchingManager.activeTransport, equals(TransportType.none));
      expect(switchingManager.preferredTransport, equals(TransportType.webrtc));
      
      // Test that manual switching throws UnimplementedError for now
      expect(
        () => switchingManager.switchTransport(TransportType.webSocket),
        throwsA(isA<UnimplementedError>()),
      );
      
      await switchingManager.close();
    });
  });
}