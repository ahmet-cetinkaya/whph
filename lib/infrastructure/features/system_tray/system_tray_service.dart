import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:whph/presentation/shared/services/abstraction/i_system_tray_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:whph/domain/shared/constants/app_assets.dart';

class SystemTrayService extends TrayListener with WindowListener implements ISystemTrayService {
  final List<TrayMenuItem> _menuItems = [];

  @override
  Future<void> init() async {
    try {
      await destroy();
      windowManager.addListener(this);

      await setTrayIcon(TrayIconType.default_);

      // Add default menu items
      await addMenuItems([
        TrayMenuItem(key: 'show_window', label: 'Show Window', onClicked: showWindow),
        TrayMenuItem(key: 'hide_window', label: 'Hide Window', onClicked: hideWindow),
        TrayMenuItem.separator('window_separator'),
        TrayMenuItem(key: 'exit_app', label: 'Exit', onClicked: exitApp),
      ]);

      trayManager.addListener(this);
    } catch (e) {
      if (kDebugMode) {
        print('ERROR: Error initializing tray: $e');
      }
    }
  }

  @override
  Future<void> setTrayIcon(TrayIconType type) async {
    try {
      await trayManager.setIcon(
        AppAssets.getTrayIcon(type, isWindows: Platform.isWindows),
      );
    } catch (e) {
      if (kDebugMode) {
        print('ERROR: Error setting tray icon: $e');
      }
    }
  }

  @override
  Future<void> destroy() async {
    windowManager.removeListener(this); // Remove window event listener
    trayManager.removeListener(this);
    await trayManager.destroy();
  }

  // Capture window close event
  @override
  void onWindowClose() {
    hideWindow(); // Hide window instead of closing it
  }

  @override
  Future<void> showWindow() async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;

    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> hideWindow() async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;

    await windowManager.hide();
  }

  @override
  Future<void> exitApp() async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      exit(0);
    }

    await windowManager.destroy();
    exit(0);
  }

  @override
  void onTrayIconMouseDown() {
    if (Platform.isLinux) showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    if (Platform.isLinux) trayManager.popUpContextMenu();
  }

  @override
  Future<void> addMenuItem(TrayMenuItem item) async {
    _menuItems.add(item);
    await rebuildMenu();
  }

  @override
  Future<void> addMenuItems(List<TrayMenuItem> items) async {
    _menuItems.addAll(items);
    await rebuildMenu();
  }

  @override
  Future<void> insertMenuItems(List<TrayMenuItem> items, int index) async {
    _menuItems.insertAll(index, items);
    await rebuildMenu();
  }

  @override
  Future<void> removeMenuItem(String key) async {
    _menuItems.removeWhere((item) => item.key == key);
    await rebuildMenu();
  }

  @override
  Future<void> clearMenu() async {
    _menuItems.clear();
    await rebuildMenu();
  }

  @override
  Future<void> rebuildMenu() async {
    final menu = Menu(
      items: _menuItems.map((item) {
        if (item.isSeparator) return MenuItem.separator();
        return MenuItem(
          key: item.key,
          label: item.label,
        );
      }).toList(),
    );
    await trayManager.setContextMenu(menu);
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
