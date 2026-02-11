import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';

/// A full-screen loading overlay that covers the entire page during data loading.
///
/// This overlay appears when [isLoading] is true and smoothly fades out when
/// loading completes. It prevents content from appearing piece by piece and
/// ensures users see the complete page at once.
///
/// The overlay uses a semi-transparent background with a centered circular
/// progress indicator.
class LoadingOverlay extends StatefulWidget {
  /// Whether the overlay should be visible
  final bool isLoading;

  /// The widget to display beneath the overlay
  final Widget child;

  /// Duration of the fade-out animation when loading completes
  final Duration fadeDuration;

  /// Background color of the overlay
  final Color? backgroundColor;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.fadeDuration = const Duration(milliseconds: 300),
    this.backgroundColor,
  });

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _showOverlay = widget.isLoading;

    _animationController = AnimationController(
      vsync: this,
      duration: widget.fadeDuration,
    );

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _showOverlay = false;
          });
        }
      }
    });
  }

  @override
  void didUpdateWidget(LoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading && !widget.isLoading) {
      // Start fade out animation
      _animationController.forward();
    } else if (!oldWidget.isLoading && widget.isLoading) {
      // Reset overlay to visible state
      _animationController.reset();
      setState(() {
        _showOverlay = true;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        widget.child,

        // Loading overlay
        if (_showOverlay)
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              color: widget.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.surface3,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
