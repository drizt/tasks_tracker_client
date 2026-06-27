import '../models/task.dart';
import '../models/time_entry.dart';

class TaskStore {
  const TaskStore({required this.tasks, required this.timeEntries});

  final List<Task> tasks;
  final List<TimeEntry> timeEntries;

  factory TaskStore.fromJson(Map<String, dynamic> json) {
    return TaskStore(
      tasks: (json['tasks'] as List<dynamic>? ?? [])
          .map((item) => Task.fromJson(item as Map<String, dynamic>))
          .toList(),
      timeEntries: (json['timeEntries'] as List<dynamic>? ?? [])
          .map((item) => TimeEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tasks': tasks.map((task) => task.toJson()).toList(),
      'timeEntries': timeEntries.map((entry) => entry.toJson()).toList(),
    };
  }
}
