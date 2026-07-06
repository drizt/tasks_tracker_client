import 'package:flutter/material.dart';

import 'app.dart';
import 'window/task_window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeTaskWindow();
  runApp(const TasksTrackerApp());
}
