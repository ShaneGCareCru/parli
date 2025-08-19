import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:parli/services/token_service.dart';

import 'token_service_test.mocks.dart';

// Generate mocks for http.Client
@GenerateMocks([http.Client])
void main() {
  group('TokenService', () {
    late MockClient mockHttpClient;
    late TokenService tokenService;

    setUp(() {
      mockHttpClient = MockClient();
      tokenService = TokenService(
        baseUrl: 'http://localhost:8000',
        httpClient: mockHttpClient,
      );
    });

    tearDown(() {
      tokenService.dispose();
    });

    group('getToken', () {
      test('returns cached token when valid', () async {
        // Arrange: First request to get a token
        final now = DateTime.now().toUtc();
        final expiry = now.add(const Duration(minutes: 5));
        final responseBody = jsonEncode({
          'token': 'test-token-123',
          'expires_at': expiry.toIso8601String(),
          'token_type': 'Bearer',
        });

        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(responseBody, 200));

        // Act: Get token twice
        final token1 = await tokenService.getToken();
        final token2 = await tokenService.getToken();

        // Assert: Should return same token and only call API once
        expect(token1, equals('test-token-123'));
        expect(token2, equals('test-token-123'));
        verify(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body'))).called(1);
      });

      test('refreshes token when close to expiry', () async {
        // Arrange: Use fixed test time to avoid race conditions
        // Token expires in 20 seconds (less than 30s refresh margin)
        final testBaseTime = DateTime.parse('2025-01-01T12:00:00.000Z');
        final nearExpiry = testBaseTime.add(const Duration(seconds: 20)); // Less than 30s margin
        final futureExpiry = testBaseTime.add(const Duration(minutes: 5)); // Well beyond margin

        final nearExpiryResponse = jsonEncode({
          'token': 'near-expiry-token',
          'expires_at': nearExpiry.toIso8601String(),
          'token_type': 'Bearer',
        });

        final freshResponse = jsonEncode({
          'token': 'fresh-token',
          'expires_at': futureExpiry.toIso8601String(),
          'token_type': 'Bearer',
        });

        // First call returns token that's close to expiry
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => http.Response(nearExpiryResponse, 200));

        // Act: Get token first time (will refresh due to being close to expiry)
        final token1 = await tokenService.getToken();
        
        // Setup for second call - return fresh token
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => http.Response(freshResponse, 200));
        
        // Act: Get token again - should refresh again since previous token is still close to expiry
        final token2 = await tokenService.getToken();

        // Assert: Both calls should return fresh tokens due to refresh logic
        expect(token1, equals('near-expiry-token'));
        expect(token2, equals('fresh-token'));
        
        // Verify HTTP client was called twice (once for each getToken call)
        verify(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body'))).called(2);
      });
    });

    group('refreshToken', () {
      test('handles successful token refresh', () async {
        // Arrange
        final now = DateTime.now().toUtc();
        final expiry = now.add(const Duration(minutes: 5));
        final responseBody = jsonEncode({
          'token': 'success-token',
          'expires_at': expiry.toIso8601String(),
          'token_type': 'Bearer',
        });

        when(mockHttpClient.post(
          Uri.parse('http://localhost:8000/realtime/ephemeral'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(responseBody, 200));

        // Act
        await tokenService.refreshToken();

        // Assert
        expect(tokenService.hasValidToken, isTrue);
        expect(tokenService.getAuthorizationHeader(), equals('Bearer success-token'));
      });

      test('throws TokenServiceException for 401 Unauthorized', () async {
        // Arrange
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => http.Response('Unauthorized', 401));

        // Act & Assert
        expect(
          () => tokenService.refreshToken(),
          throwsA(isA<TokenServiceException>()
              .having((e) => e.type, 'type', TokenErrorType.unauthorized)
              .having((e) => e.statusCode, 'statusCode', 401)),
        );
      });

      test('throws TokenServiceException for 429 Rate Limited', () async {
        // Arrange
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => http.Response('Rate Limited', 429, headers: {'retry-after': '60'}));

        // Act & Assert
        expect(
          () => tokenService.refreshToken(),
          throwsA(isA<TokenServiceException>()
              .having((e) => e.type, 'type', TokenErrorType.rateLimited)
              .having((e) => e.statusCode, 'statusCode', 429)
              .having((e) => e.retryAfter, 'retryAfter', const Duration(seconds: 60))),
        );
      });

      test('throws TokenServiceException for server errors', () async {
        // Arrange
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => http.Response('Internal Server Error', 500));

        // Act & Assert
        expect(
          () => tokenService.refreshToken(),
          throwsA(isA<TokenServiceException>()
              .having((e) => e.type, 'type', TokenErrorType.serverError)
              .having((e) => e.statusCode, 'statusCode', 500)),
        );
      });

      test('throws TokenServiceException for timeout', () async {
        // Arrange: Use a completer to simulate timeout without real delays
        final completer = Completer<http.Response>();
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) => completer.future);

        // Act & Assert: The TokenService has a 10s timeout, so this should throw
        await expectLater(
          tokenService.refreshToken(),
          throwsA(isA<TokenServiceException>()
              .having((e) => e.type, 'type', TokenErrorType.networkError)
              .having((e) => e.message, 'message', contains('timed out'))),
        );
        
        // Clean up: Complete the future to avoid hanging
        if (!completer.isCompleted) {
          completer.complete(http.Response('', 200));
        }
      });

      test('throws TokenServiceException for invalid response format', () async {
        // Arrange: Response missing required fields
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => http.Response('{"invalid": "response"}', 200));

        // Act & Assert
        expect(
          () => tokenService.refreshToken(),
          throwsA(isA<TokenServiceException>()
              .having((e) => e.type, 'type', TokenErrorType.parseError)),
        );
      });
    });

    group('clearToken', () {
      test('clears cached token data', () async {
        // Arrange: Get a token first
        final responseBody = jsonEncode({
          'token': 'test-token',
          'expires_at': DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
          'token_type': 'Bearer',
        });

        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => http.Response(responseBody, 200));

        await tokenService.getToken();
        expect(tokenService.hasValidToken, isTrue);

        // Act
        tokenService.clearToken();

        // Assert
        expect(tokenService.hasValidToken, isFalse);
        expect(tokenService.getAuthorizationHeader(), isNull);
        expect(tokenService.tokenExpiry, isNull);
      });
    });

    group('error properties', () {
      test('TokenServiceException.isRetryable returns correct values', () {
        expect(
          TokenServiceException('', TokenErrorType.rateLimited, 429).isRetryable,
          isTrue,
        );
        expect(
          TokenServiceException('', TokenErrorType.serverError, 500).isRetryable,
          isTrue,
        );
        expect(
          TokenServiceException('', TokenErrorType.networkError, null).isRetryable,
          isTrue,
        );
        expect(
          TokenServiceException('', TokenErrorType.unauthorized, 401).isRetryable,
          isFalse,
        );
        expect(
          TokenServiceException('', TokenErrorType.parseError, null).isRetryable,
          isFalse,
        );
        expect(
          TokenServiceException('', TokenErrorType.unknown, null).isRetryable,
          isFalse,
        );
      });
    });
  });
}