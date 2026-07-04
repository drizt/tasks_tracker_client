import 'dart:async';

import 'package:flutter/material.dart';

import 'data/server_endpoint.dart';
import 'data/web_socket_task_repository.dart';
import 'data/web_socket_task_rpc_client.dart';
import 'state/task_controller.dart';
import 'screens/task_list_screen.dart';

class TasksTrackerApp extends StatefulWidget {
  const TasksTrackerApp({super.key});

  @override
  State<TasksTrackerApp> createState() => _TasksTrackerAppState();
}

class _TasksTrackerAppState extends State<TasksTrackerApp> {
  late final TaskController controller;
  late final WebSocketTaskRepository repository;

  @override
  void initState() {
    super.initState();
    repository = WebSocketTaskRepository(
      client: WebSocketTaskRpcClient(defaultServerWebSocketUri()),
    );
    controller = TaskController(repository);
    repository.onStoreChanged = controller.applyStore;
    unawaited(controller.load());
  }

  @override
  void dispose() {
    controller.dispose();
    unawaited(repository.close());
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
