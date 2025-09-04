import 'package:flutter/material.dart';

/// Interface for window management operations
abstract class IWindowManager {
  /// Initialize the window manager
  Future<void> initialize();

  /// Show the window
  Future<void> show();

  /// Hide the window
  Future<void> hide();

  /// Close the window
  Future<void> close();

  /// Minimize the window
  Future<void> minimize();

  /// Maximize the window
  Future<void> maximize();

  /// Restore the window to its previous state
  Future<void> restore();

  /// Focus the window (bring to foreground)
  Future<void> focus();

  /// Center the window on the screen
  Future<void> center();

  /// Set the window title
  Future<void> setTitle(String title);

  /// Get the window title
  Future<String> getTitle();

  /// Set the window size
  Future<void> setSize(Size size);

  /// Get the window size
  Future<Size> getSize();

  /// Set the window position
  Future<void> setPosition(Offset position);

  /// Get the window position
  Future<Offset> getPosition();

  /// Check if the window is visible
  Future<bool> isVisible();

  /// Check if the window is focused
  Future<bool> isFocused();

  /// Check if the window is minimized
  Future<bool> isMinimized();

  /// Set whether the window should prevent close
  Future<void> setPreventClose(bool preventClose);
}
