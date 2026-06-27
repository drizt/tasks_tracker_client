enum TaskStatus {
  newTask,
  active,
  completed,
  deferred,
  canceled;

  static TaskStatus fromJson(String value) {
    final normalizedValue = value == 'new' ? 'newTask' : value;
    return TaskStatus.values.firstWhere(
      (status) => status.name == normalizedValue,
      orElse: () => TaskStatus.active,
    );
  }

  String get label {
    return switch (this) {
      TaskStatus.newTask => 'New',
      TaskStatus.active => 'Active',
      TaskStatus.completed => 'Completed',
      TaskStatus.deferred => 'Deferred',
      TaskStatus.canceled => 'Canceled',
    };
  }

  String get jsonValue {
    return switch (this) {
      TaskStatus.newTask => 'new',
      _ => name,
    };
  }
}

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
    this.archivedAt,
  });

  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
  final DateTime? archivedAt;

  bool get isCompleted => status == TaskStatus.completed;

  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: clearArchivedAt ? null : archivedAt ?? this.archivedAt,
    );
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      status: TaskStatus.fromJson(json['status'] as String? ?? 'active'),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isArchived: json['isArchived'] as bool? ?? false,
      archivedAt: json['archivedAt'] == null
          ? null
          : DateTime.parse(json['archivedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status.jsonValue,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'isArchived': isArchived,
      'archivedAt': archivedAt?.toUtc().toIso8601String(),
    };
  }
}
