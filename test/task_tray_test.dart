import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_tracker_client/data/task_repository.dart';
import 'package:tasks_tracker_client/data/task_store.dart';
import 'package:tasks_tracker_client/models/task.dart';
import 'package:tasks_tracker_client/state/task_controller.dart';
import 'package:tasks_tracker_client/tray/task_tray_desktop.dart';

void main() {
  test('uses platform-specific tray icon formats', () {
    expect(
      taskTrayIconPath(isActive: false, isWindows: false),
      'assets/tray_icon.png',
    );
    expect(
      taskTrayIconPath(isActive: true, isWindows: false),
      'assets/tray_icon_active.png',
    );
    expect(
      taskTrayIconPath(isActive: false, isWindows: true),
      'windows/runner/resources/tray_icon.ico',
    );
    expect(
      taskTrayIconPath(isActive: true, isWindows: true),
      'windows/runner/resources/tray_icon_active.ico',
    );
  });

  test(
    'keeps tray icon shown and marks it active while a timer runs',
    () async {
      final host = _FakeTaskTrayHost();
      final controller = TaskController(
        _MemoryTaskRepository(
          TaskStore(
            tasks: [
              Task(
                id: 'task-1',
                title: 'Tracked task',
                description: '',
                status: TaskStatus.active,
                createdAt: DateTime.utc(2026, 7, 6, 8),
                updatedAt: DateTime.utc(2026, 7, 6, 8),
              ),
            ],
            timeEntries: const [],
          ),
        ),
      );
      final tray = TaskTray(host: host);

      await tray.idle;
      expect(host.icons, ['assets/tray_icon.png']);
      expect(host.menu.map((item) => item.label), ['Exit']);

      tray.attach(controller);
      await controller.load();
      await tray.idle;

      expect(host.icons, ['assets/tray_icon.png']);

      await controller.startTimer('task-1');
      await tray.idle;

      expect(host.icons.last, 'assets/tray_icon_active.png');

      await controller.stopTimer();
      await tray.idle;

      expect(host.icons.last, 'assets/tray_icon.png');
      expect(host.destroyCount, 0);

      await tray.dispose();
      expect(host.destroyCount, 1);
      controller.dispose();
    },
  );

  test('left click tray icon toggles app window', () async {
    var didToggle = false;
    final host = _FakeTaskTrayHost();
    final tray = TaskTray(
      host: host,
      toggleAppWindow: () async {
        didToggle = true;
      },
    );

    host.click();

    expect(didToggle, isTrue);

    await tray.dispose();
  });

  test('right click tray icon opens context menu', () async {
    final host = _FakeTaskTrayHost();
    final tray = TaskTray(host: host);

    host.rightClick();

    expect(host.openContextMenuCount, 1);

    await tray.dispose();
  });

  test('exit tray menu item invokes exit callback', () async {
    var didExit = false;
    final host = _FakeTaskTrayHost();
    final tray = TaskTray(
      host: host,
      exitApplication: () {
        didExit = true;
      },
    );

    host.choose('exit');

    expect(didExit, isTrue);

    await tray.dispose();
  });
}

class _FakeTaskTrayHost implements TaskTrayHost {
  final List<String> icons = [];
  List<TaskTrayMenuItem> menu = [];
  int destroyCount = 0;
  int openContextMenuCount = 0;
  VoidCallback? _onClick;
  VoidCallback? _onRightClick;
  void Function(String key)? _onMenuItemClick;

  @override
  void setHandlers({
    required VoidCallback onClick,
    required VoidCallback onRightClick,
    required void Function(String key) onMenuItemClick,
  }) {
    _onClick = onClick;
    _onRightClick = onRightClick;
    _onMenuItemClick = onMenuItemClick;
  }

  void click() {
    _onClick?.call();
  }

  void rightClick() {
    _onRightClick?.call();
  }

  void choose(String key) {
    _onMenuItemClick?.call(key);
  }

  @override
  Future<void> destroy() async {
    destroyCount += 1;
  }

  @override
  Future<void> openContextMenu() async {
    openContextMenuCount += 1;
  }

  @override
  Future<void> setContextMenu(List<TaskTrayMenuItem> menu) async {
    this.menu = menu;
  }

  @override
  Future<void> setIcon(String iconPath) async {
    icons.add(iconPath);
  }

  @override
  Future<void> setToolTip(String toolTip) async {}
}

class _MemoryTaskRepository implements TaskRepository {
  _MemoryTaskRepository(this.store);

  TaskStore store;

  @override
  Future<TaskStore> load() async {
    return store;
  }

  @override
  Future<void> save(TaskStore store) async {
    this.store = store;
  }
}
