import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nativeapi/nativeapi.dart' as native;
import 'package:tasks_tracker_client/window/task_window_desktop.dart';

void main() {
  test('shows and focuses app window', () {
    final host = _FakeTaskWindowHost();
    final taskWindow = TaskWindow(host: host);

    taskWindow.show();

    expect(host.events, ['setCloseHandler', 'show', 'focus']);

    taskWindow.dispose();
  });

  test('toggle hides a visible app window', () {
    final host = _FakeTaskWindowHost(state: TaskWindowState.shown);
    final taskWindow = TaskWindow(host: host);

    taskWindow.toggle();

    expect(host.events, ['setCloseHandler', 'getState:shown', 'hide']);

    taskWindow.dispose();
  });

  test('toggle shows and focuses a hidden app window', () {
    final host = _FakeTaskWindowHost(state: TaskWindowState.hidden);
    final taskWindow = TaskWindow(host: host);

    taskWindow.toggle();

    expect(host.events, [
      'setCloseHandler',
      'getState:hidden',
      'show',
      'focus',
    ]);

    taskWindow.dispose();
  });

  test('toggle restores and focuses a minimized app window', () {
    final host = _FakeTaskWindowHost(state: TaskWindowState.minimized);
    final taskWindow = TaskWindow(host: host);

    taskWindow.toggle();

    expect(host.events, [
      'setCloseHandler',
      'getState:minimized',
      'show',
      'focus',
    ]);

    taskWindow.dispose();
  });

  test('title bar close hides app window instead of closing it', () {
    final host = _FakeTaskWindowHost();
    final taskWindow = TaskWindow(host: host);

    host.onClose!();

    expect(host.events, ['setCloseHandler', 'hide']);

    taskWindow.dispose();
  });

  test(
    'native close is cancelled before hiding, then unhooked on dispose',
    () async {
      final window = _FakeNativeWindow();
      final host = SystemTaskWindowHost(window: window);
      final taskWindow = TaskWindow(host: host);
      final request = _FakeCloseRequest(window.events);

      await window.emit(
        native.WindowCloseRequestedEvent(windowId: 1, request: request),
      );

      expect(window.events, ['cancelClose', 'hide']);
      expect(request.isCancelled, isTrue);

      taskWindow.dispose();
      expect(window.listeners, isEmpty);

      taskWindow.show();
      expect(window.events, ['cancelClose', 'hide']);
    },
  );

  test('native minimized windows are restored before showing and focusing', () {
    final window = _FakeNativeWindow()..isMinimized = true;
    final taskWindow = TaskWindow(host: SystemTaskWindowHost(window: window));

    taskWindow.toggle();

    expect(window.events, ['restore', 'show', 'focus']);
    taskWindow.dispose();
  });

  test('hidden windows are shown even when reported as occluded', () {
    final window = _FakeNativeWindow()
      ..isVisible = false
      ..occlusionState = native.WindowOcclusionState.occluded;
    final taskWindow = TaskWindow(host: SystemTaskWindowHost(window: window));

    taskWindow.toggle();

    expect(window.events, ['show', 'focus']);
    taskWindow.dispose();
  });

  test('Linux unmapped windows are treated as minimized', () {
    final window = _FakeNativeWindow()
      ..occlusionState = native.WindowOcclusionState.occluded;
    final taskWindow = TaskWindow(host: SystemTaskWindowHost(window: window));

    taskWindow.toggle();

    expect(window.events, ['show', 'focus']);
    taskWindow.dispose();
  }, skip: !Platform.isLinux);
}

class _FakeTaskWindowHost implements TaskWindowHost {
  _FakeTaskWindowHost({this.state = TaskWindowState.shown});

  final List<String> events = [];
  final TaskWindowState state;
  VoidCallback? onClose;

  @override
  void setCloseHandler(VoidCallback? onClose) {
    this.onClose = onClose;
    events.add(onClose == null ? 'clearCloseHandler' : 'setCloseHandler');
  }

  @override
  void focus() {
    events.add('focus');
  }

  @override
  void hide() {
    events.add('hide');
  }

  @override
  TaskWindowState getState() {
    events.add('getState:${state.name}');
    return state;
  }

  @override
  void show() {
    events.add('show');
  }
}

class _FakeNativeWindow implements native.Window {
  @override
  bool isVisible = true;

  @override
  bool isMinimized = false;

  @override
  native.WindowOcclusionState occlusionState =
      native.WindowOcclusionState.unknown;

  final events = <String>[];
  final listeners =
      <native.ListenerId, FutureOr<void> Function(native.WindowEvent)>{};

  @override
  native.ListenerId addListener(
    FutureOr<void> Function(native.WindowEvent) callback,
  ) {
    listeners[1] = callback;
    return 1;
  }

  @override
  bool removeListener(native.ListenerId id) => listeners.remove(id) != null;

  Future<void> emit(native.WindowEvent event) async {
    for (final callback in listeners.values.toList()) {
      await callback(event);
    }
  }

  @override
  void focus() => events.add('focus');

  @override
  void hide() => events.add('hide');

  @override
  void restore() => events.add('restore');

  @override
  void show() => events.add('show');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCloseRequest implements native.EventRequest {
  _FakeCloseRequest(this.events);

  final List<String> events;

  @override
  bool isCancelled = false;

  @override
  bool cancel() {
    isCancelled = true;
    events.add('cancelClose');
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
