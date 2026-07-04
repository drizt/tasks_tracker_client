import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_tracker/data/task_rpc_client.dart';
import 'package:tasks_tracker/data/task_store.dart';
import 'package:tasks_tracker/data/web_socket_task_repository.dart';
import 'package:tasks_tracker/models/task.dart';
import 'package:tasks_tracker/models/time_entry.dart';

void main() {
  test('loads tasks through JSON-RPC', () async {
    final client = _FakeTaskRpcClient();
    final repository = WebSocketTaskRepository(client: client);

    final store = await repository.load();

    expect(client.connected, isTrue);
    expect(client.requests.first.method, 'auth.hello');
    expect(client.requests.first.parameters, {
      'clientId': 'tasks-tracker-flutter',
      'protocolVersion': 1,
    });
    expect(client.requests[1].method, 'tasks.list');
    expect(client.requests[1].parameters, {'includeArchived': true});
    expect(client.requests.last.method, 'timeEntries.list');
    expect(client.requests.last.parameters, {});
    expect(store.tasks.single.id, 'task-1');
    expect(store.tasks.single.status, TaskStatus.active);
    expect(store.timeEntries.single.id, 'entry-1');
  });

  test('creates new tasks with client-supplied ids', () async {
    final client = _FakeTaskRpcClient();
    final repository = WebSocketTaskRepository(client: client);
    await repository.load();

    await repository.save(
      TaskStore(
        tasks: [
          ...repositoryLastTasks,
          Task(
            id: 'client-ulid-1',
            title: 'Write RPC client',
            description: '',
            status: TaskStatus.newTask,
            createdAt: DateTime.utc(2026, 6, 30),
            updatedAt: DateTime.utc(2026, 6, 30),
          ),
        ],
        timeEntries: repositoryLastTimeEntries,
      ),
    );

    expect(client.requests.last.method, 'tasks.create');
    expect(client.requests.last.parameters, {
      'id': 'client-ulid-1',
      'createdAt': '2026-06-30T00:00:00.000Z',
      'updatedAt': '2026-06-30T00:00:00.000Z',
      'title': 'Write RPC client',
      'description': '',
      'statusId': 1,
      'isArchived': false,
      'archivedAt': null,
    });
  });

  test('updates changed tasks and archives newly archived tasks', () async {
    final client = _FakeTaskRpcClient();
    final repository = WebSocketTaskRepository(client: client);
    final store = await repository.load();

    await repository.save(
      TaskStore(
        tasks: [
          store.tasks.single.copyWith(title: 'Updated title', isArchived: true),
        ],
        timeEntries: store.timeEntries,
      ),
    );

    expect(client.requests.last.method, 'tasks.archive');
    expect(client.requests.last.parameters, {'id': 'task-1'});
  });

  test('deletes removed tasks through JSON-RPC', () async {
    final client = _FakeTaskRpcClient();
    final repository = WebSocketTaskRepository(client: client);
    final store = await repository.load();

    await repository.save(
      TaskStore(tasks: const [], timeEntries: store.timeEntries),
    );

    expect(client.requests.last.method, 'tasks.delete');
    expect(client.requests.last.parameters, {'id': 'task-1'});
  });

  test('creates new time entries through JSON-RPC', () async {
    final client = _FakeTaskRpcClient();
    final repository = WebSocketTaskRepository(client: client);
    final store = await repository.load();

    await repository.save(
      TaskStore(
        tasks: store.tasks,
        timeEntries: [
          ...store.timeEntries,
          TimeEntry(
            id: 'entry-client-ulid',
            taskId: 'task-1',
            startedAt: DateTime.utc(2026, 6, 30, 1),
            endedAt: DateTime.utc(2026, 6, 30, 1, 30),
            note: 'Manual work',
          ),
        ],
      ),
    );

    expect(client.requests.last.method, 'timeEntries.create');
    expect(client.requests.last.parameters, {
      'id': 'entry-client-ulid',
      'taskId': 'task-1',
      'startedAt': '2026-06-30T01:00:00.000Z',
      'endedAt': '2026-06-30T01:30:00.000Z',
      'note': 'Manual work',
    });
  });

  test('applies echoed own task events without duplicating tasks', () async {
    final client = _FakeTaskRpcClient();
    final changes = <TaskStore>[];
    final repository = WebSocketTaskRepository(client: client)
      ..onStoreChanged = changes.add;
    await repository.load();

    client.callRegisteredMethod('tasks.changed', {
      'task': {
        'id': 'task-1',
        'title': 'Loaded task',
        'description': '',
        'statusId': 2,
        'createdAt': '2026-06-30T00:00:00.000Z',
        'updatedAt': '2026-06-30T00:00:00.000Z',
        'isArchived': false,
        'archivedAt': null,
      },
      'operation': 'updated',
    });

    expect(changes.single.tasks, hasLength(1));
    expect(changes.single.tasks.single.id, 'task-1');
  });

  test('applies task events from other clients', () async {
    final client = _FakeTaskRpcClient();
    final changes = <TaskStore>[];
    final repository = WebSocketTaskRepository(client: client)
      ..onStoreChanged = changes.add;
    await repository.load();

    client.callRegisteredMethod('tasks.changed', {
      'task': {
        'id': 'task-2',
        'title': 'Remote task',
        'description': '',
        'statusId': 1,
        'createdAt': '2026-06-30T02:00:00.000Z',
        'updatedAt': '2026-06-30T02:00:00.000Z',
        'isArchived': false,
        'archivedAt': null,
      },
      'operation': 'created',
    });

    expect(changes.single.tasks.map((task) => task.id), ['task-2', 'task-1']);
  });

  test('applies sync task changes and returns an object result', () async {
    final client = _FakeTaskRpcClient();
    final changes = <TaskStore>[];
    final repository = WebSocketTaskRepository(client: client)
      ..onStoreChanged = changes.add;
    await repository.load();

    final result = client.callRegisteredMethod('sync.applyChanges', {
      'tasks': [
        {
          'task': {
            'id': 'task-2',
            'title': 'Synced task',
            'description': '',
            'statusId': 1,
            'createdAt': '2026-06-30T02:00:00.000Z',
            'updatedAt': '2026-06-30T02:00:00.000Z',
            'isArchived': false,
            'archivedAt': null,
          },
          'operation': 'created',
        },
      ],
    });

    expect(result, {});
    expect(changes.single.tasks.first.id, 'task-2');
  });

  test('applies time entry events from other clients', () async {
    final client = _FakeTaskRpcClient();
    final changes = <TaskStore>[];
    final repository = WebSocketTaskRepository(client: client)
      ..onStoreChanged = changes.add;
    await repository.load();

    client.callRegisteredMethod('timeEntries.changed', {
      'timeEntry': {
        'id': 'entry-2',
        'taskId': 'task-1',
        'startedAt': '2026-06-30T02:00:00.000Z',
        'endedAt': null,
        'note': '',
      },
      'operation': 'created',
    });

    expect(changes.single.timeEntries.map((entry) => entry.id), [
      'entry-1',
      'entry-2',
    ]);
  });
}

