import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

Future<void> initializeTaskWindow() async {
  if (!_isSupported) {
    return;
  }

  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
}

TaskWindow createTaskWindow({TaskWindowHost? host}) {
  return TaskWindow(host: host);
}

enum TaskWindowState {
  hidden,
  minimized,
  shown;

  static TaskWindowState fromName(String? name) {
    return switch (name) {
      'shown' => TaskWindowState.shown,
      'minimized' => TaskWindowState.minimized,
      _ => TaskWindowState.hidden,
    };
  }
}

abstract interface class TaskWindowHost {
  void addListener(WindowListener listener);

  void removeListener(WindowListener listener);

  Future<void> focus();

  Future<void> hide();

  Future<TaskWindowState> getState();

  Future<void> setPreventClose(bool isPreventClose);

  Future<void> show();
}

class SystemTaskWindowHost implements TaskWindowHost {
  const SystemTaskWindowHost();

  static const MethodChannel _channel = MethodChannel('tasks_tracker/window');

  @override
  void addListener(WindowListener listener) {
    windowManager.addListener(listener);
  }

  @override
  void removeListener(WindowListener listener) {
    windowManager.removeListener(listener);
  }

  @override
  Future<void> focus() {
    return windowManager.focus();
  }

  @override
  Future<void> hide() {
    return windowManager.hide();
  }

  @override
  Future<TaskWindowState> getState() async {
    if (Platform.isLinux) {
      final stateName = await _channel.invokeMethod<String>('getState');
      return TaskWindowState.fromName(stateName);
    }

    if (await windowManager.isMinimized()) {
      return TaskWindowState.minimized;
    }

    if (await windowManager.isVisible()) {
      return TaskWindowState.shown;
    }

    return TaskWindowState.hidden;
  }

  @override
  Future<void> setPreventClose(bool isPreventClose) {
    return windowManager.setPreventClose(isPreventClose);
  }

  @override
  Future<void> show() {
    return windowManager.show();
  }
}

class TaskWindow with WindowListener {
  TaskWindow({TaskWindowHost? host})
    : _host = host ?? const SystemTaskWindowHost() {
    if (_isSupported) {
      _host.addListener(this);
    }
  }

  final TaskWindowHost _host;
  Future<void> _operation = Future<void>.value();
  bool _isDisposed = false;

  @visibleForTesting
  Future<void> get idle => _operation;

  Future<void> show() {
    return _enqueue(_showAndFocus);
  }

  Future<void> toggle() {
    return _enqueue(() async {
      final state = await _host.getState();
      if (state == TaskWindowState.shown) {
        await _host.hide();
        return;
      }

      await _showAndFocus();
    });
  }

  @override
  void onWindowClose() {
    _enqueue(_host.hide);
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    if (_isSupported) {
      _host.removeListener(this);
      await _operation;
      await _host.setPreventClose(false);
    }
  }

  Future<void> _enqueue(Future<void> Function() action) {
    if (!_isSupported || _isDisposed) {
      return Future<void>.value();
    }

    _operation = _operation
        .then((_) => action())
        .catchError((Object error, StackTrace stackTrace) {});
    return _operation;
  }

  Future<void> _showAndFocus() async {
    await _host.show();
    await _host.focus();
  }
}

bool get _isSupported {
  return Platform.isLinux || Platform.isMacOS || Platform.isWindows;
}
