import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../utils/logger.dart';

/// Service for handling network operations and connectivity
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final http.Client _client = http.Client();
  bool _isConnected = true;

  /// Check if device has internet connectivity
  Future<bool> checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      _isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      Log.debug('Connectivity check: $_isConnected');
      return _isConnected;
    } on SocketException catch (e) {
      _isConnected = false;
      Log.warn('No internet connection: $e');
      return false;
    } catch (e) {
      _isConnected = false;
      Log.error('Connectivity check failed: $e');
      return false;
    }
  }

  /// Get current connectivity status
  bool get isConnected => _isConnected;

  /// Make a GET request
  Future<http.Response> get(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    if (!await checkConnectivity()) {
      throw NetworkException('No internet connection');
    }

    try {
      final response = await _client
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(timeout ?? AppConstants.connectionTimeout);

      Log.debug('GET $url - Status: ${response.statusCode}');
      return response;
    } on SocketException catch (e) {
      Log.error('Network error during GET request: $e');
      throw NetworkException('Network error: $e');
    } on TimeoutException catch (e) {
      Log.error('Timeout during GET request: $e');
      throw NetworkException('Request timeout');
    } catch (e) {
      Log.error('Unexpected error during GET request: $e');
      throw NetworkException('Unexpected error: $e');
    }
  }

  /// Make a POST request
  Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    if (!await checkConnectivity()) {
      throw NetworkException('No internet connection');
    }

    try {
      final response = await _client
          .post(
            Uri.parse(url),
            headers: headers,
            body: body,
          )
          .timeout(timeout ?? AppConstants.connectionTimeout);

      Log.debug('POST $url - Status: ${response.statusCode}');
      return response;
    } on SocketException catch (e) {
      Log.error('Network error during POST request: $e');
      throw NetworkException('Network error: $e');
    } on TimeoutException catch (e) {
      Log.error('Timeout during POST request: $e');
      throw NetworkException('Request timeout');
    } catch (e) {
      Log.error('Unexpected error during POST request: $e');
      throw NetworkException('Unexpected error: $e');
    }
  }

  /// Make a PUT request
  Future<http.Response> put(
    String url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    if (!await checkConnectivity()) {
      throw NetworkException('No internet connection');
    }

    try {
      final response = await _client
          .put(
            Uri.parse(url),
            headers: headers,
            body: body,
          )
          .timeout(timeout ?? AppConstants.connectionTimeout);

      Log.debug('PUT $url - Status: ${response.statusCode}');
      return response;
    } on SocketException catch (e) {
      Log.error('Network error during PUT request: $e');
      throw NetworkException('Network error: $e');
    } on TimeoutException catch (e) {
      Log.error('Timeout during PUT request: $e');
      throw NetworkException('Request timeout');
    } catch (e) {
      Log.error('Unexpected error during PUT request: $e');
      throw NetworkException('Unexpected error: $e');
    }
  }

  /// Make a DELETE request
  Future<http.Response> delete(
    String url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    if (!await checkConnectivity()) {
      throw NetworkException('No internet connection');
    }

    try {
      final response = await _client
          .delete(
            Uri.parse(url),
            headers: headers,
            body: body,
          )
          .timeout(timeout ?? AppConstants.connectionTimeout);

      Log.debug('DELETE $url - Status: ${response.statusCode}');
      return response;
    } on SocketException catch (e) {
      Log.error('Network error during DELETE request: $e');
      throw NetworkException('Network error: $e');
    } on TimeoutException catch (e) {
      Log.error('Timeout during DELETE request: $e');
      throw NetworkException('Request timeout');
    } catch (e) {
      Log.error('Unexpected error during DELETE request: $e');
      throw NetworkException('Unexpected error: $e');
    }
  }

  /// Upload a file
  Future<http.Response> uploadFile(
    String url,
    String filePath, {
    Map<String, String>? headers,
    Map<String, String>? fields,
    Duration? timeout,
  }) async {
    if (!await checkConnectivity()) {
      throw NetworkException('No internet connection');
    }

    try {
      final request = http.MultipartRequest('POST', Uri.parse(url));
      
      // Add headers
      if (headers != null) {
        request.headers.addAll(headers);
      }
      
      // Add fields
      if (fields != null) {
        request.fields.addAll(fields);
      }
      
      // Add file
      final file = await http.MultipartFile.fromPath('file', filePath);
      request.files.add(file);

      final streamedResponse = await request
          .send()
          .timeout(timeout ?? AppConstants.connectionTimeout);
      
      final response = await http.Response.fromStream(streamedResponse);
      
      Log.debug('UPLOAD $url - Status: ${response.statusCode}');
      return response;
    } on SocketException catch (e) {
      Log.error('Network error during file upload: $e');
      throw NetworkException('Network error: $e');
    } on TimeoutException catch (e) {
      Log.error('Timeout during file upload: $e');
      throw NetworkException('Upload timeout');
    } catch (e) {
      Log.error('Unexpected error during file upload: $e');
      throw NetworkException('Unexpected error: $e');
    }
  }

  /// Handle response and throw appropriate exceptions
  void handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return; // Success
    }

    switch (response.statusCode) {
      case 400:
        throw NetworkException('Bad request: ${response.body}');
      case 401:
        throw NetworkException('Unauthorized: Please log in again');
      case 403:
        throw NetworkException('Forbidden: Access denied');
      case 404:
        throw NetworkException('Not found: Resource not available');
      case 429:
        throw NetworkException('Too many requests: Please try again later');
      case 500:
        throw NetworkException('Server error: Please try again later');
      case 502:
        throw NetworkException('Bad gateway: Service temporarily unavailable');
      case 503:
        throw NetworkException('Service unavailable: Please try again later');
      default:
        throw NetworkException('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  /// Close the HTTP client
  void dispose() {
    _client.close();
  }
}

/// Custom exception for network-related errors
class NetworkException implements Exception {
  final String message;
  
  NetworkException(this.message);
  
  @override
  String toString() => 'NetworkException: $message';
}

/// Timeout exception
class TimeoutException implements Exception {
  final String message;
  
  TimeoutException(this.message);
  
  @override
  String toString() => 'TimeoutException: $message';
}
