import '../models/task.dart';
import '../models/time_entry.dart';
import 'task_repository.dart';
import 'task_rpc_client.dart';
import 'task_store.dart';

class WebSocketTaskRepository implements TaskRepository {
  WebSocketTaskRepository({
    required this.client,
    this.clientId = 'tasks-tracker-flutter',
  });

  final TaskRpcClient client;
  final String clientId;
  void Function(TaskStore store)? onStoreChanged;
  TaskStore _lastStore = const TaskStore(tasks: [], timeEntries: []);
  bool _isConnected = false;

  @override
  Future<TaskStore> load() async {
    await _connect();
    final result = await client.sendRequest('tasks.list', {
      'includeArchived': true,
    });
    final timeEntryResult = await client.sendRequest('timeEntries.list', {});
    final tasks = _readTaskList(result);
    final timeEntries = _readTimeEntryList(timeEntryResult);
    _lastStore = TaskStore(tasks: tasks, timeEntries: timeEntries);
    return _lastStore;
  }

  @override
  Future<void> save(TaskStore store) async {
    await _connect();

    final oldTasks = {for (final task in _lastStore.tasks) task.id: task};
    final newTaskIds = store.tasks.map((task) => task.id).toSet();
    for (final task in store.tasks) {
      final oldTask = oldTasks[task.id];
      if (oldTask == null) {
        await client.sendRequest('tasks.create', _taskCreateParams(task));
      } else if (_becameArchived(oldTask, task)) {
        await client.sendRequest('tasks.archive', {'id': task.id});
      } else if (_taskChanged(oldTask, task)) {
        await client.sendRequest('tasks.update', _taskUpdateParams(task));
      }
    }

    for (final oldTask in _lastStore.tasks) {
      if (!newTaskIds.contains(oldTask.id)) {
        await client.sendRequest('tasks.delete', {'id': oldTask.id});
      }
    }

    final oldEntries = {
      for (final entry in _lastStore.timeEntries) entry.id: entry,
    };
    final newEntryIds = store.timeEntries.map((entry) => entry.id).toSet();
    final deletedTaskIds = oldTasks.keys
        .where((taskId) => !newTaskIds.contains(taskId))
        .toSet();

    for (final entry in store.timeEntries) {
      final oldEntry = oldEntries[entry.id];
      if (oldEntry == null) {
        await client.sendRequest(
          'timeEntries.create',
          _timeEntryCreateParams(entry),
        );
      } else if (_timeEntryChanged(oldEntry, entry)) {
        await client.sendRequest(
          'timeEntries.update',
          _timeEntryUpdateParams(entry),
        );
      }
    }

    for (final oldEntry in _lastStore.timeEntries) {
      if (!newEntryIds.contains(oldEntry.id) &&
          !deletedTaskIds.contains(oldEntry.taskId)) {
        await client.sendRequest('timeEntries.delete', {'id': oldEntry.id});
      }
    }

    _lastStore = store;
  }

  Future<void> close() async {
    await client.close();
  }

  Future<void> _connect() async {
    if (_isConnected) {
      return;
    }

    await client.connect();
    client.registerMethod('tasks.changed', _handleTaskChanged);
    client.registerMethod('timeEntries.changed', _handleTimeEntryChanged);
    client.registerMethod('sync.applyChanges', _handleSyncApplyChanges);
    await client.sendRequest('auth.hello', {
      'clientId': clientId,
      'protocolVersion': 1,
    });
    _isConnected = true;
  }

  Object _handleTaskChanged(Object? params) {
    final event = _readMap(params, 'tasks.changed params');
    _applyTaskChangedEvent(event);
    return {};
  }

  Object _handleSyncApplyChanges(Object? params) {
    final syncParams = _readMap(params, 'sync.applyChanges params');
    final tasks = syncParams['tasks'];
    if (tasks is! List) {
      throw FormatException('sync.applyChanges params.tasks must be a list');
    }

    for (final taskEvent in tasks) {
      _applyTaskChangedEvent(
        _readMap(taskEvent, 'sync.applyChanges params.tasks item'),
      );
    }
    return {};
  }

  void _applyTaskChangedEvent(Map<dynamic, dynamic> event) {
    final task = _taskFromServer(_readMap(event['task'], 'tasks.changed task'));
    final operation = event['operation'] as String? ?? '';

    final tasks = switch (operation) {
      'created' || 'updated' || 'archived' => _upsertTask(task),
      'deleted' => _removeTask(task.id),
      _ => throw FormatException('Unknown tasks.changed operation $operation'),
    };

    final timeEntries = operation == 'deleted'
        ? _lastStore.timeEntries
              .where((entry) => entry.taskId != task.id)
              .toList()
        : _lastStore.timeEntries;
    _replaceStore(TaskStore(tasks: tasks, timeEntries: timeEntries));
  }

  Object _handleTimeEntryChanged(Object? params) {
    final event = _readMap(params, 'timeEntries.changed params');
    final timeEntry = _timeEntryFromServer(
      _readMap(event['timeEntry'], 'timeEntries.changed timeEntry'),
    );
    final operation = event['operation'] as String? ?? '';

    final timeEntries = switch (operation) {
      'created' || 'updated' => _upsertTimeEntry(timeEntry),
      'deleted' => _removeTimeEntry(timeEntry.id),
      _ => throw FormatException(
        'Unknown timeEntries.changed operation $operation',
      ),
    };

    _replaceStore(TaskStore(tasks: _lastStore.tasks, timeEntries: timeEntries));
    return {};
  }

