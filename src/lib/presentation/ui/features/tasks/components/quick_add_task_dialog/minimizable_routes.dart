import 'package:flutter/material.dart' hide ModalBottomSheetRoute;
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

/// Tracks whether a minimizable modal route is currently collapsed.
///
/// The controller is owned by the code that pushes the route, so it outlives
/// rebuilds of the route content and never resets while the route is alive.
class SheetMinimizeController extends ChangeNotifier {
  bool _isMinimized = false;

  bool get isMinimized => _isMinimized;

  void minimize() => _setMinimized(true);

  void restore() => _setMinimized(false);

  void _setMinimized(bool value) {
    if (_isMinimized == value) return;
    _isMinimized = value;
    notifyListeners();
  }
}

/// Exposes a [SheetMinimizeController] to the route content.
///
/// Absent when the host route cannot collapse, which lets descendants hide the
/// minimize affordance instead of showing a dead one.
class SheetMinimizeScope extends InheritedNotifier<SheetMinimizeController> {
  const SheetMinimizeScope({
    super.key,
    required SheetMinimizeController controller,
    required super.child,
  }) : super(notifier: controller);

  static SheetMinimizeController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SheetMinimizeScope>()?.notifier;
  }
}

/// A material modal bottom sheet whose barrier disappears while minimized.
///
/// Dropping the barrier is what makes the content behind the sheet scrollable
/// and tappable again. The route itself is never popped, so the sheet's [State]
/// - and therefore every value the user already entered - stays alive.
class MinimizableSheetRoute<T> extends ModalSheetRoute<T> {
  MinimizableSheetRoute({
    required this.minimizeController,
    required super.builder,
    super.containerBuilder,
    super.barrierLabel,
    super.isDismissible,
    super.enableDrag,
    super.settings,
    super.expanded = false,
  });

  final SheetMinimizeController minimizeController;

  @override
  Widget buildModalBarrier() {
    return AnimatedBuilder(
      animation: minimizeController,
      builder: (context, _) {
        if (minimizeController.isMinimized) return const SizedBox.shrink();
        return super.buildModalBarrier();
      },
    );
  }
}

/// Mirrors the private container builder used by [showMaterialModalBottomSheet]
/// so a custom route keeps the stock material sheet appearance.
WidgetWithChildBuilder buildMaterialSheetContainer(BuildContext context) {
  final theme = Theme.of(context);
  final sheetTheme = theme.bottomSheetTheme;

  return (builderContext, animation, child) => Theme(
        data: theme,
        child: Material(
          color: sheetTheme.modalBackgroundColor ?? sheetTheme.backgroundColor,
          elevation: sheetTheme.elevation ?? 0.0,
          shape: sheetTheme.shape,
          clipBehavior: sheetTheme.clipBehavior ?? Clip.none,
          child: child,
        ),
      );
}

/// The desktop counterpart of [MinimizableSheetRoute].
///
/// [DialogRoute] is a [PopupRoute], so `opaque` is already `false` and the route
/// below stays mounted and painted. The only thing intercepting pointers is the
/// [ModalBarrier] built by [ModalRoute.buildModalBarrier], so dropping it while
/// minimized hands input back to the page behind without popping this route.
class MinimizableDialogRoute<T> extends DialogRoute<T> {
  MinimizableDialogRoute({
    required this.minimizeController,
    required super.context,
    required super.builder,
    super.themes,
    super.barrierColor,
    super.barrierDismissible,
    super.barrierLabel,
    super.settings,
  });

  final SheetMinimizeController minimizeController;

  @override
  Widget buildModalBarrier() {
    return AnimatedBuilder(
      animation: minimizeController,
      builder: (context, _) {
        if (minimizeController.isMinimized) return const SizedBox.shrink();
        return super.buildModalBarrier();
      },
    );
  }
}
