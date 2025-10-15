import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

/// Service for caching data to improve performance
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  late SharedPreferences _prefs;
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  /// Initialize the cache service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    Log.info('Cache service initialized');
  }

  /// Get cached data with automatic expiration
  T? get<T>(String key) {
    // Check memory cache first
    if (_memoryCache.containsKey(key)) {
      final timestamp = _cacheTimestamps[key];
      if (timestamp != null && 
          DateTime.now().difference(timestamp) < AppConstants.cacheExpiration) {
        return _memoryCache[key] as T?;
      } else {
        // Expired, remove from memory cache
        _memoryCache.remove(key);
        _cacheTimestamps.remove(key);
      }
    }

    // Check persistent cache
    final cachedData = _prefs.getString(key);
    if (cachedData != null) {
      try {
        final data = jsonDecode(cachedData);
        final timestamp = _prefs.getInt('${key}_timestamp');
        
        if (timestamp != null) {
          final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          if (DateTime.now().difference(cacheTime) < AppConstants.cacheExpiration) {
            // Cache is valid, store in memory cache
            _memoryCache[key] = data;
            _cacheTimestamps[key] = cacheTime;
            return data as T?;
          }
        }
        
        // Expired, remove from persistent cache
        _prefs.remove(key);
        _prefs.remove('${key}_timestamp');
      } catch (e) {
        Log.error('Error parsing cached data for key: $key', e);
        _prefs.remove(key);
        _prefs.remove('${key}_timestamp');
      }
    }

    return null;
  }

  /// Set cached data with timestamp
  Future<void> set<T>(String key, T value) async {
    try {
      // Store in memory cache
      _memoryCache[key] = value;
      _cacheTimestamps[key] = DateTime.now();

      // Store in persistent cache
      final jsonData = jsonEncode(value);
      await _prefs.setString(key, jsonData);
      await _prefs.setInt('${key}_timestamp', DateTime.now().millisecondsSinceEpoch);

      Log.debug('Cached data for key: $key');
    } catch (e) {
      Log.error('Error caching data for key: $key', e);
    }
  }

  /// Remove cached data
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    _cacheTimestamps.remove(key);
    await _prefs.remove(key);
    await _prefs.remove('${key}_timestamp');
    Log.debug('Removed cache for key: $key');
  }

  /// Clear all cached data
  Future<void> clear() async {
    _memoryCache.clear();
    _cacheTimestamps.clear();
    
    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.endsWith('_timestamp')) {
        await _prefs.remove(key);
      }
    }
    
    Log.info('All cache cleared');
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    return {
      'memory_cache_size': _memoryCache.length,
      'persistent_cache_keys': _prefs.getKeys().length,
      'total_cached_items': _memoryCache.length + _prefs.getKeys().length,
    };
  }

  /// Check if cache is valid for a key
  bool isValid(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;
    
    return DateTime.now().difference(timestamp) < AppConstants.cacheExpiration;
  }

  /// Get cache expiration time for a key
  DateTime? getExpirationTime(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return null;
    
    return timestamp.add(AppConstants.cacheExpiration);
  }

  /// Preload frequently accessed data
  Future<void> preloadData(List<String> keys) async {
    for (final key in keys) {
      if (!_memoryCache.containsKey(key)) {
        get(key);
      }
    }
    Log.info('Preloaded ${keys.length} cache items');
  }

  /// Clean up expired cache entries
  Future<void> cleanup() async {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    // Check memory cache
    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) >= AppConstants.cacheExpiration) {
        expiredKeys.add(entry.key);
      }
    }

    // Remove expired entries
    for (final key in expiredKeys) {
      await remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      Log.info('Cleaned up ${expiredKeys.length} expired cache entries');
    }
  }
}
