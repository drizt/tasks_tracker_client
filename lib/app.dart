import 'package:flutter/material.dart';

import 'data/json_task_repository.dart';
import 'state/task_controller.dart';
import 'screens/task_list_screen.dart';

class TasksTrackerApp extends StatefulWidget {
  const TasksTrackerApp({super.key});

  @override
  State<TasksTrackerApp> createState() => _TasksTrackerAppState();
}

class _TasksTrackerAppState extends State<TasksTrackerApp> {
  late final TaskController controller;

  @override
  void initState() {
    super.initState();
    controller = TaskController(JsonTaskRepository())..load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tasks Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff1f7a5a),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        visualDensity: VisualDensity.compact,
      ),
      home: TaskListScreen(controller: controller),
    );
  }
}
