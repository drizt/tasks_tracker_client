import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/task_repository.dart';
import '../data/task_store.dart';
import '../models/task.dart';
import '../models/time_entry.dart';
import '../utils/task_id.dart';

enum TaskListFilter {
  work,
  completed,
  deferred,
  canceled,
  archive;

  String get label {
    return switch (this) {
      TaskListFilter.work => 'Work',
      TaskListFilter.completed => 'Completed',
      TaskListFilter.deferred => 'Deferred',
      TaskListFilter.canceled => 'Canceled',
      TaskListFilter.archive => 'Archive',
    };
  }
}

class TaskController extends ChangeNotifier {
  TaskController(this._repository);

  final TaskRepository _repository;

  List<Task> _tasks = [];
  List<TimeEntry> _timeEntries = [];
  final List<String> _selectedTaskIds = [];
  String? _activeTaskId;
  String? _activeEntryId;
  DateTime? _activeStartedAt;
  TaskListFilter _filter = TaskListFilter.work;
  Timer? _ticker;
  bool _isLoading = true;
  String? _error;

  List<Task> get tasks => List.unmodifiable(_tasks);
  List<TimeEntry> get timeEntries => List.unmodifiable(_timeEntries);
  String? get selectedTaskId =>
      _selectedTaskIds.isEmpty ? null : _selectedTaskIds.last;
  List<String> get selectedTaskIds => List.unmodifiable(_selectedTaskIds);
  String? get activeTaskId => _activeTaskId;
  String? get activeEntryId => _activeEntryId;
  DateTime? get activeStartedAt => _activeStartedAt;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasActiveTimer => _activeTaskId != null && _activeStartedAt != null;
  TaskListFilter get filter => _filter;

  List<Task> get filteredTasks {
    final visibleTasks = _tasks.where(_matchesFilter).toList();
    final originalIndexes = {
      for (var index = 0; index < visibleTasks.length; index++)
        visibleTasks[index].id: index,
    };
    final latestEndedAtByTaskId = <String, DateTime>{};

    for (final entry in _timeEntries) {
      final endedAt = entry.endedAt;
      if (endedAt == null) {
        continue;
      }

      final latestEndedAt = latestEndedAtByTaskId[entry.taskId];
      if (latestEndedAt == null || endedAt.isAfter(latestEndedAt)) {
        latestEndedAtByTaskId[entry.taskId] = endedAt;
      }
    }

    visibleTasks.sort((first, second) {
      final firstIsRunning = first.id == _activeTaskId;
      final secondIsRunning = second.id == _activeTaskId;
      if (firstIsRunning != secondIsRunning) {
        return firstIsRunning ? -1 : 1;
      }

      final firstSortTime = latestEndedAtByTaskId[first.id] ?? first.updatedAt;
      final secondSortTime =
          latestEndedAtByTaskId[second.id] ?? second.updatedAt;
      final sortTimeComparison = secondSortTime.compareTo(firstSortTime);
      if (sortTimeComparison != 0) {
        return sortTimeComparison;
      }

      return originalIndexes[first.id]!.compareTo(originalIndexes[second.id]!);
    });

    return visibleTasks;
  }

  Task? get selectedTask {
    final taskId = selectedTaskId;
    if (taskId == null) {
      return null;
    }

    return _taskById(taskId);
  }

  List<Task> get selectedTasks {
    return _selectedTaskIds
        .map(_taskById)
        .whereType<Task>()
        .toList(growable: false);
  }

  Task? get activeTask {
    if (_activeTaskId == null) {
      return null;
    }

    return _taskById(_activeTaskId!);
  }

