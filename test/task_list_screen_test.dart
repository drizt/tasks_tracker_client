import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_tracker_client/data/task_repository.dart';
import 'package:tasks_tracker_client/data/task_store.dart';
import 'package:tasks_tracker_client/models/task.dart';
import 'package:tasks_tracker_client/models/time_entry.dart';
import 'package:tasks_tracker_client/screens/task_list_screen.dart';
import 'package:tasks_tracker_client/state/task_controller.dart';

void main() {
  testWidgets('adds a task from the sidebar', (tester) async {
    final controller = await _pumpApp(
      tester,
      const TaskStore(tasks: [], timeEntries: []),
    );

    await tester.tap(find.byTooltip('Add task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Write tests',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'Cover important UI workflows',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controller.tasks.single.title, 'Write tests');
    expect(controller.tasks.single.status, TaskStatus.newTask);
    expect(find.text('Write tests'), findsWidgets);

    controller.dispose();
  });

  testWidgets('changes status and moves task to the matching filter', (
    tester,
  ) async {
    final controller = await _pumpApp(tester, _storeWithTask());

    await tester.tap(find.widgetWithText(OutlinedButton, 'Active'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Completed'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controller.tasks.single.status, TaskStatus.completed);
    expect(controller.filter, TaskListFilter.completed);
    expect(find.text('Completed'), findsWidgets);

    controller.dispose();
  });

  testWidgets('filter chip width stays fixed when selection changes', (
    tester,
  ) async {
    final controller = await _pumpApp(
      tester,
      _storeWithTask(status: TaskStatus.completed),
    );
    final completedChip = find.widgetWithText(ChoiceChip, 'Completed');
    final initialWidth = tester.getSize(completedChip).width;

    await tester.tap(completedChip);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(completedChip).width, initialWidth);

    controller.dispose();
  });

  testWidgets('completes selected task from dedicated button', (tester) async {
    final controller = await _pumpApp(tester, _storeWithTask());

    await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controller.tasks.single.status, TaskStatus.completed);
    expect(controller.filter, TaskListFilter.completed);

    controller.dispose();
  });

  testWidgets('archives and unarchives selected task', (tester) async {
    final controller = await _pumpApp(tester, _storeWithTask());

    await tester.tap(find.widgetWithText(OutlinedButton, 'Archive'));
    await tester.pumpAndSettle();

    expect(controller.tasks.single.isArchived, isTrue);
    expect(controller.filter, TaskListFilter.archive);
    expect(find.widgetWithText(OutlinedButton, 'Unarchive'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Unarchive'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controller.tasks.single.isArchived, isFalse);
    expect(controller.tasks.single.status, TaskStatus.newTask);
    expect(controller.filter, TaskListFilter.work);

    controller.dispose();
  });

  testWidgets('resizes task list pane by dragging the split handle', (
    tester,
  ) async {
    final controller = await _pumpApp(tester, _storeWithTask());

    await tester.drag(find.byTooltip('Resize task list'), const Offset(80, 0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tracked task'), findsWidgets);

    controller.dispose();
  });

  testWidgets('opens server settings from the sidebar', (tester) async {
    var openCount = 0;
    final controller = await _pumpApp(
      tester,
      _storeWithTask(),
      onConfigureServer: (_) async {
        openCount += 1;
      },
    );

    await tester.tap(
      find.byTooltip('Server settings (ws://localhost:3000/ws)'),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(openCount, 1);

    controller.dispose();
  });

  testWidgets('stopping timer creates a saved time entry', (tester) async {
    final controller = await _pumpApp(
      tester,
      _storeWithTask(status: TaskStatus.newTask),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Start timer'));
    await tester.pumpAndSettle();

    expect(controller.entriesForTask('task-1'), hasLength(1));
    expect(controller.entriesForTask('task-1').single.endedAt, isNull);
    expect(find.textContaining('Running'), findsWidgets);
    expect(find.text('1'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Stop timer'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controller.tasks.single.status, TaskStatus.active);
    expect(controller.entriesForTask('task-1'), hasLength(1));
    expect(controller.entriesForTask('task-1').single.endedAt, isNotNull);

    controller.dispose();
  });

  testWidgets('adds a time entry from the detail screen', (tester) async {
    final controller = await _pumpApp(tester, _storeWithTask());

    await _addTimeEntry(
      tester,
      start: '2026-06-27 09:00:15',
      end: '2026-06-27 10:00:45',
      note: 'Review',
    );

    expect(tester.takeException(), isNull);
    expect(controller.entriesForTask('task-1'), hasLength(1));
    expect(find.text('Review'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('edits and deletes a time entry from the detail screen', (
    tester,
  ) async {
    final controller = await _pumpApp(
      tester,
      _storeWithTask(
        entries: [
          TimeEntry(
            id: 'entry-1',
            taskId: 'task-1',
            startedAt: DateTime(2026, 6, 27, 9),
            endedAt: DateTime(2026, 6, 27, 10),
            note: 'Original note',
          ),
        ],
      ),
    );

    await tester.tap(find.byTooltip('Edit time entry'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(1),
      '2026-06-27 10:30:30',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'Updated note');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(controller.entriesForTask('task-1').single.note, 'Updated note');
    expect(
      controller.totalForTask('task-1'),
      const Duration(hours: 1, minutes: 30, seconds: 30),
    );
    expect(find.text('Updated note'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete time entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controller.entriesForTask('task-1'), isEmpty);
    expect(find.text('No saved time entries'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('shows selectable error text with copy action', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var openCount = 0;
    final controller = TaskController(_FailingTaskRepository());
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
        home: TaskListScreen(
          controller: controller,
          serverUri: Uri.parse('ws://localhost:3000/ws'),
          onConfigureServer: (_) async {
            openCount += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load tasks'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.textContaining('SocketException'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Copy'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Server'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Copy'));
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Server'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(openCount, 1);

    controller.dispose();
  });
}

Future<TaskController> _pumpApp(
  WidgetTester tester,
  TaskStore store, {
  Future<void> Function(BuildContext context)? onConfigureServer,
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final controller = TaskController(_MemoryTaskRepository(store));
  await controller.load();

  await tester.pumpWidget(
    MaterialApp(
      home: TaskListScreen(
        controller: controller,
        serverUri: Uri.parse('ws://localhost:3000/ws'),
        onConfigureServer: onConfigureServer ?? (_) async {},
      ),
    ),
  );
  await tester.pumpAndSettle();

  return controller;
}

TaskStore _storeWithTask({
  TaskStatus status = TaskStatus.active,
  List<TimeEntry> entries = const [],
}) {
  return TaskStore(
    tasks: [
      Task(
        id: 'task-1',
        title: 'Tracked task',
        description: 'Task under test',
        status: status,
        createdAt: DateTime.utc(2026, 6, 26, 8),
        updatedAt: DateTime.utc(2026, 6, 26, 8),
      ),
    ],
    timeEntries: entries,
  );
}

Future<void> _addTimeEntry(
  WidgetTester tester, {
  required String start,
  required String end,
  required String note,
}) async {
  await tester.tap(find.text('Add entry'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'Start'), start);
  await tester.enterText(find.widgetWithText(TextFormField, 'End'), end);
  await tester.enterText(find.widgetWithText(TextFormField, 'Note'), note);
  await tester.tap(find.widgetWithText(FilledButton, 'Save'));
  await tester.pumpAndSettle();
}

class _MemoryTaskRepository implements TaskRepository {
  _MemoryTaskRepository(this.store);

  TaskStore store;

  @override
  Future<TaskStore> load() async => store;

  @override
  Future<void> save(TaskStore store) async {
    this.store = store;
  }
}

class _FailingTaskRepository implements TaskRepository {
  @override
  Future<TaskStore> load() async {
    throw Exception('SocketException: connection refused');
  }

  @override
  Future<void> save(TaskStore store) async {}
}
