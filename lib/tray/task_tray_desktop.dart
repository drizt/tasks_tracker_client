import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nativeapi/nativeapi.dart' as native;

import '../state/task_controller.dart';

const _exitMenuKey = 'exit';

TaskTray createTaskTray({
  void Function()? exitApplication,
  Future<void> Function()? toggleAppWindow,
}) {
  return TaskTray(
    exitApplication: exitApplication,
    toggleAppWindow: toggleAppWindow,
  );
}

class TaskTrayMenuItem {
  const TaskTrayMenuItem({required this.key, required this.label})
    : isSeparator = false;

  const TaskTrayMenuItem.separator()
    : key = null,
      label = null,
      isSeparator = true;

  final String? key;
  final String? label;
  final bool isSeparator;
}

abstract interface class TaskTrayHost {
  void setHandlers({
    required VoidCallback onClick,
    required VoidCallback onRightClick,
    required void Function(String key) onMenuItemClick,
  });

  Future<void> destroy();

  Future<void> openContextMenu();

  Future<void> setContextMenu(List<TaskTrayMenuItem> items);

  Future<void> setIcon(String iconPath);

  Future<void> setToolTip(String toolTip);
}

TaskTrayHost createSystemTaskTrayHost() {
  return NativeApiTaskTrayHost();
}

class NativeApiTaskTrayHost implements TaskTrayHost {
  NativeApiTaskTrayHost();

  final native.TrayIcon _trayIcon = native.TrayIcon();
  final List<native.Image> _images = [];
  final List<native.MenuItem> _menuItems = [];
  // Keep the native menu wrapper alive while the tray icon references it.
  // ignore: unused_field
  native.Menu? _menu;
  void Function(String key)? _onMenuItemClick;

  @override
  void setHandlers({
    required VoidCallback onClick,
    required VoidCallback onRightClick,
    required void Function(String key) onMenuItemClick,
  }) {
    _onMenuItemClick = onMenuItemClick;
    _trayIcon.on<native.TrayIconClickedEvent>((_) => onClick());
    _trayIcon.on<native.TrayIconRightClickedEvent>((_) => onRightClick());
  }

  @override
  Future<void> destroy() async {
    _trayIcon.isVisible = false;
    _trayIcon.dispose();
    for (final image in _images) {
      image.dispose();
    }
    _images.clear();
  }

  @override
  Future<void> openContextMenu() async {
    _trayIcon.openContextMenu();
  }

  @override
  Future<void> setContextMenu(List<TaskTrayMenuItem> items) async {
    _menuItems.clear();

    final menu = native.Menu();
    for (final item in items) {
      if (item.isSeparator) {
        menu.addSeparator();
        continue;
      }

      final key = item.key;
      final label = item.label;
      if (key == null || label == null) {
        continue;
      }

      final menuItem = native.MenuItem(label);
      menuItem.on<native.MenuItemClickedEvent>(
        (_) => _onMenuItemClick?.call(key),
      );
      menu.addItem(menuItem);
      _menuItems.add(menuItem);
    }

    _menu = menu;
    _trayIcon.contextMenu = menu;
    _trayIcon.contextMenuTrigger = native.ContextMenuTrigger.rightClicked;
    _trayIcon.isVisible = true;
  }

  @override
  Future<void> setIcon(String iconPath) async {
    final image = native.Image.fromAsset(iconPath);
    if (image == null) {
      return;
    }

    _images.add(image);
    _trayIcon.icon = image;
    _trayIcon.isVisible = true;
  }

  @override
  Future<void> setToolTip(String toolTip) async {
    _trayIcon.title = toolTip;
    _trayIcon.tooltip = toolTip;
    _trayIcon.isVisible = true;
  }
}

class TaskTray {
  TaskTray({
    void Function()? exitApplication,
    this.toggleAppWindow,
    TaskTrayHost? host,
  }) : _exitApplication = exitApplication ?? (() => exit(0)),
       _host = host ?? createSystemTaskTrayHost() {
    if (_isSupported) {
      _host.setHandlers(
        onClick: _toggleAppWindow,
        onRightClick: _openContextMenu,
        onMenuItemClick: _handleMenuItemClick,
      );
      _sync();
    }
  }

  final void Function() _exitApplication;
  final Future<void> Function()? toggleAppWindow;
  final TaskTrayHost _host;
  TaskController? _controller;
  Future<void> _operation = Future<void>.value();
  bool _hasIcon = false;
  bool _hasActiveIcon = false;
  bool _isDisposed = false;

  @visibleForTesting
  Future<void> get idle => _operation;

  bool get _isSupported {
    return Platform.isLinux || Platform.isMacOS || Platform.isWindows;
  }

  String get _iconPath => 'assets/app_icon.png';

  String get _activeIconPath => 'assets/app_icon_active.png';

  void attach(TaskController? controller) {
    if (identical(_controller, controller)) {
      return;
    }

    _controller?.removeListener(_sync);
    _controller = controller;
    _controller?.addListener(_sync);
    _sync();
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    _controller?.removeListener(_sync);
    _controller = null;

    await _operation;
    if (_hasIcon) {
      await _host.destroy();
      _hasIcon = false;
    }
  }

  void _sync() {
    if (!_isSupported || _isDisposed) {
      return;
    }

    final hasActiveTimer = _controller?.hasActiveTimer ?? false;
    _operation = _operation
        .then((_) => _setActive(hasActiveTimer))
        .catchError((Object error, StackTrace stackTrace) {});
  }

  Future<void> _setActive(bool hasActiveTimer) async {
    if (_isDisposed || (_hasIcon && _hasActiveIcon == hasActiveTimer)) {
      return;
    }

    await _host.setIcon(hasActiveTimer ? _activeIconPath : _iconPath);
    await _host.setToolTip('Tasks Tracker');
    if (!_hasIcon) {
      await _host.setContextMenu(_menuItems);
    }
    _hasIcon = true;
    _hasActiveIcon = hasActiveTimer;
  }

  void _toggleAppWindow() {
    unawaited(toggleAppWindow?.call());
  }

  void _openContextMenu() {
    unawaited(_host.openContextMenu());
  }

  void _handleMenuItemClick(String key) {
    switch (key) {
      case _exitMenuKey:
        _exitApplication();
    }
  }

  List<TaskTrayMenuItem> get _menuItems {
    return [const TaskTrayMenuItem(key: _exitMenuKey, label: 'Exit')];
  }
}
