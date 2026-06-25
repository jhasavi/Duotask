import '../models/task.dart';

/// Sort tasks for display: urgent first, then by due date, then by creation date.
List<Task> sortTasksForDisplay(List<Task> tasks) {
  final sorted = List<Task>.from(tasks);
  sorted.sort((a, b) {
    if (a.priority != b.priority) {
      return a.priority == TaskPriority.urgent ? -1 : 1;
    }

    if (a.dueDate != null && b.dueDate != null) {
      return a.dueDate!.compareTo(b.dueDate!);
    }
    if (a.dueDate != null) return -1;
    if (b.dueDate != null) return 1;

    return b.createdAt.compareTo(a.createdAt);
  });
  return sorted;
}

bool taskMatchesSearch(Task task, String query) {
  if (query.isEmpty) return true;
  return task.title.toLowerCase().contains(query.toLowerCase());
}

bool taskMatchesTodayFilter(Task task, bool showTodayOnly) {
  if (!showTodayOnly) return true;
  return task.isDueToday || task.status != TaskStatus.completed;
}
