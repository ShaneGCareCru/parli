import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

/// Service for fetching and managing ephemeral tokens from the backend
/// Handles token refresh logic and provides error handling for 401/429 responses
class TokenService {
  static final _logger = Logger('TokenService');
  
  // Token service endpoint - configurable via environment
  static const String _defaultBaseUrl = 'http://localhost:8000';
  final String _baseUrl;
  
  // Cached token data
  String? _currentToken;
  DateTime? _tokenExpiry;
  String? _tokenType;
  
  /// HTTP client with configurable timeout
  final http.Client _httpClient;
  
  /// Token refresh margin - refresh when this close to expiry
  static const Duration _refreshMargin = Duration(seconds: 30);
  
  TokenService({
    String? baseUrl,
    http.Client? httpClient,
  }) : _baseUrl = baseUrl ?? _defaultBaseUrl,
       _httpClient = httpClient ?? http.Client();
  
  /// Get current token, refreshing if needed
  /// 
  /// Returns a valid token or throws an exception if token cannot be obtained
  /// Automatically refreshes when token is close to expiry
  Future<String> getToken() async {
    // Check if current token is still valid with margin
    if (_isTokenValid()) {
      _logger.fine('Using cached token (expires: $_tokenExpiry)');
      return _currentToken!;
    }
    
    _logger.info('Token expired or missing, fetching new token');
    await refreshToken();
    return _currentToken!;
  }
  
  /// Force refresh of the current token
  /// 
  /// Fetches a new ephemeral token from the backend service
  /// Throws [TokenServiceException] for various error conditions
  Future<void> refreshToken() async {
    _logger.info('Refreshing token from $_baseUrl/realtime/ephemeral');
    
    try {
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/realtime/ephemeral'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({}), // Empty request body for now
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Token request timed out', const Duration(seconds: 10));
        },
      );
      
      _logger.fine('Token request response: ${response.statusCode}');
      
      // Handle specific HTTP status codes per PAR-16 requirements
      switch (response.statusCode) {
        case 200:
          try {
            await _parseTokenResponse(response.body);
            _logger.info('Token refreshed successfully (expires: $_tokenExpiry)');
          } catch (e) {
            _logger.severe('Failed to parse token response: $e');
            throw TokenServiceException(
              'Invalid response format from token service',
              TokenErrorType.parseError,
              response.statusCode,
            );
          }
          break;
          
        case 401:
          _logger.warning('Authentication failed (401)');
          throw TokenServiceException(
            'Authentication failed - check app credentials',
            TokenErrorType.unauthorized,
            response.statusCode,
          );
          
        case 429:
          _logger.warning('Rate limited (429)');
          // Extract retry-after header if available
          final retryAfter = _parseRetryAfter(response.headers['retry-after']);
          throw TokenServiceException(
            'Rate limited - too many requests',
            TokenErrorType.rateLimited,
            response.statusCode,
            retryAfter: retryAfter,
          );
          
        case 500:
        case 502:
        case 503:
        case 504:
          _logger.warning('Server error (${response.statusCode})');
          throw TokenServiceException(
            'Server error - service temporarily unavailable',
            TokenErrorType.serverError,
            response.statusCode,
          );
          
        default:
          _logger.warning('Unexpected response (${response.statusCode}): ${response.body}');
          throw TokenServiceException(
            'Unexpected error from token service',
            TokenErrorType.networkError,
            response.statusCode,
          );
      }
      
    } on TokenServiceException {
      // Re-throw TokenServiceException from switch cases
      rethrow;
    } on TimeoutException catch (e) {
      _logger.warning('Token request timeout: $e');
      throw TokenServiceException(
        'Request timed out - check network connection',
        TokenErrorType.networkError,
        null,
      );
    } on http.ClientException catch (e) {
      _logger.warning('HTTP client error: $e');
      throw TokenServiceException(
        'Network error - unable to reach token service',
        TokenErrorType.networkError,
        null,
      );
    } catch (e) {
      _logger.severe('Unexpected error during token refresh: $e');
      throw TokenServiceException(
        'Unexpected error during token refresh',
        TokenErrorType.unknown,
        null,
      );
    }
  }
  
  /// Parse token response from backend
  Future<void> _parseTokenResponse(String responseBody) async {
    try {
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      
      // Validate required fields
      if (!data.containsKey('token') || !data.containsKey('expires_at')) {
        throw FormatException('Invalid token response: missing required fields');
      }
      
      _currentToken = data['token'] as String;
      _tokenType = data['token_type'] as String? ?? 'Bearer';
      
      // Parse ISO 8601 expiry timestamp
      final expiryString = data['expires_at'] as String;
      _tokenExpiry = DateTime.parse(expiryString).toUtc();
      
      _logger.fine('Parsed token expiry: $_tokenExpiry');
      
    } catch (e) {
      _logger.severe('Failed to parse token response: $e');
      rethrow; // Re-throw to be caught by calling method
    }
  }
  
  /// Parse retry-after header value
  Duration? _parseRetryAfter(String? retryAfterHeader) {
    if (retryAfterHeader == null) return null;
    
    try {
      final seconds = int.parse(retryAfterHeader);
      return Duration(seconds: seconds);
    } catch (e) {
      _logger.warning('Failed to parse retry-after header: $retryAfterHeader');
      return null;
    }
  }
  
  /// Check if current token is valid with refresh margin
  bool _isTokenValid() {
    if (_currentToken == null || _tokenExpiry == null) {
      return false;
    }
    
    final now = DateTime.now().toUtc();
    final expiryWithMargin = _tokenExpiry!.subtract(_refreshMargin);
    
    return now.isBefore(expiryWithMargin);
  }
  
  /// Get authorization header value for HTTP requests
  String? getAuthorizationHeader() {
    if (_currentToken == null || _tokenType == null) {
      return null;
    }
    return '$_tokenType $_currentToken';
  }
  
  /// Get token expiry time
  DateTime? get tokenExpiry => _tokenExpiry;
  
  /// Check if service has a valid token
  bool get hasValidToken => _isTokenValid();
  
  /// Clear cached token data
  void clearToken() {
    _logger.info('Clearing cached token');
    _currentToken = null;
    _tokenExpiry = null;
    _tokenType = null;
  }
  
  /// Dispose of HTTP client
  void dispose() {
    _httpClient.close();
  }
}

/// Token service specific exceptions
class TokenServiceException implements Exception {
  final String message;
  final TokenErrorType type;
  final int? statusCode;
  final Duration? retryAfter;
  
  const TokenServiceException(
    this.message,
    this.type,
    this.statusCode, {
    this.retryAfter,
  });
  
  @override
  String toString() => 'TokenServiceException($type): $message';
  
  /// Whether this error is retryable
  bool get isRetryable {
    switch (type) {
      case TokenErrorType.rateLimited:
      case TokenErrorType.serverError:
      case TokenErrorType.networkError:
        return true;
      case TokenErrorType.unauthorized:
      case TokenErrorType.parseError:
      case TokenErrorType.unknown:
        return false;
    }
  }
}

/// Types of token service errors
enum TokenErrorType {
  unauthorized,    // 401 - authentication failed
  rateLimited,     // 429 - too many requests
  serverError,     // 5xx - backend server error
  networkError,    // Network/connectivity issues
  parseError,      // Response parsing failed
  unknown,         // Unexpected error
}