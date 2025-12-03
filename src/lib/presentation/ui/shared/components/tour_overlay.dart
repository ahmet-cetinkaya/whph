import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/corePackages/acore/lib/utils/color_contrast_helper.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';

class TourStep {
  final String title;
  final String description;
  final GlobalKey? targetKey;
  final Offset? targetPosition;
  final Size? targetSize;
  final TourHighlightShape shape;
  final TourPosition position;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final IconData? icon;
  final bool highlightFullScreen;

  const TourStep({
    required this.title,
    required this.description,
    this.targetKey,
    this.targetPosition,
    this.targetSize,
    this.shape = TourHighlightShape.rectangle,
    this.position = TourPosition.bottom,
    this.onNext,
    this.onPrevious,
    this.icon,
    this.highlightFullScreen = false,
  });
}

enum TourHighlightShape {
  rectangle,
  circle,
  roundedRectangle,
}

enum TourPosition {
  top,
  bottom,
  left,
  right,
  center,
}

class _DimOverlayPainter extends CustomPainter {
  final Rect clearRect;
  final Color backgroundColor;

  _DimOverlayPainter({
    required this.clearRect,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    // Draw four rectangles around the clear area
    final rects = <Rect>[
      // Top rectangle (above clear area)
      Rect.fromLTRB(0, 0, size.width, clearRect.top),
      // Bottom rectangle (below clear area)
      Rect.fromLTRB(0, clearRect.bottom, size.width, size.height),
      // Left rectangle (middle section)
      Rect.fromLTRB(0, clearRect.top, clearRect.left, clearRect.bottom),
      // Right rectangle (middle section)
      Rect.fromLTRB(clearRect.right, clearRect.top, size.width, clearRect.bottom),
    ];

    for (final rect in rects) {
      if (rect.width > 0 && rect.height > 0) {
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DimOverlayPainter oldDelegate) {
    return oldDelegate.clearRect != clearRect || oldDelegate.backgroundColor != backgroundColor;
  }
}

class TourOverlay extends StatefulWidget {
  final List<TourStep> steps;
  final VoidCallback? onComplete;
  final Future<void> Function()? onSkip;
  final VoidCallback? onBack;
  final bool showBackButton;
  final bool isFinalPageOfTour;
  final int initialStep;
  final ITranslationService translationService;

  const TourOverlay({
    super.key,
    required this.steps,
    this.onComplete,
    this.onSkip,
    this.onBack,
    this.showBackButton = false,
    this.isFinalPageOfTour = false,
    this.initialStep = 0,
    required this.translationService,
  });

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay> {
  late int _currentStepIndex;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _currentStepIndex = widget.initialStep;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showTourStep();
    });
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  void _showTourStep() {
    final step = widget.steps[_currentStepIndex];
    final renderBox = step.targetKey?.currentContext?.findRenderObject() as RenderBox?;
    final position = renderBox?.localToGlobal(Offset.zero);
    final size = renderBox?.size;

    // Check if we have valid position and size, if not, retry after a short delay
    if ((position == null || position == Offset.zero || size == null || size.isEmpty) && step.targetKey != null) {
      // Retry after a short delay to allow layout to complete
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _showTourStep();
        }
      });
      return;
    }

    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        builder: (context) => _TourOverlayContent(
          currentStepIndex: _currentStepIndex,
          steps: widget.steps,
          onNext: _nextStep,
          onPrevious: _previousStep,
          onSkip: _skipTour,
          onBack: widget.onBack,
          showBackButton: widget.showBackButton,
          isFinalPageOfTour: widget.isFinalPageOfTour,
          isFirstStep: _currentStepIndex == 0,
          isLastStep: _currentStepIndex == widget.steps.length - 1,
          translationService: widget.translationService,
        ),
      );

      // Defer overlay insertion to after build is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _overlayEntry != null) {
          Overlay.of(context).insert(_overlayEntry!);
        }
      });
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _nextStep() {
    widget.steps[_currentStepIndex].onNext?.call();

    if (_currentStepIndex < widget.steps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
      _showTourStep();
    } else {
      _completeTour();
    }
  }

  void _previousStep() {
    widget.steps[_currentStepIndex].onPrevious?.call();

    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
      });
      _showTourStep();
    }
  }

  Future<void> _skipTour() async {
    if (widget.onSkip != null) {
      await widget.onSkip!();
    }
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _completeTour() {
    widget.onComplete?.call();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _TourOverlayContent extends StatelessWidget {
  final int currentStepIndex;
  final List<TourStep> steps;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Future<void> Function() onSkip;
  final VoidCallback? onBack;
  final bool showBackButton;
  final bool isFinalPageOfTour;
  final bool isFirstStep;
  final bool isLastStep;
  final ITranslationService translationService;

  const _TourOverlayContent({
    required this.currentStepIndex,
    required this.steps,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
    this.onBack,
    required this.showBackButton,
    required this.isFinalPageOfTour,
    required this.isFirstStep,
    required this.isLastStep,
    required this.translationService,
  });

  @override
  Widget build(BuildContext context) {
    final step = steps[currentStepIndex];
    final renderBox = step.targetKey?.currentContext?.findRenderObject() as RenderBox?;
    final position = renderBox?.localToGlobal(Offset.zero);
    final size = renderBox?.size;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: TourStepOverlay(
        key: ValueKey(currentStepIndex),
        step: step,
        targetPosition: position ?? step.targetPosition ?? Offset.zero,
        targetSize: size ?? step.targetSize ?? Size.zero,
        onNext: onNext,
        onPrevious: onPrevious,
        onSkip: onSkip,
        onBack: onBack,
        showBackButton: showBackButton,
        isFirstStep: currentStepIndex == 0,
        isLastStep: currentStepIndex == steps.length - 1,
        isFinalPageOfTour: isFinalPageOfTour,
        stepNumber: currentStepIndex + 1,
        totalSteps: steps.length,
        translationService: translationService,
      ),
    );
  }
}

class TourStepOverlay extends StatelessWidget {
  final TourStep step;
  final Offset targetPosition;
  final Size targetSize;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Future<void> Function() onSkip;
  final VoidCallback? onBack;
  final bool showBackButton;
  final bool isFirstStep;
  final bool isLastStep;
  final bool isFinalPageOfTour;
  final int stepNumber;
  final int totalSteps;
  final ITranslationService translationService;

  const TourStepOverlay({
    super.key,
    required this.step,
    required this.targetPosition,
    required this.targetSize,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
    this.onBack,
    this.showBackButton = false,
    required this.isFirstStep,
    required this.isLastStep,
    this.isFinalPageOfTour = false,
    required this.stepNumber,
    required this.totalSteps,
    required this.translationService,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    // Recalculate target position and size from GlobalKey if available
    // This ensures the highlight repositions correctly when screen size changes
    Offset currentTargetPosition = targetPosition;
    Size currentTargetSize = targetSize;

    if (step.targetKey != null) {
      final renderBox = step.targetKey!.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;

        // Only update if we have valid values
        if (position != Offset.zero && !size.isEmpty) {
          currentTargetPosition = position;
          currentTargetSize = size;
        }
      }
    }

    // Border area - if highlightFullScreen, use full screen dimensions
    final borderLeft = step.highlightFullScreen ? 0.0 : currentTargetPosition.dx - 8;
    final borderTop = step.highlightFullScreen ? 0.0 : currentTargetPosition.dy - 8;
    final borderWidth = step.highlightFullScreen ? screenSize.width : currentTargetSize.width + 16;
    final borderHeight = step.highlightFullScreen ? screenSize.height : currentTargetSize.height + 16;

    return Stack(
      children: [
        // Dimmed background outside highlighted area (only if not full screen)
        if (currentTargetSize != Size.zero && !step.highlightFullScreen)
          Positioned.fill(
            child: CustomPaint(
              painter: _DimOverlayPainter(
                clearRect: Rect.fromLTWH(borderLeft, borderTop, borderWidth, borderHeight),
                backgroundColor: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ),

        // Full screen background for when no target or full screen highlight
        if (currentTargetSize == Size.zero || step.highlightFullScreen)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),

        // Highlighted area border (only if not full screen)
        if (currentTargetSize != Size.zero && !step.highlightFullScreen)
          Positioned(
            left: borderLeft,
            top: borderTop,
            width: borderWidth,
            height: borderHeight,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppTheme.primaryColor,
                    width: 3,
                  ),
                  borderRadius: step.shape == TourHighlightShape.circle
                      ? BorderRadius.circular(borderWidth / 2)
                      : BorderRadius.circular(AppTheme.sizeSmall),
                ),
              ),
            ),
          ),

        // Tour content with tap protection (without buttons)
        Positioned(
          left: _getContentPosition(context, currentTargetPosition, currentTargetSize).dx,
          top: _getContentPosition(context, currentTargetPosition, currentTargetSize).dy,
          child: GestureDetector(
            onTap: () {}, // Prevent tap dismissal on content
            behavior: HitTestBehavior.opaque,
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.9,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.4, // Reduced to make room for fixed buttons
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surface1,
                  borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.sizeMedium),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Step indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.sizeSmall,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(AppTheme.sizeXSmall),
                        ),
                        child: Text(
                          '$stepNumber / $totalSteps',
                          style: AppTheme.bodySmall.copyWith(
                            color: ColorContrastHelper.getContrastingTextColor(AppTheme.primaryColor),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(height: AppTheme.sizeSmall),

                      // Icon and Title
                      Row(
                        children: [
                          if (step.icon != null) ...[
                            Icon(
                              step.icon,
                              size: 32,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: AppTheme.sizeSmall),
                          ],
                          Expanded(
                            child: Text(
                              step.title,
                              style: AppTheme.headlineSmall.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppTheme.sizeXSmall),

                      // Description
                      Text(
                        step.description,
                        style: AppTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Navigation buttons at bottom of screen - vertical layout
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.of(context).padding.bottom + AppTheme.sizeMedium,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Skip Tour button at top
                  Align(
                    alignment: Alignment.center,
                    child: OutlinedButton.icon(
                      onPressed: () async => await onSkip(),
                      icon: const Icon(Icons.close, size: 18),
                      label: Text(translationService.translate(SharedTranslationKeys.skipTour)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.sizeMedium,
                          vertical: AppTheme.sizeSmall,
                        ),
                        backgroundColor: AppTheme.surface1.withValues(alpha: 0.9),
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppTheme.sizeSmall),

                  // Previous and Next buttons in a row
                  Row(
                    children: [
                      // Previous button (always shown, disabled on first step)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _getPreviousButtonAction(isFirstStep, showBackButton, onBack, onPrevious),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.sizeMedium,
                              horizontal: AppTheme.sizeSmall,
                            ),
                            backgroundColor: AppTheme.surface1,
                            foregroundColor: AppTheme.primaryColor,
                            side: BorderSide(
                              color: isFirstStep && !(showBackButton && onBack != null)
                                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                  : AppTheme.primaryColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.arrow_back,
                                size: 18,
                                color: isFirstStep && !(showBackButton && onBack != null)
                                    ? AppTheme.primaryColor.withValues(alpha: 0.3)
                                    : null,
                              ),
                              const SizedBox(height: AppTheme.size4XSmall),
                              Text(
                                _getPreviousButtonText(isFirstStep, showBackButton, onBack),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isFirstStep && !(showBackButton && onBack != null)
                                      ? AppTheme.primaryColor.withValues(alpha: 0.3)
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: AppTheme.sizeXSmall),

                      // Next/Finish button
                      Expanded(
                        child: FilledButton(
                          onPressed: onNext,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.sizeMedium,
                              horizontal: AppTheme.sizeSmall,
                            ),
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: ColorContrastHelper.getContrastingTextColor(AppTheme.primaryColor),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                (isLastStep && isFinalPageOfTour) ? Icons.check : Icons.arrow_forward,
                                size: 18,
                              ),
                              const SizedBox(height: AppTheme.size4XSmall),
                              Text(
                                (isLastStep && isFinalPageOfTour) ? 'Finish' : 'Next',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Offset _getContentPosition(BuildContext context, Offset currentTargetPosition, Size currentTargetSize) {
    final screenSize = MediaQuery.sizeOf(context);
    final targetCenter = currentTargetPosition + Offset(currentTargetSize.width / 2, currentTargetSize.height / 2);

    // Calculate safe margins
    const horizontalMargin = 20.0;
    const verticalMargin = 20.0;
    final overlayWidth = screenSize.width * 0.9; // Matches the constraint
    final overlayHeight = 200.0; // Approximate height

    // Get bottom safe area inset for dynamic offset calculation
    const actionButtonHeight = 100;
    final bottomSafeArea = MediaQuery.of(context).padding.bottom + actionButtonHeight;

    // Calculate safe clamping bounds
    final minX = horizontalMargin;
    final maxX = (screenSize.width - overlayWidth - horizontalMargin).clamp(minX, screenSize.width - overlayWidth);
    final minY = verticalMargin;
    final maxY = (screenSize.height - overlayHeight - bottomSafeArea).clamp(minY, screenSize.height - overlayHeight);

    switch (step.position) {
      case TourPosition.top:
        final x = (targetCenter.dx - overlayWidth / 2).clamp(minX, maxX);
        final y = (currentTargetPosition.dy - overlayHeight - verticalMargin).clamp(minY, maxY);
        return Offset(x, y);

      case TourPosition.bottom:
        final x = (targetCenter.dx - overlayWidth / 2).clamp(minX, maxX);
        // For bottom position, ensure the card doesn't go below the safe area or overlap with buttons
        final adjustedY = (currentTargetPosition.dy + currentTargetSize.height + verticalMargin)
            .clamp(minY, screenSize.height - overlayHeight - bottomSafeArea);
        return Offset(x, adjustedY);

      case TourPosition.left:
        final x = (currentTargetPosition.dx - overlayWidth - horizontalMargin).clamp(minX, maxX);
        final y = (targetCenter.dy - overlayHeight / 2).clamp(minY, maxY);
        return Offset(x, y);

      case TourPosition.right:
        final x = (currentTargetPosition.dx + currentTargetSize.width + horizontalMargin).clamp(minX, maxX);
        final y = (targetCenter.dy - overlayHeight / 2).clamp(minY, maxY);
        return Offset(x, y);

      case TourPosition.center:
        return Offset(
          (screenSize.width - overlayWidth) / 2,
          (screenSize.height - overlayHeight) / 2,
        );
    }
  }

  /// Determines the action for the previous button based on tour context
  VoidCallback? _getPreviousButtonAction(
    bool isFirstStep,
    bool showBackButton,
    VoidCallback? onBack,
    VoidCallback onPrevious,
  ) {
    // If it's the first step and we're showing the back button with a back action,
    // use the back action (navigate to previous page)
    if (isFirstStep && showBackButton && onBack != null) {
      return onBack;
    }

    // Otherwise, if it's not the first step, use the previous step action
    if (!isFirstStep) {
      return onPrevious;
    }

    // If it's the first step but we don't have a back action, return null (disabled)
    return null;
  }

  /// Determines the text for the previous button based on tour context
  String _getPreviousButtonText(
    bool isFirstStep,
    bool showBackButton,
    VoidCallback? onBack,
  ) {
    // If it's the first step and we're showing the back button with a back action,
    // show "Back" text (navigate to previous page)
    if (isFirstStep && showBackButton && onBack != null) {
      return translationService.translate(SharedTranslationKeys.backButton);
    }

    // Otherwise, show "Previous" text
    return translationService.translate(SharedTranslationKeys.previousButton);
  }
}
