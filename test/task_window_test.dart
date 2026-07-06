import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_tracker_client/window/task_window_desktop.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  test('shows and focuses app window', () async {
    final host = _FakeTaskWindowHost();
    final taskWindow = TaskWindow(host: host);

    await taskWindow.show();

    expect(host.events, ['addListener', 'show', 'focus']);

    await taskWindow.dispose();
  });

  test('toggle hides a visible app window', () async {
    final host = _FakeTaskWindowHost(state: TaskWindowState.shown);
    final taskWindow = TaskWindow(host: host);

    await taskWindow.toggle();

    expect(host.events, ['addListener', 'getState:shown', 'hide']);

    await taskWindow.dispose();
  });

  test('toggle shows and focuses a hidden app window', () async {
    final host = _FakeTaskWindowHost(state: TaskWindowState.hidden);
    final taskWindow = TaskWindow(host: host);

    await taskWindow.toggle();

    expect(host.events, ['addListener', 'getState:hidden', 'show', 'focus']);

    await taskWindow.dispose();
  });

  test('toggle restores and focuses a minimized app window', () async {
    final host = _FakeTaskWindowHost(state: TaskWindowState.minimized);
    final taskWindow = TaskWindow(host: host);

    await taskWindow.toggle();

    expect(host.events, ['addListener', 'getState:minimized', 'show', 'focus']);

    await taskWindow.dispose();
  });

  test('title bar close hides app window instead of closing it', () async {
    final host = _FakeTaskWindowHost();
    final taskWindow = TaskWindow(host: host);

    taskWindow.onWindowClose();
    await taskWindow.idle;

    expect(host.events, ['addListener', 'hide']);

    await taskWindow.dispose();
  });
}

class _FakeTaskWindowHost implements TaskWindowHost {
  _FakeTaskWindowHost({this.state = TaskWindowState.shown});

  final List<String> events = [];
  final TaskWindowState state;

  @override
  void addListener(WindowListener listener) {
    events.add('addListener');
  }

  @override
  void removeListener(WindowListener listener) {
    events.add('removeListener');
  }

  @override
  Future<void> focus() async {
    events.add('focus');
  }

  @override
  Future<void> hide() async {
    events.add('hide');
  }

  @override
  Future<TaskWindowState> getState() async {
    events.add('getState:${state.name}');
    return state;
  }

  @override
  Future<void> setPreventClose(bool isPreventClose) async {
    events.add('setPreventClose:$isPreventClose');
  }

  @override
  Future<void> show() async {
    events.add('show');
  }
}
