import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_tracker_client/data/task_repository.dart';
import 'package:tasks_tracker_client/data/task_store.dart';
import 'package:tasks_tracker_client/models/task.dart';
import 'package:tasks_tracker_client/models/time_entry.dart';
import 'package:tasks_tracker_client/screens/task_list_screen.dart';
import 'package:tasks_tracker_client/state/task_controller.dart';
import 'package:tasks_tracker_client/utils/duration_format.dart';
import 'package:tasks_tracker_client/widgets/task_card.dart';

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
    expect(controller.filter, TaskListFilter.work);
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

  testWidgets('moves and resizes the edit task dialog', (tester) async {
    final controller = await _pumpApp(tester, _storeWithTask());

    await tester.tap(find.byTooltip('Edit task'));
    await tester.pumpAndSettle();

    final dialog = find.byType(Dialog);
    final initialTopLeft = tester.getTopLeft(dialog);
    final initialSize = tester.getSize(dialog);

    await tester.drag(
      find.byKey(const ValueKey('task-dialog-title-bar')),
      const Offset(100, 60),
    );
    await tester.pump();

    expect(tester.getTopLeft(dialog), initialTopLeft + const Offset(100, 60));

    await tester.drag(
      find.byKey(const ValueKey('task-dialog-resize-handle')),
      const Offset(80, 50),
    );
    await tester.pump();

    expect(tester.getSize(dialog), initialSize + const Offset(80, 50));
    expect(tester.takeException(), isNull);

    controller.dispose();
  });

  testWidgets('maximizes the edit task dialog by double-clicking its title', (
    tester,
  ) async {
    final controller = await _pumpApp(tester, _storeWithTask());

    await tester.tap(find.byTooltip('Edit task'));
    await tester.pumpAndSettle();

    final dialog = find.byType(Dialog);
    final titleBar = find.byKey(const ValueKey('task-dialog-title-bar'));
    final initialSize = tester.getSize(dialog);

    await tester.tap(titleBar);
    await tester.tap(titleBar);
    await tester.pump();

    expect(tester.getTopLeft(dialog), const Offset(24, 24));
    expect(tester.getSize(dialog).width, greaterThan(initialSize.width));
    expect(tester.getSize(dialog).height, greaterThan(initialSize.height));
    expect(find.byTooltip('Move task dialog'), findsNothing);
    expect(find.byTooltip('Resize task dialog'), findsNothing);
    expect(tester.takeException(), isNull);

    controller.dispose();
  });

  testWidgets('makes selected task title and description selectable', (
    tester,
  ) async {
    final controller = await _pumpApp(tester, _storeWithTask());

    expect(find.widgetWithText(SelectableText, 'Tracked task'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('task-description')),
        matching: find.text('Task under test'),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Expand description'), findsNothing);

    controller.dispose();
  });

  testWidgets('collapses and expands the selected task description', (
    tester,
  ) async {
    final controller = await _pumpApp(
      tester,
      _storeWithTask(
        description: 'First line\nSecond line\nThird line\nFourth line',
      ),
    );
    final descriptionArea = find.byKey(const ValueKey('task-description'));
    Text description() => tester.widget(
      find.descendant(of: descriptionArea, matching: find.byType(Text)),
    );

    expect(description().maxLines, 3);
    expect(description().overflow, TextOverflow.clip);
    expect(
      find.descendant(of: descriptionArea, matching: find.byType(Scrollable)),
      findsNothing,
    );
    expect(find.byTooltip('Expand description'), findsOneWidget);

    await tester.tap(find.byTooltip('Expand description'));
    await tester.pump();

    expect(description().maxLines, isNull);
    expect(description().overflow, isNull);
    expect(find.byTooltip('Collapse description'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('shows nothing when selected task has no description', (
    tester,
  ) async {
    final controller = await _pumpApp(tester, _storeWithTask(description: ''));

    expect(find.text('No description'), findsNothing);

    controller.dispose();
  });

  testWidgets('Ctrl selects tasks and shows their combined time entries', (
    tester,
  ) async {
    final today = DateTime.now();
    final controller = await _pumpApp(
      tester,
      TaskStore(
        tasks: [
          _taskForWidgetTest('task-1', 'First task'),
          _taskForWidgetTest('task-2', 'Second task'),
        ],
        timeEntries: [
          TimeEntry(
            id: 'entry-1',
            taskId: 'task-1',
            startedAt: DateTime(today.year, today.month, today.day, 8),
            endedAt: DateTime(today.year, today.month, today.day, 8, 30),
          ),
          TimeEntry(
            id: 'entry-2',
            taskId: 'task-2',
            startedAt: DateTime(today.year, today.month, today.day, 9),
            endedAt: DateTime(today.year, today.month, today.day, 10),
          ),
        ],
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('First task'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(controller.selectedTaskIds, ['task-2', 'task-1']);
    expect(find.text('2 tasks selected'), findsOneWidget);
    expect(find.text('1:30:00'), findsWidgets);
    expect(find.text('30:00  First task'), findsOneWidget);
    expect(find.text('1:00:00  Second task'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Set status'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Complete'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Archive'), findsOneWidget);
    expect(find.text('Add entry'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
    await tester.pumpAndSettle();
    expect(
      controller.tasks.map((task) => task.status),
      everyElement(TaskStatus.completed),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Archive'));
    await tester.pumpAndSettle();
    expect(
      controller.tasks.map((task) => task.isArchived),
      everyElement(isTrue),
    );
    expect(find.widgetWithText(OutlinedButton, 'Unarchive'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Unarchive'));
    await tester.pumpAndSettle();
    expect(
      controller.tasks.map((task) => task.isArchived),
      everyElement(isFalse),
    );

    controller.dispose();
  });

  testWidgets('Up and Down select adjacent tasks', (tester) async {
    final controller = await _pumpApp(
      tester,
      TaskStore(
        tasks: [
          _taskForWidgetTest('task-1', 'First task'),
          _taskForWidgetTest('task-2', 'Second task'),
        ],
        timeEntries: const [],
      ),
    );

    expect(controller.selectedTaskId, 'task-1');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(controller.selectedTaskId, 'task-2');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(controller.selectedTaskId, 'task-1');

    controller.dispose();
  });

  testWidgets('scrolls to task selected with Up and Down', (tester) async {
    final controller = await _pumpApp(
      tester,
      TaskStore(
        tasks: [
          for (var index = 1; index <= 30; index++)
            _taskForWidgetTest('task-$index', 'Task $index'),
        ],
        timeEntries: const [],
      ),
    );

    for (var index = 1; index < 30; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.pumpAndSettle();

    expect(controller.selectedTaskId, 'task-30');
    final selectedTask = find.widgetWithText(TaskCard, 'Task 30');
    expect(selectedTask, findsOneWidget);
    expect(
      tester.getBottomRight(selectedTask).dy,
      lessThanOrEqualTo(tester.getBottomRight(find.byType(ListView).first).dy),
    );

    for (var index = 1; index < 30; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    }
    await tester.pumpAndSettle();

    expect(controller.selectedTaskId, 'task-1');
    expect(find.widgetWithText(TaskCard, 'Task 1'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('applies a status to all Ctrl-selected tasks', (tester) async {
    final controller = await _pumpApp(
      tester,
      TaskStore(
        tasks: [
          _taskForWidgetTest('task-1', 'First task'),
          _taskForWidgetTest('task-2', 'Second task'),
        ],
        timeEntries: const [],
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('Second task'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Set status'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Canceled'));
    await tester.pumpAndSettle();

    expect(
      controller.tasks.map((task) => task.status),
      everyElement(TaskStatus.canceled),
    );
    expect(controller.filter, TaskListFilter.canceled);
    expect(controller.selectedTaskIds, ['task-1', 'task-2']);
    expect(find.text('2 tasks selected'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('Shift adds a task range to the Ctrl selection', (tester) async {
    final controller = await _pumpApp(
      tester,
      TaskStore(
        tasks: [
          _taskForWidgetTest('task-1', 'First task'),
          _taskForWidgetTest('task-2', 'Second task'),
          _taskForWidgetTest('task-3', 'Third task'),
          _taskForWidgetTest('task-4', 'Fourth task'),
        ],
        timeEntries: const [],
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('Fourth task'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.text('Second task'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(controller.selectedTaskIds, [
      'task-1',
      'task-4',
      'task-2',
      'task-3',
    ]);
    expect(find.text('4 tasks selected'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('Ctrl+A selects all visible tasks', (tester) async {
    final controller = await _pumpApp(
      tester,
      TaskStore(
        tasks: [
          _taskForWidgetTest('task-1', 'First task'),
          _taskForWidgetTest('task-2', 'Second task'),
          _taskForWidgetTest(
            'completed',
            'Completed task',
            status: TaskStatus.completed,
          ),
        ],
        timeEntries: const [],
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(controller.selectedTaskIds, ['task-1', 'task-2']);
    expect(find.text('2 tasks selected'), findsOneWidget);

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
    await tester.tap(find.text(formatDate(DateTime(2026, 6, 27))));
    await tester.pumpAndSettle();
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

    await tester.tap(find.text(formatDate(DateTime(2026, 6, 27))));
    await tester.pumpAndSettle();
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

  testWidgets('groups entries by start date with daily totals', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final controller = await _pumpApp(
      tester,
      _storeWithTask(
        entries: [
          TimeEntry(
            id: 'today-entry',
            taskId: 'task-1',
            startedAt: today.add(const Duration(hours: 9)),
            endedAt: today.add(const Duration(hours: 10)),
            note: 'Today note',
          ),
          TimeEntry(
            id: 'cross-midnight-entry',
            taskId: 'task-1',
            startedAt: yesterday.add(const Duration(hours: 23)),
            endedAt: today.add(const Duration(hours: 1)),
            note: 'Cross-midnight note',
          ),
          TimeEntry(
            id: 'yesterday-entry',
            taskId: 'task-1',
            startedAt: yesterday.add(const Duration(hours: 12)),
            endedAt: yesterday.add(const Duration(hours: 12, minutes: 30)),
            note: 'Yesterday note',
          ),
        ],
      ),
    );

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('1:00:00'), findsNWidgets(2));
    expect(find.text('2:30:00'), findsOneWidget);
    expect(find.text('Today note'), findsOneWidget);
    expect(find.text('Cross-midnight note'), findsNothing);
    expect(find.text('Yesterday note'), findsNothing);
    expect(find.byIcon(Icons.schedule_rounded), findsNothing);

    await tester.tap(find.text('Yesterday'));
    await tester.pumpAndSettle();

    expect(find.text('Cross-midnight note'), findsOneWidget);
    expect(find.text('Yesterday note'), findsOneWidget);

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
  String description = 'Task under test',
  List<TimeEntry> entries = const [],
}) {
  return TaskStore(
    tasks: [
      Task(
        id: 'task-1',
        title: 'Tracked task',
        description: description,
        status: status,
        createdAt: DateTime.utc(2026, 6, 26, 8),
        updatedAt: DateTime.utc(2026, 6, 26, 8),
      ),
    ],
    timeEntries: entries,
  );
}

Task _taskForWidgetTest(
  String id,
  String title, {
  TaskStatus status = TaskStatus.active,
}) {
  return Task(
    id: id,
    title: title,
    description: '',
    status: status,
    createdAt: DateTime.utc(2026, 6, 26, 8),
    updatedAt: DateTime.utc(2026, 6, 26, 8),
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
