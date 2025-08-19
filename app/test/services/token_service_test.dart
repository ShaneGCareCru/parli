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
        // Arrange: Token that expires soon
        final now = DateTime.now().toUtc();
        final nearExpiry = now.add(const Duration(seconds: 10)); // Less than 30s margin
        final futureExpiry = now.add(const Duration(minutes: 5));

        final expiredResponse = jsonEncode({
          'token': 'old-token',
          'expires_at': nearExpiry.toIso8601String(),
          'token_type': 'Bearer',
        });

        final freshResponse = jsonEncode({
          'token': 'new-token',
          'expires_at': futureExpiry.toIso8601String(),
          'token_type': 'Bearer',
        });

        // First call returns expired token
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => http.Response(expiredResponse, 200));

        // Act: Get token first time
        final token1 = await tokenService.getToken();
        
        // Setup for second call - new token
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => http.Response(freshResponse, 200));
        
        // Act: Get token again - should refresh since it's near expiry
        final token2 = await tokenService.getToken();

        // Assert: Should get new token
        expect(token1, equals('old-token'));
        expect(token2, equals('new-token'));
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
        // Arrange
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async {
          await Future.delayed(const Duration(seconds: 15)); // Longer than 10s timeout
          return http.Response('', 200);
        });

        // Act & Assert
        expect(
          () => tokenService.refreshToken(),
          throwsA(isA<TokenServiceException>()
              .having((e) => e.type, 'type', TokenErrorType.networkError)),
        );
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