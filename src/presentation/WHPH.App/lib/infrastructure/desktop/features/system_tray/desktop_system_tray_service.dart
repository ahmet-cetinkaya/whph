import 'dart:io';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_system_tray_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:whph/core/domain/shared/constants/app_assets.dart';

class DesktopSystemTrayService extends TrayListener with WindowListener implements ISystemTrayService {
  final List<TrayMenuItem> _menuItems = [];
  final WindowManager _windowManager = WindowManager.instance;

  // Core methods
  @override
  Future<void> init() async {
    try {
      await destroy();
      _windowManager.addListener(this);

      await setIcon(TrayIconType.default_);

      // Add default menu items
      await setMenuItems([
        TrayMenuItem(key: 'show_window', label: 'Show Window', onClicked: _showWindow),
        TrayMenuItem(key: 'hide_window', label: 'Hide Window', onClicked: _hideWindow),
        TrayMenuItem.separator('window_separator'),
        TrayMenuItem(key: 'exit_app', label: 'Exit', onClicked: _exitApp),
      ]);

      trayManager.addListener(this);
    } catch (e) {
      Logger.error('Error initializing tray: $e');
    }
  }

  @override
  Future<void> destroy() async {
    _windowManager.removeListener(this);
    trayManager.removeListener(this);
    await trayManager.destroy();
  }

  @override
  Future<void> setIcon(TrayIconType type) async {
    try {
      final iconPath = AppAssets.getTrayIcon(type, isWindows: Platform.isWindows);
      await trayManager.setIcon(iconPath);
    } catch (e) {
      Logger.error('Error setting tray icon: $e');
    }
  }

  @override
  Future<void> setTitle(String title) async {
    try {
      await trayManager.setTitle(title);
    } catch (e) {
      Logger.error('Error setting tray title: $e');
    }
  }

  @override
  Future<void> setBody(String body) async {
    // Not applicable for desktop
  }

  // Menu management methods
  @override
  List<TrayMenuItem> getMenuItems() => List.unmodifiable(_menuItems);

  @override
  Future<void> setMenuItems(List<TrayMenuItem> items) async {
    _menuItems
      ..clear()
      ..addAll(items);
    await _rebuildMenu();
  }

  @override
  Future<void> insertMenuItem(TrayMenuItem item, {int? index}) async {
    if (index != null) {
      _menuItems.insert(index, item);
    } else {
      _menuItems.add(item);
    }
    await _rebuildMenu();
  }

  @override
  Future<void> updateMenuItem(String key, TrayMenuItem newItem) async {
    final index = _menuItems.indexWhere((item) => item.key == key);
    if (index != -1) {
      _menuItems[index] = newItem;
      await _rebuildMenu();
    }
  }

  @override
  Future<TrayMenuItem?> getMenuItem(String key) async {
    return _menuItems.firstWhere(
      (item) => item.key == key,
      orElse: () => TrayMenuItem(key: '', label: ''),
    );
  }

  @override
  Future<void> removeMenuItem(String key) async {
    _menuItems.removeWhere((item) => item.key == key);
    await _rebuildMenu();
  }

  @override
  Future<void> reset() async {
    await destroy();
    await init();
  }

  // Private helper methods
  Future<void> _rebuildMenu() async {
    final menu = Menu(
      items: _menuItems.map((item) {
        if (item.isSeparator) return MenuItem.separator();
        return MenuItem(key: item.key, label: item.label);
      }).toList(),
    );
    await trayManager.setContextMenu(menu);
  }

  Future<void> _showWindow() async {
    await _windowManager.show();
    await _windowManager.focus();
  }

  Future<void> _hideWindow() async {
    await _windowManager.hide();
  }

  Future<void> _exitApp() async {
    await destroy();
    // Direct exit - cleanup is handled by signal handlers in main.dart
    exit(0);
  }

  // Event handlers
  @override
  void onWindowClose() {
    _hideWindow();
  }

  @override
  void onTrayIconMouseDown() {
    _showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconMouseUp() {
    _showWindow();
  }

  @override
  void onTrayIconRightMouseUp() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final item = _menuItems.firstWhere(
      (item) => item.key == menuItem.key,
      orElse: () => TrayMenuItem(key: '', label: ''),
    );
    item.onClicked?.call();
  }
}
