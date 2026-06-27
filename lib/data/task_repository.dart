import 'task_store.dart';

abstract class TaskRepository {
  Future<TaskStore> load();
  Future<void> save(TaskStore store);
}
