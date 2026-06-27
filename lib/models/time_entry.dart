class TimeEntry {
  const TimeEntry({
    required this.id,
    required this.taskId,
    required this.startedAt,
    this.endedAt,
    this.note = '',
  });

  final String id;
  final String taskId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String note;

  bool get isRunning => endedAt == null;

  Duration get duration => durationUntil(DateTime.now());

  Duration durationUntil(DateTime now) {
    final effectiveEnd = endedAt ?? now;
    final duration = effectiveEnd.difference(startedAt);
    if (duration.isNegative) {
      return Duration.zero;
    }

    return duration;
  }

  TimeEntry copyWith({
    String? id,
    String? taskId,
    DateTime? startedAt,
    DateTime? endedAt,
    String? note,
    bool clearEndedAt = false,
  }) {
    return TimeEntry(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: clearEndedAt ? null : endedAt ?? this.endedAt,
      note: note ?? this.note,
    );
  }

  factory TimeEntry.fromJson(Map<String, dynamic> json) {
    return TimeEntry(
      id: json['id'] as String,
      taskId: json['taskId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.parse(json['endedAt'] as String),
      note: json['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'endedAt': endedAt?.toUtc().toIso8601String(),
      'note': note,
    };
  }
}
