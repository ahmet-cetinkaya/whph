import 'dart:async';

import 'package:flutter/material.dart';
import 'package:acore/acore.dart' show ColorHelper;
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/core/shared/utils/logger.dart';

/// A helper class for showing overlay notifications that appear above all content,
/// independent of Scaffold widgets. These notifications appear at the top of the screen
/// and automatically dismiss after a specified duration.
class OverlayNotificationHelper {
  static OverlayEntry? _currentOverlay;

  /// Shows an overlay notification at the top of the screen
  static void showNotification({
    required BuildContext context,
    required String message,
    Color? backgroundColor,
    IconData? icon,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
    Widget? actionWidget,
  }) {
    // Remove any existing overlay first
    hideNotification();

    // Check if overlay is available before proceeding
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      // Overlay not available, cannot show notification
      Logger.warning('Cannot show overlay notification - no Overlay widget found in context');
      return;
    }

    _currentOverlay = OverlayEntry(
      builder: (context) => _NotificationOverlay(
        message: message,
        backgroundColor: backgroundColor ?? AppTheme.errorColor,
        icon: icon,
        duration: duration,
        onTap: onTap,
        onDismiss: hideNotification,
        actionWidget: actionWidget,
      ),
    );

    overlay.insert(_currentOverlay!);
  }

  /// Shows an error notification with predefined styling
  static void showError({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 5),
    VoidCallback? onTap,
    Widget? actionWidget,
  }) {
    showNotification(
      context: context,
      message: message,
      backgroundColor: AppTheme.errorColor,
      icon: Icons.error_outline,
      duration: duration,
      onTap: onTap,
      actionWidget: actionWidget,
    );
  }

  /// Shows a success notification with predefined styling
  static void showSuccess({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
    Widget? actionWidget,
  }) {
    showNotification(
      context: context,
      message: message,
      backgroundColor: Colors.green,
      icon: Icons.check_circle_outline,
      duration: duration,
      onTap: onTap,
      actionWidget: actionWidget,
    );
  }

  /// Shows an info notification with predefined styling
  static void showInfo({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
    Widget? actionWidget,
  }) {
    showNotification(
      context: context,
      message: message,
      backgroundColor: AppTheme.primaryColor,
      icon: Icons.info_outline,
      duration: duration,
      onTap: onTap,
      actionWidget: actionWidget,
    );
  }

  /// Shows a loading notification with a progress indicator
  static void showLoading({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 30),
    VoidCallback? onTap,
    Widget? actionWidget,
  }) {
    showNotification(
      context: context,
      message: message,
      backgroundColor: AppTheme.primaryColor,
      icon: null, // We'll add a custom loading widget
      duration: duration,
      onTap: onTap,
      actionWidget: actionWidget ??
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(ColorHelper.getContrastingTextColor(AppTheme.primaryColor,
                  darkColor: AppTheme.darkTextColor, lightColor: AppTheme.lightTextColor)),
            ),
          ),
    );
  }

  /// Hides the current overlay notification if one is showing
  static void hideNotification() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}

/// The actual overlay widget that displays the notification
class _NotificationOverlay extends StatefulWidget {
  const _NotificationOverlay({
    required this.message,
    required this.backgroundColor,
    this.icon,
    required this.duration,
    this.onTap,
    required this.onDismiss,
    this.actionWidget,
  });

  final String message;
  final Color backgroundColor;
  final IconData? icon;
  final Duration duration;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;
  final Widget? actionWidget;

  @override
  State<_NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<_NotificationOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _animation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _animationController.forward();

    _dismissTimer = Timer(widget.duration, () {
      _animationController.reverse().then((_) {
        widget.onDismiss();
      });
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contrastingTextColor = ColorHelper.getContrastingTextColor(widget.backgroundColor,
        darkColor: AppTheme.darkTextColor, lightColor: AppTheme.lightTextColor);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(_animation),
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: contrastingTextColor),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        widget.message,
                        style: TextStyle(color: contrastingTextColor, fontSize: AppTheme.fontSizeLarge),
                      ),
                    ),
                    if (widget.actionWidget != null) ...[
                      const SizedBox(width: 12),
                      widget.actionWidget!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
