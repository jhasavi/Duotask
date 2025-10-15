import 'package:flutter/material.dart';
import '../utils/logger.dart';

/// Centralized error handling service
class ErrorService {
  static final ErrorService _instance = ErrorService._internal();
  factory ErrorService() => _instance;
  ErrorService._internal();

  /// Handle and log errors with user-friendly messages
  void handleError(
    BuildContext context,
    dynamic error,
    String operation, {
    String? customMessage,
    VoidCallback? onRetry,
  }) {
    // Log the error
    Log.error('Error during $operation: $error');

    // Show user-friendly error message
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(customMessage ?? _getUserFriendlyMessage(error)),
          backgroundColor: Colors.red,
          action: onRetry != null
              ? SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: onRetry,
                )
              : null,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Handle network errors specifically
  void handleNetworkError(
    BuildContext context,
    dynamic error,
    String operation, {
    VoidCallback? onRetry,
  }) {
    handleError(
      context,
      error,
      operation,
      customMessage:
          'Network error. Please check your connection and try again.',
      onRetry: onRetry,
    );
  }

  /// Handle authentication errors
  void handleAuthError(
    BuildContext context,
    dynamic error,
    String operation,
  ) {
    handleError(
      context,
      error,
      operation,
      customMessage: 'Authentication error. Please log in again.',
    );
  }

  /// Handle database errors
  void handleDatabaseError(
    BuildContext context,
    dynamic error,
    String operation, {
    VoidCallback? onRetry,
  }) {
    handleError(
      context,
      error,
      operation,
      customMessage: 'Data error. Please try again.',
      onRetry: onRetry,
    );
  }

  /// Get user-friendly error message from error object
  String _getUserFriendlyMessage(dynamic error) {
    if (error is String) {
      return error;
    }

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network error. Please check your connection.';
    }

    if (errorString.contains('auth') || errorString.contains('login')) {
      return 'Authentication error. Please log in again.';
    }

    if (errorString.contains('permission') || errorString.contains('access')) {
      return 'Access denied. Please check your permissions.';
    }

    if (errorString.contains('not found') || errorString.contains('404')) {
      return 'Resource not found.';
    }

    if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    if (errorString.contains('validation') || errorString.contains('invalid')) {
      return 'Invalid data. Please check your input.';
    }

    return 'An unexpected error occurred. Please try again.';
  }

  /// Show success message
  void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: duration,
        ),
      );
    }
  }

  /// Show info message
  void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.blue,
          duration: duration,
        ),
      );
    }
  }

  /// Show warning message
  void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: duration,
        ),
      );
    }
  }
}
