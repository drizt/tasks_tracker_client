import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_tracker_client/data/task_repository.dart';
import 'package:tasks_tracker_client/data/task_store.dart';
import 'package:tasks_tracker_client/models/task.dart';
import 'package:tasks_tracker_client/models/time_entry.dart';
import 'package:tasks_tracker_client/state/task_controller.dart';

void main() {
  test('loads tasks and calculates saved time', () async {
    final repository = _MemoryTaskRepository(
      TaskStore(
        tasks: [
          Task(
            id: 'task-1',
            title: 'Build UI',
            description: 'Desktop layout',
            status: TaskStatus.active,
            createdAt: DateTime.utc(2026, 6, 26, 8),
            updatedAt: DateTime.utc(2026, 6, 26, 8),
          ),
        ],
        timeEntries: [
          TimeEntry(
            id: 'entry-1',
            taskId: 'task-1',
            startedAt: DateTime.utc(2026, 6, 26, 8),
            endedAt: DateTime.utc(2026, 6, 26, 8, 45),
          ),
        ],
      ),
    );
    final controller = TaskController(repository);

    await controller.load();

    expect(controller.tasks, hasLength(1));
    expect(controller.selectedTaskId, 'task-1');
    expect(controller.totalForTask('task-1'), const Duration(minutes: 45));
  });

  test('orders time entries by start time descending', () async {
    final repository = _MemoryTaskRepository(
      TaskStore(
        tasks: const [],
        timeEntries: [
          TimeEntry(
            id: 'middle-entry',
            taskId: 'task-1',
            startedAt: DateTime.utc(2026, 6, 26, 10),
          ),
          TimeEntry(
            id: 'newest-entry',
            taskId: 'task-1',
            startedAt: DateTime.utc(2026, 6, 26, 11),
          ),
          TimeEntry(
            id: 'oldest-entry',
            taskId: 'task-1',
            startedAt: DateTime.utc(2026, 6, 26, 9),
          ),
        ],
      ),
    );
    final controller = TaskController(repository);

    await controller.load();

    expect(controller.entriesForTask('task-1').map((entry) => entry.id), [
      'newest-entry',
      'middle-entry',
      'oldest-entry',
    ]);
  });

  test('supports additive task selection and aggregate time data', () async {
    final repository = _MemoryTaskRepository(
      TaskStore(
        tasks: [_task('task-1'), _task('task-2'), _task('task-3')],
        timeEntries: [
          TimeEntry(
            id: 'entry-1',
            taskId: 'task-1',
            startedAt: DateTime.utc(2026, 6, 26, 8),
            endedAt: DateTime.utc(2026, 6, 26, 8, 30),
          ),
          TimeEntry(
            id: 'entry-2',
            taskId: 'task-2',
            startedAt: DateTime.utc(2026, 6, 26, 10),
            endedAt: DateTime.utc(2026, 6, 26, 11),
          ),
        ],
      ),
    );
    final controller = TaskController(repository);

    await controller.load();
    controller.selectTask('task-1');
    controller.selectTask('task-2', additive: true);

    expect(controller.selectedTaskIds, ['task-1', 'task-2']);
    expect(
      controller.totalForTasks(controller.selectedTaskIds),
      const Duration(minutes: 90),
    );
    expect(
      controller
          .entriesForTasks(controller.selectedTaskIds)
          .map((entry) => entry.id),
      ['entry-2', 'entry-1'],
    );

    controller.selectTask('task-1', additive: true);
    expect(controller.selectedTaskIds, ['task-2']);

    controller.selectTask('task-3');
    expect(controller.selectedTaskIds, ['task-3']);
  });

  test('selects a task range and all visible tasks', () async {
    final repository = _MemoryTaskRepository(
      TaskStore(
        tasks: [
          _task('task-1'),
          _task('task-2'),
          _task('task-3'),
          _task('completed', status: TaskStatus.completed),
        ],
        timeEntries: const [],
      ),
    );
    final controller = TaskController(repository);

    await controller.load();
    controller.selectTask('task-3', range: true);

    expect(controller.selectedTaskIds, ['task-1', 'task-2', 'task-3']);

    controller.selectTask('task-1');
    controller.selectTask('task-3', additive: true);
    controller.selectTask('task-2', range: true);
    expect(controller.selectedTaskIds, ['task-1', 'task-3', 'task-2']);

    controller.selectAllVisibleTasks();
    expect(controller.selectedTaskIds, ['task-1', 'task-2', 'task-3']);
    expect(controller.selectedTaskIds, isNot(contains('completed')));
  });

  test('selects adjacent tasks in visible order', () async {
    final repository = _MemoryTaskRepository(
      TaskStore(
        tasks: [_task('task-1'), _task('task-2'), _task('task-3')],
        timeEntries: const [],
      ),
    );
    final controller = TaskController(repository);

    await controller.load();
    controller.selectNextTask();
    expect(controller.selectedTaskId, 'task-2');

    controller.selectTask('task-1', additive: true);
    controller.selectNextTask();
    expect(controller.selectedTaskIds, ['task-2']);

    controller.selectNextTask();
    expect(controller.selectedTaskId, 'task-3');

    controller.selectNextTask();
    expect(controller.selectedTaskId, 'task-3');

    controller.selectPreviousTask();
    expect(controller.selectedTaskId, 'task-2');
  });

  test('changes the status of all selected tasks', () async {
    final repository = _MemoryTaskRepository(
      TaskStore(
        tasks: [_task('task-1'), _task('task-2')],
        timeEntries: const [],
      ),
    );
    final controller = TaskController(repository);

    await controller.load();
    controller.selectTask('task-2', additive: true);
    await controller.changeTasksStatus(
      controller.selectedTaskIds,
      TaskStatus.deferred,
    );

    expect(
      controller.tasks.map((task) => task.status),
      everyElement(TaskStatus.deferred),
    );
    expect(controller.filter, TaskListFilter.deferred);
    expect(controller.selectedTaskIds, ['task-1', 'task-2']);
    expect(
      repository.savedStore!.tasks.map((task) => task.status),
      everyElement(TaskStatus.deferred),
    );
  });

  test('completes, archives, and unarchives all selected tasks', () async {
    final repository = _MemoryTaskRepository(
      TaskStore(
        tasks: [_task('task-1'), _task('task-2')],
        timeEntries: [
          TimeEntry(
            id: 'entry-1',
            taskId: 'task-1',
            startedAt: DateTime.now().toUtc().subtract(
              const Duration(minutes: 10),
            ),
          ),
        ],
      ),
    );
    final controller = TaskController(repository);

    await controller.load();
    controller.selectTask('task-2', additive: true);
    await controller.completeTasks(controller.selectedTaskIds);

    expect(controller.hasActiveTimer, isFalse);
    expect(
      controller.tasks.map((task) => task.status),
      everyElement(TaskStatus.completed),
    );

    await controller.archiveTasks(controller.selectedTaskIds);
    expect(
      controller.tasks.map((task) => task.isArchived),
      everyElement(isTrue),
    );

    await controller.unarchiveTasks(controller.selectedTaskIds);
    expect(
      controller.tasks.map((task) => task.isArchived),
      everyElement(isFalse),
    );
    expect(controller.tasks.first.status, TaskStatus.active);
    expect(controller.tasks.last.status, TaskStatus.newTask);
  });

  test('adds a task and saves it through the repository', () async {
    final repository = _MemoryTaskRepository(
      const TaskStore(tasks: [], timeEntries: []),
    );
    final controller = TaskController(repository);

    await controller.load();
    await controller.addTask(
      title: ' Model local data ',
      description: ' JSON-backed app state ',
    );

    expect(controller.tasks, hasLength(1));
    expect(controller.tasks.first.title, 'Model local data');
    expect(
      repository.savedStore?.tasks.first.description,
      'JSON-backed app state',
    );
  });

  test(
    'new tasks appear in work view and become active when timer starts',
    () async {
      final repository = _MemoryTaskRepository(
        const TaskStore(tasks: [], timeEntries: []),
      );
      final controller = TaskController(repository);

      await controller.load();
      await controller.addTask(title: 'Plan statuses', description: '');
      await controller.startTimer(controller.tasks.first.id);

      expect(controller.filter, TaskListFilter.work);
      expect(controller.filteredTasks, hasLength(1));
      expect(controller.tasks.first.status, TaskStatus.active);
    },
  );

  test('running timer creates and closes one open time entry', () async {
    final repository = _MemoryTaskRepository(
      TaskStore(
        tasks: [
          Task(
            id: 'task-1',
            title: 'Tracked task',
            description: '',
            status: TaskStatus.active,
            createdAt: DateTime.utc(2026, 6, 26, 8),
            updatedAt: DateTime.utc(2026, 6, 26, 8),
          ),
        ],
        timeEntries: const [],
      ),
    );
    final controller = TaskController(repository);

    await controller.load();
    await controller.startTimer('task-1');

    final openEntry = controller.entriesForTask('task-1').single;
    expect(openEntry.endedAt, isNull);
    expect(openEntry.isRunning, isTrue);
    expect(controller.activeEntryId, openEntry.id);

    await controller.stopTimer();

    final closedEntry = controller.entriesForTask('task-1').single;
    expect(closedEntry.id, openEntry.id);
    expect(closedEntry.endedAt, isNotNull);
    expect(controller.hasActiveTimer, isFalse);
  });

  test('load restores an open running entry', () async {
    final startedAt = DateTime.now().toUtc().subtract(
      const Duration(minutes: 10),
    );
    final repository = _MemoryTaskRepository(
      TaskStore(
        tasks: [
          Task(
            id: 'task-1',
            title: 'Tracked task',
            description: '',
            status: TaskStatus.active,
            createdAt: DateTime.utc(2026, 6, 26, 8),
            updatedAt: DateTime.utc(2026, 6, 26, 8),
          ),
        ],
        timeEntries: [
          TimeEntry(id: 'entry-1', taskId: 'task-1', startedAt: startedAt),
        ],
      ),
    );
    final controller = TaskController(repository);

    await controller.load();

    expect(controller.activeTaskId, 'task-1');
    expect(controller.activeEntryId, 'entry-1');
    expect(controller.entriesForTask('task-1').single.isRunning, isTrue);
    expect(
      controller.totalForTask('task-1').inMinutes,
      greaterThanOrEqualTo(9),
    );

    controller.dispose();
  });

  test(
    'orders visible tasks by latest finished entry with running task first',
    () async {
      final repository = _MemoryTaskRepository(
        TaskStore(
          tasks: [
            _task('without-entry', updatedAt: DateTime.utc(2026, 6, 26, 10)),
            _task('older-entry'),
            _task('running'),
            _task('newer-entry'),
          ],
          timeEntries: [
            _finishedEntry('older-entry', DateTime.utc(2026, 6, 26, 9)),
            TimeEntry(
              id: 'entry-running',
              taskId: 'running',
              startedAt: DateTime.now().toUtc().subtract(
                const Duration(minutes: 10),
              ),
            ),
            _finishedEntry('newer-entry', DateTime.utc(2026, 6, 26, 11)),
          ],
        ),
      );
      final controller = TaskController(repository);

      await controller.load();

      expect(controller.filteredTasks.map((task) => task.id), [
        'running',
        'newer-entry',
        'without-entry',
        'older-entry',
      ]);

      controller.dispose();
    },
  );

  test('orders completed tasks by latest finished entry descending', () async {
    final repository = _MemoryTaskRepository(
      TaskStore(
        tasks: [
          _task('older-entry', status: TaskStatus.completed),
          _task(
            'without-entry',
            status: TaskStatus.completed,
            updatedAt: DateTime.utc(2026, 6, 26, 10),
          ),
          _task('newer-entry', status: TaskStatus.completed),
        ],
        timeEntries: [
          _finishedEntry('older-entry', DateTime.utc(2026, 6, 26, 9)),
          _finishedEntry('newer-entry', DateTime.utc(2026, 6, 26, 11)),
        ],
      ),
    );
    final controller = TaskController(repository);

    await controller.load();
    controller.setFilter(TaskListFilter.completed);

    expect(controller.filteredTasks.map((task) => task.id), [
      'newer-entry',
      'without-entry',
      'older-entry',
    ]);
  });

  test('archives tasks and unarchives them as new tasks', () async {
    final repository = _MemoryTaskRepository(
      TaskStore(
        tasks: [
          Task(
            id: 'task-1',
            title: 'Done task',
            description: '',
            status: TaskStatus.completed,
            createdAt: DateTime.utc(2026, 6, 26, 8),
            updatedAt: DateTime.utc(2026, 6, 26, 8),
          ),
        ],
        timeEntries: const [],
      ),
    );
    final controller = TaskController(repository);

    await controller.load();
    controller.setFilter(TaskListFilter.completed);
    await controller.archiveTask('task-1');

    expect(controller.filter, TaskListFilter.completed);
    expect(controller.tasks.single.isArchived, isTrue);
    expect(controller.tasks.single.status, TaskStatus.completed);

    controller.setFilter(TaskListFilter.archive);
    await controller.unarchiveTask('task-1');

    expect(controller.filter, TaskListFilter.archive);
    expect(controller.tasks.single.isArchived, isFalse);
    expect(controller.tasks.single.status, TaskStatus.newTask);
  });

  test('unarchives tasks with time entries as active tasks', () async {
    final repository = _MemoryTaskRepository(
      TaskStore(
        tasks: [
          Task(
            id: 'task-1',
            title: 'Tracked task',
            description: '',
            status: TaskStatus.completed,
            createdAt: DateTime.utc(2026, 6, 26, 8),
            updatedAt: DateTime.utc(2026, 6, 26, 8),
          ),
        ],
        timeEntries: [
          TimeEntry(
            id: 'entry-1',
            taskId: 'task-1',
            startedAt: DateTime.utc(2026, 6, 26, 8),
            endedAt: DateTime.utc(2026, 6, 26, 8, 30),
          ),
        ],
      ),
    );
    final controller = TaskController(repository);

    await controller.load();
    await controller.archiveTask('task-1');
    controller.setFilter(TaskListFilter.archive);
    await controller.unarchiveTask('task-1');

    expect(controller.filter, TaskListFilter.archive);
    expect(controller.tasks.single.isArchived, isFalse);
    expect(controller.tasks.single.status, TaskStatus.active);
  });

  test(
    'complete task stops running timer and moves task to completed',
    () async {
      final repository = _MemoryTaskRepository(
        TaskStore(
          tasks: [
            Task(
              id: 'task-1',
              title: 'Tracked task',
              description: '',
              status: TaskStatus.active,
              createdAt: DateTime.utc(2026, 6, 26, 8),
              updatedAt: DateTime.utc(2026, 6, 26, 8),
            ),
          ],
          timeEntries: const [],
        ),
      );
      final controller = TaskController(repository);

      await controller.load();
      await controller.startTimer('task-1');
      await controller.completeTask('task-1');

      expect(controller.hasActiveTimer, isFalse);
      expect(controller.tasks.single.status, TaskStatus.completed);
      expect(controller.entriesForTask('task-1').single.endedAt, isNotNull);
      expect(controller.filter, TaskListFilter.completed);
    },
  );

  test('creates, updates, and deletes manual time entries', () async {
    final repository = _MemoryTaskRepository(
      TaskStore(
        tasks: [
          Task(
            id: 'task-1',
            title: 'Tracked task',
            description: '',
            status: TaskStatus.active,
            createdAt: DateTime.utc(2026, 6, 26, 8),
            updatedAt: DateTime.utc(2026, 6, 26, 8),
          ),
        ],
        timeEntries: const [],
      ),
    );
    final controller = TaskController(repository);

    await controller.load();
    await controller.addTimeEntry(
      taskId: 'task-1',
      startedAt: DateTime.utc(2026, 6, 26, 9),
      endedAt: DateTime.utc(2026, 6, 26, 10),
      note: ' Manual work ',
    );

    final entry = controller.entriesForTask('task-1').single;
    expect(entry.note, 'Manual work');
    expect(controller.totalForTask('task-1'), const Duration(hours: 1));

    await controller.updateTimeEntry(
      entry.copyWith(
        endedAt: DateTime.utc(2026, 6, 26, 10, 30),
        note: 'Extended work',
      ),
    );

    final updatedEntry = controller.entriesForTask('task-1').single;
    expect(updatedEntry.note, 'Extended work');
    expect(controller.totalForTask('task-1'), const Duration(minutes: 90));

    await controller.deleteTimeEntry(updatedEntry.id);

    expect(controller.entriesForTask('task-1'), isEmpty);
    expect(controller.totalForTask('task-1'), Duration.zero);
  });
}

Task _task(
  String id, {
  TaskStatus status = TaskStatus.active,
  DateTime? updatedAt,
}) {
  return Task(
    id: id,
    title: id,
    description: '',
    status: status,
    createdAt: DateTime.utc(2026, 6, 26, 8),
    updatedAt: updatedAt ?? DateTime.utc(2026, 6, 26, 8),
  );
}

TimeEntry _finishedEntry(String taskId, DateTime endedAt) {
  return TimeEntry(
    id: 'entry-$taskId',
    taskId: taskId,
    startedAt: endedAt.subtract(const Duration(hours: 1)),
    endedAt: endedAt,
  );
}

class _MemoryTaskRepository implements TaskRepository {
  _MemoryTaskRepository(this.store);

  TaskStore store;
  TaskStore? savedStore;

  @override
  Future<TaskStore> load() async => store;

  @override
  Future<void> save(TaskStore store) async {
    this.store = store;
    savedStore = store;
  }
}
