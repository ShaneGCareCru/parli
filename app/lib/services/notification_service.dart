import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'token_service.dart';

/// Service for displaying user notifications, especially for error states
/// Provides consistent banner notifications for token service errors
class NotificationService {
  static final _logger = Logger('NotificationService');
  
  /// Show a token service error banner with appropriate action
  static void showTokenError(
    BuildContext context, 
    TokenServiceException error, {
    VoidCallback? onRetry,
  }) {
    _logger.info('Showing token error banner: ${error.type}');
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Clear any existing banners
    scaffoldMessenger.clearSnackBars();
    
    // Configure banner based on error type
    final bannerConfig = _getBannerConfig(error);
    
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            bannerConfig.icon,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  bannerConfig.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  error.message,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: bannerConfig.backgroundColor,
      behavior: SnackBarBehavior.floating,
      duration: bannerConfig.duration,
      action: _buildSnackBarAction(context, error, onRetry),
    );
    
    scaffoldMessenger.showSnackBar(snackBar);
  }
  
  /// Build action button for snack bar based on error type
  static SnackBarAction? _buildSnackBarAction(
    BuildContext context,
    TokenServiceException error,
    VoidCallback? onRetry,
  ) {
    switch (error.type) {
      case TokenErrorType.rateLimited:
        return SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        );
        
      case TokenErrorType.networkError:
      case TokenErrorType.serverError:
        if (onRetry != null) {
          return SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              onRetry();
            },
          );
        }
        break;
        
      case TokenErrorType.unauthorized:
        return SnackBarAction(
          label: 'Settings',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            // TODO: Navigate to settings when implemented
            _logger.info('Settings navigation not yet implemented');
          },
        );
        
      case TokenErrorType.parseError:
      case TokenErrorType.unknown:
        break;
    }
    
    return null;
  }
  
  /// Get banner configuration for error type
  static _BannerConfig _getBannerConfig(TokenServiceException error) {
    switch (error.type) {
      case TokenErrorType.unauthorized:
        return const _BannerConfig(
          title: 'Authentication Failed',
          icon: Icons.lock_outlined,
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 8),
        );
        
      case TokenErrorType.rateLimited:
        return _BannerConfig(
          title: 'Rate Limited',
          icon: Icons.timer_outlined,
          backgroundColor: Colors.orange,
          duration: error.retryAfter ?? const Duration(seconds: 6),
        );
        
      case TokenErrorType.networkError:
        return const _BannerConfig(
          title: 'Network Error',
          icon: Icons.wifi_off_outlined,
          backgroundColor: Colors.red,
          duration: Duration(seconds: 6),
        );
        
      case TokenErrorType.serverError:
        return const _BannerConfig(
          title: 'Service Unavailable',
          icon: Icons.error_outline,
          backgroundColor: Colors.red,
          duration: Duration(seconds: 6),
        );
        
      case TokenErrorType.parseError:
        return const _BannerConfig(
          title: 'Invalid Response',
          icon: Icons.warning_outlined,
          backgroundColor: Colors.deepOrange,
          duration: Duration(seconds: 5),
        );
        
      case TokenErrorType.unknown:
        return const _BannerConfig(
          title: 'Unexpected Error',
          icon: Icons.help_outline,
          backgroundColor: Colors.grey,
          duration: Duration(seconds: 5),
        );
    }
  }
  
  /// Show a success message
  static void showSuccess(BuildContext context, String message) {
    _logger.fine('Showing success message: $message');
    
    final snackBar = SnackBar(
      content: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
  
  /// Show a general info message
  static void showInfo(BuildContext context, String message) {
    _logger.fine('Showing info message: $message');
    
    final snackBar = SnackBar(
      content: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.blue,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}

/// Configuration for banner appearance
class _BannerConfig {
  final String title;
  final IconData icon;
  final Color backgroundColor;
  final Duration duration;
  
  const _BannerConfig({
    required this.title,
    required this.icon,
    required this.backgroundColor,
    required this.duration,
  });
}