  Duration get activeElapsed {
    final startedAt = _activeStartedAt;
    if (startedAt == null) {
      return Duration.zero;
    }

    return DateTime.now().difference(startedAt);
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final store = await _repository.load();
      _tasks = store.tasks;
      _timeEntries = store.timeEntries;
      _restoreOpenTimer();
      _selectFirstVisibleTask();
    } on Object catch (exception) {
      _error = exception.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectTask(String taskId, {bool additive = false}) {
    if (!additive) {
      _selectedTaskIds
        ..clear()
        ..add(taskId);
    } else if (_selectedTaskIds.contains(taskId)) {
      _selectedTaskIds.remove(taskId);
    } else {
      _selectedTaskIds.add(taskId);
    }
    notifyListeners();
  }

  void setFilter(TaskListFilter filter) {
    _filter = filter;
    _retainVisibleSelection();
    notifyListeners();
  }

  void applyStore(TaskStore store) {
    _tasks = store.tasks;
    _timeEntries = store.timeEntries;
    _retainVisibleSelection();
    _restoreOpenTimer();
    notifyListeners();
  }

  Future<void> addTask({
    required String title,
    required String description,
  }) async {
    final now = DateTime.now().toUtc();
    final task = Task(
      id: createTaskId(),
      title: title.trim(),
      description: description.trim(),
      status: TaskStatus.newTask,
      createdAt: now,
      updatedAt: now,
    );

    _tasks = [task, ..._tasks];
    _filter = TaskListFilter.work;
    _selectedTaskIds
      ..clear()
      ..add(task.id);
    await _save();
    notifyListeners();
  }

  Future<void> updateTask(Task updatedTask) async {
    _tasks = _tasks
        .map((task) => task.id == updatedTask.id ? updatedTask : task)
        .toList();
    await _save();
    notifyListeners();
  }

  Future<void> changeTaskStatus(String taskId, TaskStatus status) async {
    await changeTasksStatus([taskId], status);
  }

  Future<void> changeTasksStatus(
    Iterable<String> taskIds,
    TaskStatus status,
  ) async {
    final changedTaskIds = taskIds.toSet();
    if (changedTaskIds.isEmpty) {
      return;
    }

    final now = DateTime.now().toUtc();
    _tasks = _tasks.map((task) {
      if (!changedTaskIds.contains(task.id)) {
        return task;
      }

      return task.copyWith(status: status, updatedAt: now);
    }).toList();
    await _save();
    if (selectedTasks.any((task) => !_matchesFilter(task))) {
      _filter = _filterForStatus(status);
    }
    notifyListeners();
  }

  Future<void> completeTask(String taskId) async {
    await completeTasks([taskId]);
  }

  Future<void> completeTasks(Iterable<String> taskIds) async {
    final completedTaskIds = taskIds.toSet();
    if (_activeTaskId != null && completedTaskIds.contains(_activeTaskId)) {
      await stopTimer();
    }

    await changeTasksStatus(completedTaskIds, TaskStatus.completed);
  }

  Future<void> archiveTask(String taskId) async {
    await archiveTasks([taskId]);
  }

  Future<void> archiveTasks(Iterable<String> taskIds) async {
    final archivedTaskIds = taskIds.toSet();
    if (archivedTaskIds.isEmpty) {
      return;
    }

    if (_activeTaskId != null && archivedTaskIds.contains(_activeTaskId)) {
      await stopTimer();
    }

    final now = DateTime.now().toUtc();
    _tasks = _tasks.map((task) {
      if (!archivedTaskIds.contains(task.id)) {
        return task;
      }

      return task.copyWith(isArchived: true, archivedAt: now, updatedAt: now);
    }).toList();
    await _save();
    notifyListeners();
  }

  Future<void> unarchiveTask(String taskId) async {
    await unarchiveTasks([taskId]);
  }

  Future<void> unarchiveTasks(Iterable<String> taskIds) async {
    final unarchivedTaskIds = taskIds.toSet();
    if (unarchivedTaskIds.isEmpty) {
      return;
    }

    final now = DateTime.now().toUtc();
    _tasks = _tasks.map((task) {
      if (!unarchivedTaskIds.contains(task.id)) {
        return task;
      }

      return task.copyWith(
        status: _unarchiveStatusForTask(task.id),
        isArchived: false,
        clearArchivedAt: true,
        updatedAt: now,
      );
    }).toList();
    await _save();
    notifyListeners();
  }

  Future<void> deleteTask(String taskId) async {
    if (_activeTaskId == taskId) {
      await stopTimer();
    }

    _tasks = _tasks.where((task) => task.id != taskId).toList();
    _timeEntries = _timeEntries
        .where((entry) => entry.taskId != taskId)
        .toList();
    _selectFirstVisibleTask();
    await _save();
    notifyListeners();
  }

  Future<void> startTimer(String taskId) async {
    if (_activeTaskId == taskId) {
      return;
    }

    if (hasActiveTimer) {
      await stopTimer();
    }

    final startedAt = DateTime.now().toUtc();
    final entryId = createTaskId();
    _activeTaskId = taskId;
    _activeEntryId = entryId;
    _activeStartedAt = startedAt;
    _timeEntries = [
      ..._timeEntries,
      TimeEntry(id: entryId, taskId: taskId, startedAt: startedAt),
    ];
    final task = _taskById(taskId);
    if (task?.status == TaskStatus.newTask) {
      _tasks = _tasks
          .map(
            (task) => task.id == taskId
                ? task.copyWith(
                    status: TaskStatus.active,
                    updatedAt: _activeStartedAt,
                  )
                : task,
          )
          .toList();
    }
    await _save();
    _startTicker();
    notifyListeners();
  }

  Future<void> stopTimer() async {
    final taskId = _activeTaskId;
    final startedAt = _activeStartedAt;
    final entryId = _activeEntryId;
    if (taskId == null || startedAt == null || entryId == null) {
      return;
    }

    final endedAt = DateTime.now().toUtc();
    _timeEntries = _timeEntries.map((entry) {
      if (entry.id != entryId) {
        return entry;
      }

      return entry.copyWith(endedAt: endedAt);
    }).toList();
    _activeTaskId = null;
    _activeEntryId = null;
    _activeStartedAt = null;
    _ticker?.cancel();
    await _save();
    notifyListeners();
  }

  Future<void> addTimeEntry({
    required String taskId,
    required DateTime startedAt,
    required DateTime endedAt,
    String note = '',
  }) async {
    _timeEntries = [
      ..._timeEntries,
      TimeEntry(
        id: createTaskId(),
        taskId: taskId,
        startedAt: startedAt.toUtc(),
        endedAt: endedAt.toUtc(),
        note: note.trim(),
      ),
    ];
    await _save();
    notifyListeners();
  }

  Future<void> updateTimeEntry(TimeEntry updatedEntry) async {
    _timeEntries = _timeEntries
        .map((entry) => entry.id == updatedEntry.id ? updatedEntry : entry)
        .toList();
    if (updatedEntry.id == _activeEntryId) {
      _activeStartedAt = updatedEntry.startedAt;
      if (!updatedEntry.isRunning) {
        _activeTaskId = null;
        _activeEntryId = null;
        _activeStartedAt = null;
        _ticker?.cancel();
      }
    }
    await _save();
    notifyListeners();
  }

  Future<void> deleteTimeEntry(String entryId) async {
    _timeEntries = _timeEntries.where((entry) => entry.id != entryId).toList();
    if (_activeEntryId == entryId) {
      _activeTaskId = null;
      _activeEntryId = null;
      _activeStartedAt = null;
      _ticker?.cancel();
    }
    await _save();
    notifyListeners();
  }

  Duration totalForTask(String taskId) {
    final saved = _timeEntries
        .where((entry) => entry.taskId == taskId)
        .fold(Duration.zero, (total, entry) => total + entry.duration);

    return saved;
  }

  Duration totalForTasks(Iterable<String> taskIds) {
    final selectedIds = taskIds.toSet();
    return _timeEntries
        .where((entry) => selectedIds.contains(entry.taskId))
        .fold(Duration.zero, (total, entry) => total + entry.duration);
  }

  List<TimeEntry> entriesForTask(String taskId) {
    return entriesForTasks([taskId]);
  }

  List<TimeEntry> entriesForTasks(Iterable<String> taskIds) {
    final selectedIds = taskIds.toSet();
    final entries = _timeEntries
        .where((entry) => selectedIds.contains(entry.taskId))
        .toList();
    entries.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return entries;
  }

  Future<void> _save() async {
    await _repository.save(TaskStore(tasks: _tasks, timeEntries: _timeEntries));
  }

  Task? _taskById(String taskId) {
    for (final task in _tasks) {
      if (task.id == taskId) {
        return task;
      }
    }

    return null;
  }

  TaskStatus _unarchiveStatusForTask(String taskId) {
    final hasTimeEntries = _timeEntries.any((entry) => entry.taskId == taskId);
    return hasTimeEntries ? TaskStatus.active : TaskStatus.newTask;
  }

  bool _matchesFilter(Task task) {
    return switch (_filter) {
      TaskListFilter.work =>
        !task.isArchived &&
            (task.status == TaskStatus.newTask ||
                task.status == TaskStatus.active),
      TaskListFilter.completed =>
        !task.isArchived && task.status == TaskStatus.completed,
      TaskListFilter.deferred =>
        !task.isArchived && task.status == TaskStatus.deferred,
      TaskListFilter.canceled =>
        !task.isArchived && task.status == TaskStatus.canceled,
      TaskListFilter.archive => task.isArchived,
    };
  }

  void _selectFirstVisibleTask() {
    final visibleTasks = filteredTasks;
    _selectedTaskIds.clear();
    if (visibleTasks.isNotEmpty) {
      _selectedTaskIds.add(visibleTasks.first.id);
    }
  }

  void _retainVisibleSelection() {
    _selectedTaskIds.removeWhere((taskId) {
      final task = _taskById(taskId);
      return task == null || !_matchesFilter(task);
    });
    if (_selectedTaskIds.isEmpty) {
      _selectFirstVisibleTask();
    }
  }

  void _restoreOpenTimer() {
    for (final entry in _timeEntries) {
      if (entry.isRunning && _taskById(entry.taskId) != null) {
        _activeTaskId = entry.taskId;
        _activeEntryId = entry.id;
        _activeStartedAt = entry.startedAt;
        _startTicker();
        return;
      }
    }

    _activeTaskId = null;
    _activeEntryId = null;
    _activeStartedAt = null;
    _ticker?.cancel();
  }

  TaskListFilter _filterForStatus(TaskStatus status) {
    return switch (status) {
      TaskStatus.newTask || TaskStatus.active => TaskListFilter.work,
      TaskStatus.completed => TaskListFilter.completed,
      TaskStatus.deferred => TaskListFilter.deferred,
      TaskStatus.canceled => TaskListFilter.canceled,
    };
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
