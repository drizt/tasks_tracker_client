import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'task_repository.dart';
import 'task_store.dart';

class JsonTaskRepository implements TaskRepository {
  JsonTaskRepository({
    this.seedAssetPath = 'assets/test_tasks.json',
    String? filePath,
  }) : filePath = filePath ?? _defaultFilePath();

  final String seedAssetPath;
  final String filePath;

  @override
  Future<TaskStore> load() async {
    final file = File(filePath);

    if (!await file.exists()) {
      await _writeSeedFile(file);
    }

    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      await _writeSeedFile(file);
      return _loadSeedStore();
    }

    try {
      return TaskStore.fromJson(jsonDecode(content) as Map<String, dynamic>);
    } on FormatException {
      await _backupCorruptFile(file);
      await _writeSeedFile(file);
      return _loadSeedStore();
    } on TypeError {
      await _backupCorruptFile(file);
      await _writeSeedFile(file);
      return _loadSeedStore();
    }
  }

  @override
  Future<void> save(TaskStore store) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString('${encoder.convert(store.toJson())}\n');
    await tempFile.rename(file.path);
  }

  Future<TaskStore> _loadSeedStore() async {
    final seedJson = await rootBundle.loadString(seedAssetPath);
    return TaskStore.fromJson(jsonDecode(seedJson) as Map<String, dynamic>);
  }

  Future<void> _writeSeedFile(File file) async {
    await file.parent.create(recursive: true);
    final seedJson = await rootBundle.loadString(seedAssetPath);
    await file.writeAsString(seedJson);
  }

  Future<void> _backupCorruptFile(File file) async {
    if (!await file.exists()) {
      return;
    }

    final backupPath =
        '${file.path}.invalid.${DateTime.now().toUtc().microsecondsSinceEpoch}';
    await file.rename(backupPath);
  }

  static String _defaultFilePath() {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      return 'tasks.json';
    }

    return '$home/.local/share/tasks_tracker/tasks.json';
  }
}
