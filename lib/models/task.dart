/// Task status enum
enum TaskStatus { unclaimed, claimed, done }

/// Repeat type enum
enum RepeatType { none, daily, weekly, monthly, yearly }

/// Task model for DuoTask app
class DuoTask {
  final String id;
  final String title;
  final TaskStatus status;
  final String ownerId;
  final String? claimedBy;
  final String? pairId;
  final RepeatType repeatType;
  final DateTime? dueDate;
  final bool urgent;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DuoTask({
    required this.id,
    required this.title,
    required this.status,
    required this.ownerId,
    this.claimedBy,
    this.pairId,
    this.repeatType = RepeatType.none,
    this.dueDate,
    this.urgent = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a task from JSON (Supabase)
  factory DuoTask.fromJson(Map<String, dynamic> json) {
    return DuoTask(
      id: json['id'] as String,
      title: json['title'] as String,
      status: TaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TaskStatus.unclaimed,
      ),
      ownerId: json['owner_id'] as String,
      claimedBy: json['claimed_by'] as String?,
      pairId: json['pair_id'] as String?,
      repeatType: RepeatType.values.firstWhere(
        (e) => e.name == json['repeat_type'],
        orElse: () => RepeatType.none,
      ),
      dueDate: json['due_date'] != null 
          ? DateTime.parse(json['due_date'] as String)
          : null,
      urgent: json['urgent'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'status': status.name,
      'owner_id': ownerId,
      'claimed_by': claimedBy,
      'pair_id': pairId,
      'repeat_type': repeatType.name,
      'due_date': dueDate?.toIso8601String(),
      'urgent': urgent,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  DuoTask copyWith({
    String? id,
    String? title,
    TaskStatus? status,
    String? ownerId,
    String? claimedBy,
    String? pairId,
    RepeatType? repeatType,
    DateTime? dueDate,
    bool? urgent,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DuoTask(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      ownerId: ownerId ?? this.ownerId,
      claimedBy: claimedBy ?? this.claimedBy,
      pairId: pairId ?? this.pairId,
      repeatType: repeatType ?? this.repeatType,
      dueDate: dueDate ?? this.dueDate,
      urgent: urgent ?? this.urgent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if task is overdue
  bool get isOverdue {
    if (dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  /// Check if task is due today
  bool get isDueToday {
    if (dueDate == null) return false;
    final today = DateTime.now();
    final due = dueDate!;
    return today.year == due.year && 
           today.month == due.month && 
           today.day == due.day;
  }

  /// Check if task is due soon (within 24 hours)
  bool get isDueSoon {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final due = dueDate!;
    return due.isAfter(now) && 
           due.isBefore(now.add(const Duration(days: 1)));
  }

  /// Get task priority level
  int get priority {
    if (urgent) return 3;
    if (isOverdue) return 2;
    if (isDueToday) return 1;
    return 0;
  }

  /// Get formatted due date display
  String get dueDateDisplay {
    if (dueDate == null) return 'No due date';
    final now = DateTime.now();
    final due = dueDate!;
    final difference = due.difference(now).inDays;
    
    if (difference < 0) {
      return 'Overdue';
    } else if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference < 7) {
      return '${difference} days';
    } else {
      return '${due.day}/${due.month}/${due.year}';
    }
  }

  /// Get formatted repeat type display
  String get repeatDisplay {
    switch (repeatType) {
      case RepeatType.none:
        return 'No repeat';
      case RepeatType.daily:
        return 'Daily';
      case RepeatType.weekly:
        return 'Weekly';
      case RepeatType.monthly:
        return 'Monthly';
      case RepeatType.yearly:
        return 'Yearly';
    }
  }

  /// Convert to Map for database operations
  Map<String, dynamic> toMap() {
    return toJson();
  }

  /// Create from Map for database operations
  factory DuoTask.fromMap(Map<String, dynamic> map) {
    return DuoTask.fromJson(map);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DuoTask && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'DuoTask(id: $id, title: $title, status: $status, ownerId: $ownerId)';
  }
}
