import 'dart:async';
import 'dart:math';
import '../models/task.dart';
import '../utils/logger.dart';

/// Smart suggestions service for intelligent task recommendations
class SmartSuggestionsService {
  static final SmartSuggestionsService _instance = SmartSuggestionsService._internal();
  factory SmartSuggestionsService() => _instance;
  SmartSuggestionsService._internal();

  // Task patterns and suggestions
  final Map<String, List<String>> _taskTemplates = {
    'household': [
      'Clean the kitchen',
      'Do laundry',
      'Take out trash',
      'Vacuum living room',
      'Wash dishes',
      'Organize closet',
      'Water plants',
      'Make grocery list',
    ],
    'work': [
      'Review emails',
      'Prepare presentation',
      'Schedule meeting',
      'Update project status',
      'Complete documentation',
      'Follow up with client',
      'Organize workspace',
      'Plan next week',
    ],
    'health': [
      'Go for a walk',
      'Exercise',
      'Drink water',
      'Take vitamins',
      'Meditate',
      'Stretch',
      'Check blood pressure',
      'Schedule doctor appointment',
    ],
    'personal': [
      'Read a book',
      'Call family',
      'Plan weekend',
      'Update budget',
      'Learn something new',
      'Practice hobby',
      'Social media break',
      'Self-care time',
    ],
  };

  final Map<String, List<String>> _timeBasedSuggestions = {
    'morning': [
      'Make breakfast',
      'Check calendar',
      'Review daily goals',
      'Exercise',
      'Read news',
      'Plan day',
    ],
    'afternoon': [
      'Take lunch break',
      'Check emails',
      'Team meeting',
      'Work on priority tasks',
      'Take a walk',
      'Hydrate',
    ],
    'evening': [
      'Prepare dinner',
      'Review tomorrow',
      'Relax',
      'Family time',
      'Plan next day',
      'Self-care',
    ],
    'weekend': [
      'Grocery shopping',
      'House cleaning',
      'Laundry',
      'Meal prep',
      'Outdoor activity',
      'Social plans',
    ],
  };

  // User behavior tracking
  final Map<String, int> _taskFrequency = {};
  final Map<String, List<DateTime>> _taskTiming = {};
  final Map<String, List<String>> _taskCategories = {};

  /// Get smart suggestions based on context
  Future<List<TaskSuggestion>> getSuggestions({
    required String userId,
    String? context,
    DateTime? timeOfDay,
    List<DuoTask>? recentTasks,
    int limit = 5,
  }) async {
    final suggestions = <TaskSuggestion>[];

    // Time-based suggestions
    if (timeOfDay != null) {
      final timeContext = _getTimeContext(timeOfDay);
      final timeSuggestions = _timeBasedSuggestions[timeContext] ?? [];
      
      for (final suggestion in timeSuggestions.take(limit ~/ 2)) {
        suggestions.add(TaskSuggestion(
          title: suggestion,
          category: 'time-based',
          confidence: 0.8,
          reason: 'Based on time of day',
        ));
      }
    }

    // Pattern-based suggestions
    if (recentTasks != null && recentTasks.isNotEmpty) {
      final patternSuggestions = _getPatternBasedSuggestions(recentTasks, limit ~/ 2);
      suggestions.addAll(patternSuggestions);
    }

    // Category-based suggestions
    final categorySuggestions = _getCategoryBasedSuggestions(userId, limit ~/ 3);
    suggestions.addAll(categorySuggestions);

    // Remove duplicates and sort by confidence
    final uniqueSuggestions = suggestions.toSet().toList();
    uniqueSuggestions.sort((a, b) => b.confidence.compareTo(a.confidence));

    return uniqueSuggestions.take(limit).toList();
  }

  /// Get quick add suggestions
  Future<List<String>> getQuickAddSuggestions({
    required String userId,
    int limit = 3,
  }) async {
    final suggestions = <String>[];
    
    // Get most frequent tasks
    final frequentTasks = _getMostFrequentTasks(userId);
    suggestions.addAll(frequentTasks.take(limit));

    // Add template suggestions if needed
    if (suggestions.length < limit) {
      final templates = _taskTemplates.values.expand((x) => x).toList();
      final random = Random();
      while (suggestions.length < limit) {
        final template = templates[random.nextInt(templates.length)];
        if (!suggestions.contains(template)) {
          suggestions.add(template);
        }
      }
    }

    return suggestions;
  }

  /// Track task creation for learning
  void trackTaskCreated(String userId, DuoTask task) {
    // Track frequency
    _taskFrequency[task.title] = (_taskFrequency[task.title] ?? 0) + 1;

    // Track timing
    if (!_taskTiming.containsKey(task.title)) {
      _taskTiming[task.title] = [];
    }
    _taskTiming[task.title]!.add(DateTime.now());

    // Track categories
    final category = _categorizeTask(task.title);
    if (!_taskCategories.containsKey(userId)) {
      _taskCategories[userId] = [];
    }
    if (!_taskCategories[userId]!.contains(category)) {
      _taskCategories[userId]!.add(category);
    }

    Log.info('Tracked task creation: ${task.title} for user $userId');
  }

