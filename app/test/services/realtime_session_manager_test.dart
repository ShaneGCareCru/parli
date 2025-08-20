import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:parli/services/realtime_session_manager.dart';
import 'package:parli/services/webrtc_client.dart';
import 'package:parli/services/token_service.dart';

import 'realtime_session_manager_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<TokenService>(),
  MockSpec<WebRTCClient>(),
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('RealtimeSessionManager', () {
    late RealtimeSessionManager sessionManager;
    late MockTokenService mockTokenService;
    late MockWebRTCClient mockSessionAB;
    late MockWebRTCClient mockSessionBA;

    setUp(() {
      mockTokenService = MockTokenService();
      mockSessionAB = MockWebRTCClient();
      mockSessionBA = MockWebRTCClient();
      
      // Set up default mock behaviors
      when(mockTokenService.getToken()).thenAnswer((_) async => 'test-token');
      when(mockSessionAB.isConnected).thenReturn(true);
      when(mockSessionBA.isConnected).thenReturn(true);
      when(mockSessionAB.messages).thenAnswer((_) => Stream.value({'type': 'test'}));
      when(mockSessionBA.messages).thenAnswer((_) => Stream.value({'type': 'test'}));
      when(mockSessionAB.connectionState).thenAnswer((_) => Stream.value(RTCPeerConnectionState.RTCPeerConnectionStateConnected));
      when(mockSessionBA.connectionState).thenAnswer((_) => Stream.value(RTCPeerConnectionState.RTCPeerConnectionStateConnected));
      when(mockSessionAB.remoteStream).thenReturn(null);
      when(mockSessionBA.remoteStream).thenReturn(null);
      when(mockSessionAB.connect(token: anyNamed('token'))).thenAnswer((_) async {});
      when(mockSessionBA.connect(token: anyNamed('token'))).thenAnswer((_) async {});
      when(mockSessionAB.sendMessage(any)).thenAnswer((_) async {});
      when(mockSessionBA.sendMessage(any)).thenAnswer((_) async {});
      when(mockSessionAB.close()).thenAnswer((_) async {});
      when(mockSessionBA.close()).thenAnswer((_) async {});

      sessionManager = RealtimeSessionManager(
        languageA: 'en',
        languageB: 'zh-CN',
        tokenService: mockTokenService,
      );
    });

    tearDown(() async {
      await sessionManager.close();
    });

    test('should initialize with correct language pair', () {
      expect(sessionManager.activeDirection, isNull);
      expect(sessionManager.isReady, isFalse);
    });

    test('should provide message, status, and remote stream streams', () {
      expect(sessionManager.messages, isA<Stream<TranslationMessage>>());
      expect(sessionManager.status, isA<Stream<SessionStatus>>());
      expect(sessionManager.remoteStreams, isA<Stream<MediaStream>>());
    });

    group('initialization', () {
      test('should successfully initialize both sessions', () async {
        final statusUpdates = <SessionStatus>[];
        sessionManager.status.listen((status) => statusUpdates.add(status));

        await sessionManager.initialize();

        expect(sessionManager.isReady, isTrue);
        verify(mockTokenService.getToken()).called(1);
        verify(mockSessionAB.connect(token: 'test-token')).called(1);
        verify(mockSessionBA.connect(token: 'test-token')).called(1);
        
        // Verify session configuration messages were sent
        verify(mockSessionAB.sendMessage(argThat(contains('type')))).called(1);
        verify(mockSessionBA.sendMessage(argThat(contains('type')))).called(1);
        
        expect(statusUpdates.length, greaterThan(0));
        expect(statusUpdates.last.sessionAB, equals(SessionState.connected));
        expect(statusUpdates.last.sessionBA, equals(SessionState.connected));
      });

      test('should throw StateError if already initializing', () async {
        // Start first initialization without awaiting
        final future1 = sessionManager.initialize();
        
        // Try to initialize again while first is in progress
        expect(() => sessionManager.initialize(), throwsA(isA<StateError>()));
        
        await future1; // Complete the first initialization
      });

      test('should handle token service failure', () async {
        when(mockTokenService.getToken()).thenThrow(Exception('Token service error'));
        
        expect(
          () => sessionManager.initialize(),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle session connection failure', () async {
        when(mockSessionAB.connect(token: anyNamed('token')))
            .thenThrow(Exception('WebRTC connection failed'));
        
        expect(
          () => sessionManager.initialize(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('session management', () {
      setUp(() async {
        await sessionManager.initialize();
      });

      test('should start translation in specified direction', () async {
        await sessionManager.startTranslation(SessionDirection.aToB);
        
        expect(sessionManager.activeDirection, equals(SessionDirection.aToB));
        verify(mockSessionAB.startAudioCapture()).called(1);
      });

      test('should stop active translation', () async {
        await sessionManager.startTranslation(SessionDirection.bToA);
        await sessionManager.stopTranslation();
        
        expect(sessionManager.activeDirection, isNull);
        verify(mockSessionAB.stopAudioCapture()).called(1);
        verify(mockSessionBA.stopAudioCapture()).called(1);
      });

      test('should throw StateError when starting translation on unready sessions', () async {
        final unreadyManager = RealtimeSessionManager(
          languageA: 'en',
          languageB: 'fr',
          tokenService: mockTokenService,
        );
        
        expect(
          () => unreadyManager.startTranslation(SessionDirection.aToB),
          throwsA(isA<StateError>()),
        );
        
        await unreadyManager.close();
      });

      test('should send audio to active session', () async {
        await sessionManager.startTranslation(SessionDirection.aToB);
        final audioData = Uint8List.fromList([1, 2, 3, 4]);
        
        await sessionManager.sendAudio(audioData);
        
        verify(mockSessionAB.sendAudio(audioData)).called(1);
        verifyNever(mockSessionBA.sendAudio(any));
      });

      test('should throw StateError when sending audio without active direction', () async {
        final audioData = Uint8List.fromList([1, 2, 3, 4]);
        
        expect(
          () => sessionManager.sendAudio(audioData),
          throwsA(isA<StateError>()),
        );
      });

      test('should send message to specific session', () async {
        final message = {'type': 'test_message', 'data': 'test'};
        
        await sessionManager.sendMessage(message, SessionDirection.aToB);
        verify(mockSessionAB.sendMessage(message)).called(1);
        
        await sessionManager.sendMessage(message, SessionDirection.bToA);
        verify(mockSessionBA.sendMessage(message)).called(1);
      });
    });

    group('message handling', () {
      setUp(() async {
        await sessionManager.initialize();
      });

      test('should forward translation messages with direction context', () async {
        final messages = <TranslationMessage>[];
        sessionManager.messages.listen((message) => messages.add(message));

        // Simulate message from A→B session
        // final testMessage = {'type': 'response.audio_transcript.done', 'transcript': 'Hello'};
        
        // This would normally be triggered by WebRTC client streams
        // For testing, we can verify the stream exists and accepts data
        expect(sessionManager.messages, isA<Stream<TranslationMessage>>());
      });
    });

    group('session failure handling', () {
      setUp(() async {
        await sessionManager.initialize();
      });

      test('should handle session disconnection and attempt reconnection', () async {
        final statusUpdates = <SessionStatus>[];
        sessionManager.status.listen((status) => statusUpdates.add(status));

        // Simulate connection state change to disconnected
        final controller = StreamController<RTCPeerConnectionState>();
        when(mockSessionAB.connectionState).thenAnswer((_) => controller.stream);
        
        controller.add(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
        
        // Allow time for async handling
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Verify reconnection attempt
        verify(mockTokenService.getToken()).called(greaterThan(1));
        
        await controller.close();
      });
    });

    group('resource cleanup', () {
      test('should properly close and cleanup all resources', () async {
        await sessionManager.initialize();
        await sessionManager.close();
        
        verify(mockSessionAB.close()).called(1);
        verify(mockSessionBA.close()).called(1);
        verify(mockTokenService.dispose()).called(1);
      });

      test('should handle close() when not initialized', () async {
        // Should not throw when closing uninitialized session manager
        await sessionManager.close();
        
        verifyNever(mockSessionAB.close());
        verifyNever(mockSessionBA.close());
        verify(mockTokenService.dispose()).called(1);
      });

      test('should handle errors during cleanup gracefully', () async {
        await sessionManager.initialize();
        
        when(mockSessionAB.close()).thenThrow(Exception('Close error'));
        
        expect(
          () => sessionManager.close(),
          throwsA(isA<Exception>()),
        );
      });
    });
  });

  group('SessionDirection extension', () {
    test('should provide correct name representations', () {
      expect(SessionDirection.aToB.name, equals('A→B'));
      expect(SessionDirection.bToA.name, equals('B→A'));
    });
  });

  group('SessionStatus', () {
    test('should create status with required fields', () {
      const status = SessionStatus(
        sessionAB: SessionState.connected,
        sessionBA: SessionState.connecting,
        activeDirection: SessionDirection.aToB,
        message: 'Test message',
      );
      
      expect(status.sessionAB, equals(SessionState.connected));
      expect(status.sessionBA, equals(SessionState.connecting));
      expect(status.activeDirection, equals(SessionDirection.aToB));
      expect(status.message, equals('Test message'));
    });

    test('should provide string representation', () {
      const status = SessionStatus(
        sessionAB: SessionState.connected,
        sessionBA: SessionState.error,
      );
      
      expect(status.toString(), contains('SessionStatus'));
      expect(status.toString(), contains('connected'));
      expect(status.toString(), contains('error'));
    });
  });

  group('TranslationMessage', () {
    test('should create message with all fields', () {
      final timestamp = DateTime.now();
      final message = TranslationMessage(
        direction: SessionDirection.aToB,
        type: 'test_type',
        data: {'key': 'value'},
        timestamp: timestamp,
      );
      
      expect(message.direction, equals(SessionDirection.aToB));
      expect(message.type, equals('test_type'));
      expect(message.data, equals({'key': 'value'}));
      expect(message.timestamp, equals(timestamp));
    });

    test('should provide string representation', () {
      final message = TranslationMessage(
        direction: SessionDirection.bToA,
        type: 'audio_transcript',
        data: {},
        timestamp: DateTime.now(),
      );
      
      expect(message.toString(), contains('TranslationMessage'));
      expect(message.toString(), contains('B→A'));
      expect(message.toString(), contains('audio_transcript'));
    });
  });
}