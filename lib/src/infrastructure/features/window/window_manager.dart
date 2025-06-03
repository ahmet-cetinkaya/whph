import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart' as wm;
import 'abstractions/i_window_manager.dart';

/// Base implementation of WindowManagerInterface using window_manager package
class WindowManager implements IWindowManager {
  @override
  Future<void> initialize() async {
    await wm.windowManager.ensureInitialized();
  }

  @override
  Future<void> show() async {
    await wm.windowManager.show();
  }

  @override
  Future<void> hide() async {
    await wm.windowManager.hide();
  }

  @override
  Future<void> close() async {
    await wm.windowManager.close();
  }

  @override
  Future<void> minimize() async {
    await wm.windowManager.minimize();
  }

  @override
  Future<void> maximize() async {
    await wm.windowManager.maximize();
  }

  @override
  Future<void> restore() async {
    await wm.windowManager.restore();
  }

  @override
  Future<void> focus() async {
    await wm.windowManager.focus();
  }

  @override
  Future<void> center() async {
    await wm.windowManager.center();
  }

  @override
  Future<void> setTitle(String title) async {
    await wm.windowManager.setTitle(title);
  }

  @override
  Future<String> getTitle() async {
    return await wm.windowManager.getTitle();
  }

  @override
  Future<void> setSize(Size size) async {
    await wm.windowManager.setSize(size);
  }

  @override
  Future<Size> getSize() async {
    return await wm.windowManager.getSize();
  }

  @override
  Future<void> setPosition(Offset position) async {
    await wm.windowManager.setPosition(position);
  }

  @override
  Future<Offset> getPosition() async {
    return await wm.windowManager.getPosition();
  }

  @override
  Future<bool> isVisible() async {
    return await wm.windowManager.isVisible();
  }

  @override
  Future<bool> isFocused() async {
    return await wm.windowManager.isFocused();
  }

  @override
  Future<bool> isMinimized() async {
    return await wm.windowManager.isMinimized();
  }

  @override
  Future<void> setPreventClose(bool preventClose) async {
    await wm.windowManager.setPreventClose(preventClose);
  }
}
