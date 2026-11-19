import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nativeapi/nativeapi.dart' as native;

TaskWindow createTaskWindow({TaskWindowHost? host}) {
  return TaskWindow(host: host);
}

enum TaskWindowState { hidden, minimized, shown }

abstract interface class TaskWindowHost {
  void setCloseHandler(VoidCallback? onClose);

  void focus();

  void hide();

  TaskWindowState getState();

  void show();
}

class SystemTaskWindowHost implements TaskWindowHost {
  SystemTaskWindowHost({this._window});

  native.Window? _window;
  native.ListenerId? _closeListenerId;

  native.Window get _target => _window ??=
      native.WindowManager.instance.getCurrent() ??
      (throw StateError('Cannot find app window'));

  @override
  void setCloseHandler(VoidCallback? onClose) {
    final previousId = _closeListenerId;

    if (previousId != null) {
      _target.removeListener(previousId);
      _closeListenerId = null;
    }

    if (onClose != null) {
      _closeListenerId = _target.addListener((event) {
        if (event is native.WindowCloseRequestedEvent) {
          event.request.cancel();
          onClose();
        }
      });
    }
  }

  @override
  void focus() {
    _target.focus();
  }

  @override
  void hide() {
    _target.hide();
  }

  @override
  TaskWindowState getState() {
    if (!_target.isVisible) {
      return TaskWindowState.hidden;
    }

    // Linux also reports unmapped or withdrawn windows as occluded.
    if (_target.isMinimized ||
        (Platform.isLinux &&
            _target.occlusionState == native.WindowOcclusionState.occluded)) {
      return TaskWindowState.minimized;
    }

    return TaskWindowState.shown;
  }

  @override
  void show() {
    if (_target.isMinimized) {
      _target.restore();
    }

    _target.show();
  }
}

class TaskWindow {
  TaskWindow({TaskWindowHost? host}) : _host = host ?? SystemTaskWindowHost() {
    if (_isSupported) {
      _host.setCloseHandler(_onWindowClose);
    }
  }

  final TaskWindowHost _host;
  bool _isDisposed = false;

  void show() {
    _run(_showAndFocus);
  }

  void toggle() {
    _run(() {
      final state = _host.getState();

      if (state == TaskWindowState.shown) {
        _host.hide();
        return;
      }

      _showAndFocus();
    });
  }

  void _onWindowClose() {
    _run(_host.hide);
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    if (_isSupported) {
      _host.setCloseHandler(null);
    }
  }

  void _run(VoidCallback action) {
    if (!_isSupported || _isDisposed) {
      return;
    }

    try {
      action();
    } on Object catch (_) {}
  }

  void _showAndFocus() {
    _host.show();
    _host.focus();
  }
}

bool get _isSupported {
  return Platform.isLinux || Platform.isMacOS || Platform.isWindows;
}
