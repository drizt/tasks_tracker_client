import 'dart:async';

import 'package:flutter/material.dart';

import 'data/client_settings.dart';
import 'data/client_settings_store.dart';
import 'data/server_endpoint.dart';
import 'data/web_socket_task_repository.dart';
import 'data/web_socket_task_rpc_client.dart';
import 'screens/server_settings_dialog.dart';
import 'state/task_controller.dart';
import 'screens/task_list_screen.dart';
import 'tray/task_tray.dart';
import 'window/task_window.dart';

class TasksTrackerApp extends StatefulWidget {
  const TasksTrackerApp({super.key});

  @override
  State<TasksTrackerApp> createState() => _TasksTrackerAppState();
}

class _TasksTrackerAppState extends State<TasksTrackerApp> {
  late final ClientSettingsStore settingsStore;
  late final TaskTray taskTray;
  late final TaskWindow taskWindow;
  TaskController? controller;
  WebSocketTaskRepository? repository;
  Uri serverUri = defaultServerWebSocketUri();
  String? startupError;

  @override
  void initState() {
    super.initState();
    settingsStore = createClientSettingsStore();
    taskWindow = createTaskWindow();
    taskTray = createTaskTray(toggleAppWindow: taskWindow.toggle);
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      final settings = await settingsStore.load();
      await _connect(settings.serverUri ?? defaultServerWebSocketUri());
    } on Object catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        startupError = exception.toString();
      });
    }
  }

  Future<void> _connect(Uri nextServerUri) async {
    final nextRepository = WebSocketTaskRepository(
      client: WebSocketTaskRpcClient(nextServerUri),
    );
    final nextController = TaskController(nextRepository);
    nextRepository.onStoreChanged = nextController.applyStore;

    if (!mounted) {
      nextController.dispose();
      unawaited(nextRepository.close());
      return;
    }

    final previousController = controller;
    final previousRepository = repository;
    setState(() {
      serverUri = nextServerUri;
      repository = nextRepository;
      controller = nextController;
      startupError = null;
    });

    taskTray.attach(nextController);
    previousController?.dispose();
    unawaited(previousRepository?.close());
    unawaited(nextController.load());
  }

  Future<void> _configureServer(BuildContext context) async {
    final nextServerUri = await showServerSettingsDialog(
      context,
      serverUri: serverUri,
    );
    if (nextServerUri == null) {
      return;
    }

    try {
      await settingsStore.save(ClientSettings(serverUri: nextServerUri));
      await _connect(nextServerUri);
    } on Object catch (exception) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(exception.toString())));
      return;
    }

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Server saved')));
  }

  @override
  void dispose() {
    taskTray.attach(null);
    controller?.dispose();
    unawaited(repository?.close());
    unawaited(taskTray.dispose());
    unawaited(taskWindow.dispose());
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
      home: controller == null
          ? _StartupScreen(
              error: startupError,
              onConfigureServer: _configureServer,
            )
          : TaskListScreen(
              controller: controller!,
              serverUri: serverUri,
              onConfigureServer: _configureServer,
            ),
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen({required this.error, required this.onConfigureServer});

  final String? error;
  final Future<void> Function(BuildContext context) onConfigureServer;

  @override
  Widget build(BuildContext context) {
    final message = error;

    return Scaffold(
      body: Center(
        child: message == null
            ? const CircularProgressIndicator()
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 42),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load settings',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => onConfigureServer(context),
                      icon: const Icon(Icons.settings_rounded),
                      label: const Text('Server'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