List<Task> get repositoryLastTasks {
  return [
    Task(
      id: 'task-1',
      title: 'Loaded task',
      description: '',
      status: TaskStatus.active,
      createdAt: DateTime.utc(2026, 6, 30),
      updatedAt: DateTime.utc(2026, 6, 30),
    ),
  ];
}

List<TimeEntry> get repositoryLastTimeEntries {
  return [
    TimeEntry(
      id: 'entry-1',
      taskId: 'task-1',
      startedAt: DateTime.utc(2026, 6, 30),
    ),
  ];
}

class _FakeTaskRpcClient implements TaskRpcClient {
  bool connected = false;
  final requests = <({String method, Object? parameters})>[];
  final registeredMethods = <String, TaskRpcMethodCallback>{};

  @override
  Future<void> connect() async {
    connected = true;
  }

  @override
  void registerMethod(String name, TaskRpcMethodCallback callback) {
    registeredMethods[name] = callback;
  }

  Object? callRegisteredMethod(String name, Object? parameters) {
    return registeredMethods[name]?.call(parameters);
  }

  @override
  Future<Object?> sendRequest(String method, [Object? parameters]) async {
    requests.add((method: method, parameters: parameters));

    return switch (method) {
      'auth.hello' => {'serverName': 'tasks-tracker', 'protocolVersion': 1},
      'tasks.list' => {
        'tasks': [
          {
            'id': 'task-1',
            'title': 'Loaded task',
            'description': '',
            'statusId': 2,
            'createdAt': '2026-06-30T00:00:00.000Z',
            'updatedAt': '2026-06-30T00:00:00.000Z',
            'isArchived': false,
            'archivedAt': null,
          },
        ],
      },
      'timeEntries.list' => {
        'timeEntries': [
          {
            'id': 'entry-1',
            'taskId': 'task-1',
            'startedAt': '2026-06-30T00:00:00.000Z',
            'endedAt': null,
            'note': '',
          },
        ],
      },
      'tasks.create' => parameters,
      'tasks.update' => parameters,
      'tasks.archive' => parameters,
      'tasks.delete' => parameters,
      'timeEntries.create' => parameters,
      'timeEntries.update' => parameters,
      'timeEntries.delete' => parameters,
      _ => null,
    };
  }

  @override
  Future<void> close() async {
    connected = false;
  }
}
