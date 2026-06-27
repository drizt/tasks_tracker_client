import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_tracker/models/task.dart';
import 'package:tasks_tracker/utils/task_status_style.dart';

void main() {
  test('uses a distinct color for every task status', () {
    final colors = TaskStatus.values.map(taskStatusColor).toSet();

    expect(colors, hasLength(TaskStatus.values.length));
  });
}
