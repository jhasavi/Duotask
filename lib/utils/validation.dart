import '../utils/constants.dart';

/// Utility class for input validation and security
class Validation {
  /// Validate email format
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
    );
    return emailRegex.hasMatch(email);
  }

  /// Validate password strength
  static bool isValidPassword(String password) {
    if (password.length < 8) return false;
    
    // Check for at least one uppercase letter
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    
    // Check for at least one lowercase letter
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    
    // Check for at least one digit
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    
    return true;
  }

  /// Get password strength score (0-4)
  static int getPasswordStrength(String password) {
    int score = 0;
    
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;
    
    return score;
  }

  /// Validate task title
  static bool isValidTaskTitle(String title) {
    if (title.isEmpty) return false;
    if (title.length > AppConstants.maxTaskTitleLength) return false;
    if (title.length < AppConstants.minTaskTitleLength) return false;
    
    // Check for only whitespace
    if (title.trim().isEmpty) return false;
    
    return true;
  }

  /// Validate pair code
  static bool isValidPairCode(String code) {
    if (code.isEmpty) return false;
    if (code.length > AppConstants.maxPairCodeLength) return false;
    
    // Check for alphanumeric characters only
    final codeRegex = RegExp(r'^[a-zA-Z0-9]+$');
    return codeRegex.hasMatch(code);
  }

  /// Sanitize user input to prevent XSS
  static String sanitizeInput(String input) {
    if (input.isEmpty) return input;
    
    return input
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('&', '&amp;');
  }

  /// Validate URL format
  static bool isValidUrl(String url) {
    if (url.isEmpty) return false;
    
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }

  /// Validate phone number format
  static bool isValidPhoneNumber(String phone) {
    if (phone.isEmpty) return false;
    
    // Remove all non-digit characters
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check for valid length (7-15 digits)
    if (digits.length < 7 || digits.length > 15) return false;
    
    return true;
  }

  /// Validate date format
  static bool isValidDate(String date) {
    if (date.isEmpty) return false;
    
    try {
      DateTime.parse(date);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate that date is in the future
  static bool isFutureDate(DateTime date) {
    return date.isAfter(DateTime.now());
  }

  /// Validate that date is not too far in the future (e.g., 10 years)
  static bool isReasonableFutureDate(DateTime date) {
    final maxFuture = DateTime.now().add(const Duration(days: 3650)); // 10 years
    return date.isAfter(DateTime.now()) && date.isBefore(maxFuture);
  }

  /// Input length validation
  static bool isValidLength(String input, int minLength, int maxLength) {
    if (input.isEmpty && minLength > 0) return false;
    if (input.length < minLength) return false;
    if (input.length > maxLength) return false;
    return true;
  }

  /// Validate numeric input
  static bool isValidNumber(String input) {
    if (input.isEmpty) return false;
    
    try {
      double.parse(input);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate integer input
  static bool isValidInteger(String input) {
    if (input.isEmpty) return false;
    
    try {
      int.parse(input);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate that number is within range
  static bool isInRange(num value, num min, num max) {
    return value >= min && value <= max;
  }

  /// Validate file size (in bytes)
  static bool isValidFileSize(int sizeInBytes, int maxSizeInMB) {
    final maxSizeInBytes = maxSizeInMB * 1024 * 1024;
    return sizeInBytes <= maxSizeInBytes;
  }

  /// Validate file extension
  static bool isValidFileExtension(String fileName, List<String> allowedExtensions) {
    if (fileName.isEmpty) return false;
    
    final extension = fileName.split('.').last.toLowerCase();
    return allowedExtensions.contains(extension);
  }
}

/// Rate limiting helper
class RateLimiter {
  final Map<String, List<DateTime>> _requests = {};
  final int _maxRequests;
  final Duration _window;

  RateLimiter({
    int maxRequests = 10,
    Duration window = const Duration(minutes: 1),
  }) : _maxRequests = maxRequests, _window = window;

  /// Check if request is allowed
  bool isAllowed(String key) {
    final now = DateTime.now();
    final requests = _requests[key] ?? [];
    
    // Remove old requests outside the window
    requests.removeWhere((time) => now.difference(time) > _window);
    
    if (requests.length >= _maxRequests) {
      return false;
    }
    
    requests.add(now);
    _requests[key] = requests;
    return true;
  }

  /// Get remaining requests for a key
  int getRemainingRequests(String key) {
    final now = DateTime.now();
    final requests = _requests[key] ?? [];
    
    // Remove old requests outside the window
    requests.removeWhere((time) => now.difference(time) > _window);
    
    return _maxRequests - requests.length;
  }

  /// Clear all rate limiting data
  void clear() {
    _requests.clear();
  }
}
