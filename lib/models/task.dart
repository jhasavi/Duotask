enum TaskStatus {
  unclaimed,
  claimed,
  completed;

  String get displayName {
    switch (this) {
      case TaskStatus.unclaimed:
        return 'Unclaimed';
      case TaskStatus.claimed:
        return 'Claimed';
      case TaskStatus.completed:
        return 'Completed';
    }
  }
}

enum TaskPriority {
  normal,
  urgent;

  String get displayName {
    switch (this) {
      case TaskPriority.normal:
        return 'Normal';
      case TaskPriority.urgent:
        return 'Urgent';
    }
  }
}

enum TaskRecurrence {
  none,
  daily,
  weekly;

  String get displayName {
    switch (this) {
      case TaskRecurrence.none:
        return 'None';
      case TaskRecurrence.daily:
        return 'Daily';
      case TaskRecurrence.weekly:
        return 'Weekly';
    }
  }
}

class Task {
  final String id;
  final String title;
  final String? description;
  final String createdById;
  final String? assignedToId;
  final String? claimedById;
  final TaskStatus status;
  final TaskPriority priority;
  final TaskRecurrence recurrence;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final bool isPersonal;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.createdById,
    this.assignedToId,
    this.claimedById,
    required this.status,
    required this.priority,
    required this.recurrence,
    this.dueDate,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
    required this.isPersonal,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      createdById: json['created_by_id'] as String,
      assignedToId: json['assigned_to_id'] as String?,
      claimedById: json['claimed_by_id'] as String?,
      status: TaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TaskStatus.unclaimed,
      ),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => TaskPriority.normal,
      ),
      recurrence: TaskRecurrence.values.firstWhere(
        (e) => e.name == json['recurrence'],
        orElse: () => TaskRecurrence.none,
      ),
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      isPersonal: json['is_personal'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'created_by_id': createdById,
      'assigned_to_id': assignedToId,
      'claimed_by_id': claimedById,
      'status': status.name,
      'priority': priority.name,
      'recurrence': recurrence.name,
      'due_date': dueDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'is_personal': isPersonal,
    };
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? createdById,
    String? assignedToId,
    String? claimedById,
    TaskStatus? status,
    TaskPriority? priority,
    TaskRecurrence? recurrence,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool? isPersonal,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdById: createdById ?? this.createdById,
      assignedToId: assignedToId ?? this.assignedToId,
      claimedById: claimedById ?? this.claimedById,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      recurrence: recurrence ?? this.recurrence,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      isPersonal: isPersonal ?? this.isPersonal,
    );
  }

  bool get isUrgent => priority == TaskPriority.urgent;
  bool get isOverdue =>
      dueDate != null && dueDate!.isBefore(DateTime.now()) && status != TaskStatus.completed;
  bool get isDueToday =>
      dueDate != null &&
      dueDate!.year == DateTime.now().year &&
      dueDate!.month == DateTime.now().month &&
      dueDate!.day == DateTime.now().day;

  @override
  String toString() {
    return 'Task(id: $id, title: $title, status: ${status.displayName}, priority: ${priority.displayName})';
  }
}
