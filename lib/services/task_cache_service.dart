import 'package:hive/hive.dart';
import '../models/task.dart';
import '../utils/logger.dart';

class TaskCacheService {
  static const String _boxName = 'task_cache';
  static const Duration _cacheDuration = Duration(hours: 1);
  
  late final Box<Map> _box;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox<Map>(_boxName);
      } else {
        _box = Hive.box<Map>(_boxName);
      }
      _isInitialized = true;
      
      // Clean up old cache entries
      await _cleanupOldEntries();
    } catch (e) {
      Log.error('Failed to initialize TaskCacheService: $e');
      rethrow;
    }
  }

  Future<void> cacheTasks(String userId, List<DuoTask> tasks) async {
    if (!_isInitialized) await init();
    
    try {
      final cacheData = {
        'timestamp': DateTime.now().toIso8601String(),
        'tasks': tasks.map((t) => t.toJson()).toList(),
      };
      
      await _box.put(_cacheKey(userId), cacheData);
    } catch (e) {
      Log.error('Failed to cache tasks: $e');
    }
  }

  Future<List<DuoTask>?> getCachedTasks(String userId) async {
    if (!_isInitialized) await init();
    
    try {
      final cacheData = _box.get(_cacheKey(userId));
      if (cacheData == null) return null;
      
      final timestamp = DateTime.parse(cacheData['timestamp']);
      if (DateTime.now().difference(timestamp) > _cacheDuration) {
        await _box.delete(_cacheKey(userId));
        return null;
      }
      
      final tasks = (cacheData['tasks'] as List)
          .map((t) => DuoTask.fromJson(Map<String, dynamic>.from(t)))
          .toList();
          
      return tasks;
    } catch (e) {
      Log.error('Failed to get cached tasks: $e');
      return null;
    }
  }

  Future<void> clearCache(String userId) async {
    if (!_isInitialized) await init();
    await _box.delete(_cacheKey(userId));
  }

  Future<void> _cleanupOldEntries() async {
    final now = DateTime.now();
    final keysToDelete = <String>[];
    
    for (final key in _box.keys) {
      try {
        final cacheData = _box.get(key);
        if (cacheData != null) {
          final timestamp = DateTime.parse(cacheData['timestamp']);
          if (now.difference(timestamp) > _cacheDuration) {
            keysToDelete.add(key as String);
          }
        }
      } catch (e) {
        Log.error('Error cleaning up cache: $e');
      }
    }
    
    await _box.deleteAll(keysToDelete);
  }

  String _cacheKey(String userId) => 'tasks_$userId';
  
  Future<void> close() async {
    if (_isInitialized) {
      await _box.close();
      _isInitialized = false;
    }
  }
}
