import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_tracker/data/json_task_repository.dart';
import 'package:tasks_tracker/data/task_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('seeds the runtime file when it does not exist', () async {
    final directory = await Directory.systemTemp.createTemp(
      'tasks_tracker_repository_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/tasks.json');
    final repository = JsonTaskRepository(filePath: file.path);

    final store = await repository.load();

    expect(store.tasks, isNotEmpty);
    expect(await file.exists(), isTrue);
    expect((await file.readAsString()).trim(), isNotEmpty);
  });

  test('recovers from an empty runtime file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'tasks_tracker_repository_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/tasks.json');
    await file.create(recursive: true);
    final repository = JsonTaskRepository(filePath: file.path);

    final store = await repository.load();

    expect(store.tasks, isNotEmpty);
    expect((await file.readAsString()).trim(), isNotEmpty);
  });

  test('backs up invalid JSON and reseeds the runtime file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'tasks_tracker_repository_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/tasks.json');
    await file.create(recursive: true);
    await file.writeAsString('not json');
    final repository = JsonTaskRepository(filePath: file.path);

    final store = await repository.load();
    final backupFiles = await directory
        .list()
        .where((entity) => entity.path.contains('.invalid.'))
        .toList();

    expect(store.tasks, isNotEmpty);
    expect(backupFiles, hasLength(1));
    expect(jsonDecode(await file.readAsString()), isA<Map<String, dynamic>>());
  });

  test('saves valid JSON atomically', () async {
    final directory = await Directory.systemTemp.createTemp(
      'tasks_tracker_repository_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/tasks.json');
    final repository = JsonTaskRepository(filePath: file.path);
    final store = await repository.load();

    await repository.save(TaskStore(tasks: store.tasks, timeEntries: const []));

    expect(jsonDecode(await file.readAsString()), isA<Map<String, dynamic>>());
    expect(await File('${file.path}.tmp').exists(), isFalse);
  });
}