  void _replaceStore(TaskStore store) {
    _lastStore = store;
    onStoreChanged?.call(store);
  }

  List<Task> _upsertTask(Task changedTask) {
    var found = false;
    final tasks = _lastStore.tasks.map((task) {
      if (task.id != changedTask.id) {
        return task;
      }

      found = true;
      return changedTask;
    }).toList();

    return found ? tasks : [changedTask, ...tasks];
  }

  List<Task> _removeTask(String taskId) {
    return _lastStore.tasks.where((task) => task.id != taskId).toList();
  }

  List<TimeEntry> _upsertTimeEntry(TimeEntry changedEntry) {
    var found = false;
    final entries = _lastStore.timeEntries.map((entry) {
      if (entry.id != changedEntry.id) {
        return entry;
      }

      found = true;
      return changedEntry;
    }).toList();

    return found ? entries : [...entries, changedEntry];
  }

  List<TimeEntry> _removeTimeEntry(String entryId) {
    return _lastStore.timeEntries
        .where((entry) => entry.id != entryId)
        .toList();
  }

  List<Task> _readTaskList(Object? result) {
    final resultMap = _readMap(result, 'tasks.list result');
    final tasks = resultMap['tasks'];
    if (tasks is! List) {
      throw FormatException('tasks.list result.tasks must be a list');
    }

    return tasks
        .map((item) => _taskFromServer(item as Map<dynamic, dynamic>))
        .toList();
  }

  List<TimeEntry> _readTimeEntryList(Object? result) {
    final resultMap = _readMap(result, 'timeEntries.list result');
    final timeEntries = resultMap['timeEntries'];
    if (timeEntries is! List) {
      throw FormatException(
        'timeEntries.list result.timeEntries must be a list',
      );
    }

    return timeEntries
        .map((item) => _timeEntryFromServer(item as Map<dynamic, dynamic>))
        .toList();
  }

  Map<dynamic, dynamic> _readMap(Object? value, String label) {
    if (value is! Map) {
      throw FormatException('$label must be an object');
    }

    return value;
  }

  Task _taskFromServer(Map<dynamic, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      status: _statusFromId(json['statusId'] as int),
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      isArchived: json['isArchived'] as bool? ?? false,
      archivedAt: json['archivedAt'] == null
          ? null
          : DateTime.parse(json['archivedAt'] as String).toUtc(),
    );
  }

  Map<String, Object?> _taskCreateParams(Task task) {
    return {
      'id': task.id,
      'createdAt': task.createdAt.toUtc().toIso8601String(),
      'updatedAt': task.updatedAt.toUtc().toIso8601String(),
      'title': task.title,
      'description': task.description,
      'statusId': _statusId(task.status),
      'isArchived': task.isArchived,
      'archivedAt': task.archivedAt?.toUtc().toIso8601String(),
    };
  }

  Map<String, Object?> _taskUpdateParams(Task task) {
    return {
      'id': task.id,
      'title': task.title,
      'description': task.description,
      'statusId': _statusId(task.status),
    };
  }

  TimeEntry _timeEntryFromServer(Map<dynamic, dynamic> json) {
    return TimeEntry(
      id: json['id'] as String,
      taskId: json['taskId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String).toUtc(),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.parse(json['endedAt'] as String).toUtc(),
      note: json['note'] as String? ?? '',
    );
  }

  Map<String, Object?> _timeEntryCreateParams(TimeEntry entry) {
    return {
      'id': entry.id,
      'taskId': entry.taskId,
      'startedAt': entry.startedAt.toUtc().toIso8601String(),
      'endedAt': entry.endedAt?.toUtc().toIso8601String(),
      'note': entry.note,
    };
  }

  Map<String, Object?> _timeEntryUpdateParams(TimeEntry entry) {
    return {
      'id': entry.id,
      'startedAt': entry.startedAt.toUtc().toIso8601String(),
      'endedAt': entry.endedAt?.toUtc().toIso8601String(),
      'note': entry.note,
    };
  }

  bool _becameArchived(Task oldTask, Task task) {
    return !oldTask.isArchived && task.isArchived;
  }

  bool _taskChanged(Task oldTask, Task task) {
    return oldTask.title != task.title ||
        oldTask.description != task.description ||
        oldTask.status != task.status ||
        oldTask.isArchived != task.isArchived;
  }

  bool _timeEntryChanged(TimeEntry oldEntry, TimeEntry entry) {
    return oldEntry.startedAt != entry.startedAt ||
        oldEntry.endedAt != entry.endedAt ||
        oldEntry.note != entry.note;
  }

  int _statusId(TaskStatus status) {
    return switch (status) {
      TaskStatus.newTask => 1,
      TaskStatus.active => 2,
      TaskStatus.completed => 3,
      TaskStatus.deferred => 4,
      TaskStatus.canceled => 5,
    };
  }

  TaskStatus _statusFromId(int id) {
    return switch (id) {
      1 => TaskStatus.newTask,
      2 => TaskStatus.active,
      3 => TaskStatus.completed,
      4 => TaskStatus.deferred,
      5 => TaskStatus.canceled,
      _ => TaskStatus.active,
    };
  }
}
