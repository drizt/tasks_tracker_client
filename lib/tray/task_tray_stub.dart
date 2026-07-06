import '../state/task_controller.dart';

TaskTray createTaskTray({
  void Function()? exitApplication,
  Future<void> Function()? toggleAppWindow,
}) {
  return TaskTray();
}

class TaskTray {
  void attach(TaskController? controller) {}

  Future<void> dispose() async {}
}
