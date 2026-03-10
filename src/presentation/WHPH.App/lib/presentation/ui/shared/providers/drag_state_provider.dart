import 'package:flutter/material.dart';

/// Notifier for tracking drag state in reorderable lists
class DragStateNotifier extends ChangeNotifier {
  bool _isDragging = false;

  bool get isDragging => _isDragging;

  void startDragging() {
    if (!_isDragging) {
      _isDragging = true;
      notifyListeners();
    }
  }

  void stopDragging() {
    if (_isDragging) {
      _isDragging = false;
      notifyListeners();
    }
  }
}

/// Provider widget for drag state
class DragStateProvider extends InheritedNotifier<DragStateNotifier> {
  const DragStateProvider({
    super.key,
    required DragStateNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static DragStateNotifier? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DragStateProvider>()?.notifier;
  }

  static bool isDragging(BuildContext context) {
    final notifier = of(context);
    return notifier?.isDragging ?? false;
  }
}