  /// Get task insights
  Future<TaskInsights> getTaskInsights(String userId) async {
    final insights = TaskInsights(
      mostFrequentTasks: _getMostFrequentTasks(userId),
      preferredCategories: _getPreferredCategories(userId),
      peakProductivityTime: _getPeakProductivityTime(userId),
      averageTasksPerDay: _getAverageTasksPerDay(userId),
      completionRate: _getCompletionRate(userId),
    );

    return insights;
  }

  /// Get smart task templates
  List<String> getTaskTemplates(String category) {
    return _taskTemplates[category] ?? [];
  }

  /// Get all available categories
  List<String> getAvailableCategories() {
    return _taskTemplates.keys.toList();
  }

  // Private helper methods

  String _getTimeContext(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 22) return 'evening';
    return 'night';
  }

  List<TaskSuggestion> _getPatternBasedSuggestions(List<DuoTask> recentTasks, int limit) {
    final suggestions = <TaskSuggestion>[];
    final patterns = <String, int>{};

    // Analyze patterns in recent tasks
    for (final task in recentTasks) {
      final category = _categorizeTask(task.title);
      patterns[category] = (patterns[category] ?? 0) + 1;
    }

    // Find most common pattern
    if (patterns.isNotEmpty) {
      final mostCommonCategory = patterns.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;

      final templates = _taskTemplates[mostCommonCategory] ?? [];
      for (final template in templates.take(limit)) {
        suggestions.add(TaskSuggestion(
          title: template,
          category: mostCommonCategory,
          confidence: 0.7,
          reason: 'Based on recent task patterns',
        ));
      }
    }

    return suggestions;
  }

  List<TaskSuggestion> _getCategoryBasedSuggestions(String userId, int limit) {
    final suggestions = <TaskSuggestion>[];
    final userCategories = _taskCategories[userId] ?? [];

    for (final category in userCategories) {
      final templates = _taskTemplates[category] ?? [];
      for (final template in templates.take(limit ~/ userCategories.length)) {
        suggestions.add(TaskSuggestion(
          title: template,
          category: category,
          confidence: 0.6,
          reason: 'Based on your preferences',
        ));
      }
    }

    return suggestions;
  }

  List<String> _getMostFrequentTasks(String userId) {
    final sortedTasks = _taskFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedTasks.map((e) => e.key).toList();
  }

  List<String> _getPreferredCategories(String userId) {
    return _taskCategories[userId] ?? [];
  }

  String _getPeakProductivityTime(String userId) {
    // Analyze task timing patterns
    final allTimings = _taskTiming.values.expand((x) => x).toList();
    if (allTimings.isEmpty) return 'morning';

    final hourCounts = <int, int>{};
    for (final time in allTimings) {
      final hour = time.hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }

    if (hourCounts.isEmpty) return 'morning';

    final peakHour = hourCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    if (peakHour >= 5 && peakHour < 12) return 'morning';
    if (peakHour >= 12 && peakHour < 17) return 'afternoon';
    if (peakHour >= 17 && peakHour < 22) return 'evening';
    return 'night';
  }

  double _getAverageTasksPerDay(String userId) {
    // Calculate average tasks per day based on frequency
    final totalTasks = _taskFrequency.values.fold(0, (sum, count) => sum + count);
    if (totalTasks == 0) return 0.0;

    // Assume data spans 30 days for simplicity
    return totalTasks / 30.0;
  }

  double _getCompletionRate(String userId) {
    // This would need to be implemented with actual completion data
    // For now, return a default value
    return 0.75;
  }

  String _categorizeTask(String taskTitle) {
    final title = taskTitle.toLowerCase();
    
    if (title.contains('clean') || title.contains('wash') || title.contains('organize') || 
        title.contains('laundry') || title.contains('grocery') || title.contains('house')) {
      return 'household';
    }
    
    if (title.contains('meeting') || title.contains('email') || title.contains('project') || 
        title.contains('work') || title.contains('client') || title.contains('presentation')) {
      return 'work';
    }
    
    if (title.contains('exercise') || title.contains('walk') || title.contains('health') || 
        title.contains('doctor') || title.contains('meditate') || title.contains('vitamin')) {
      return 'health';
    }
    
    return 'personal';
  }
}

/// Task suggestion model
class TaskSuggestion {
  final String title;
  final String category;
  final double confidence;
  final String reason;

  TaskSuggestion({
    required this.title,
    required this.category,
    required this.confidence,
    required this.reason,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskSuggestion &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          category == other.category;

  @override
  int get hashCode => title.hashCode ^ category.hashCode;

  @override
  String toString() {
    return 'TaskSuggestion{title: $title, category: $category, confidence: $confidence, reason: $reason}';
  }
}

/// Task insights model
class TaskInsights {
  final List<String> mostFrequentTasks;
  final List<String> preferredCategories;
  final String peakProductivityTime;
  final double averageTasksPerDay;
  final double completionRate;

  TaskInsights({
    required this.mostFrequentTasks,
    required this.preferredCategories,
    required this.peakProductivityTime,
    required this.averageTasksPerDay,
    required this.completionRate,
  });

  @override
  String toString() {
    return 'TaskInsights{mostFrequentTasks: $mostFrequentTasks, preferredCategories: $preferredCategories, peakProductivityTime: $peakProductivityTime, averageTasksPerDay: $averageTasksPerDay, completionRate: $completionRate}';
  }
}
