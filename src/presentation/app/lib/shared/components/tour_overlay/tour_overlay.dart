import 'package:flutter/material.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';

import 'tour_step.dart';
import 'dim_overlay_painter.dart';
import 'tour_navigation_buttons.dart';
import 'tour_step_content.dart';
import 'tour_position_calculator.dart';

// Re-export for backward compatibility
export 'tour_step.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTourStep());
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  void _showTourStep() {
    final step = widget.steps[_currentStepIndex];
    final renderObject = step.targetKey?.currentContext?.findRenderObject();
    final renderBox = renderObject is RenderBox ? renderObject : null;
    final position = renderBox?.localToGlobal(Offset.zero);
    final size = renderBox?.size;

    if ((position == null || position == Offset.zero || size == null || size.isEmpty) && step.targetKey != null) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _showTourStep();
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
          translationService: widget.translationService,
        ),
      );

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
      setState(() => _currentStepIndex++);
      _showTourStep();
    } else {
      _completeTour();
    }
  }

  void _previousStep() {
    widget.steps[_currentStepIndex].onPrevious?.call();

    if (_currentStepIndex > 0) {
      setState(() => _currentStepIndex--);
      _showTourStep();
    }
  }

  Future<void> _skipTour() async {
    if (widget.onSkip != null) await widget.onSkip!();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _completeTour() {
    widget.onComplete?.call();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
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
    required this.translationService,
  });

  @override
  Widget build(BuildContext context) {
    final step = steps[currentStepIndex];
    final renderObject = step.targetKey?.currentContext?.findRenderObject();
    final renderBox = renderObject is RenderBox ? renderObject : null;
    final position = renderBox?.localToGlobal(Offset.zero);
    final size = renderBox?.size;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
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
    final bounds = TourPositionCalculator.getTargetBounds(
      step: step,
      fallbackPosition: targetPosition,
      fallbackSize: targetSize,
    );
    final borderDims = TourPositionCalculator.getBorderDimensions(
      step: step,
      targetPosition: bounds.position,
      targetSize: bounds.size,
      screenSize: screenSize,
    );
    final contentPosition = TourPositionCalculator.calculateContentPosition(
      context: context,
      step: step,
      targetPosition: bounds.position,
      targetSize: bounds.size,
    );

    return Stack(
      children: [
        // Dimmed background
        if (bounds.size != Size.zero && !step.highlightFullScreen)
          Positioned.fill(
            child: CustomPaint(
              painter: DimOverlayPainter(
                clearRect: Rect.fromLTWH(borderDims.left, borderDims.top, borderDims.width, borderDims.height),
                backgroundColor: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ),

        // Full screen background
        if (bounds.size == Size.zero || step.highlightFullScreen)
          Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.5))),

        // Highlighted area border
        if (bounds.size != Size.zero && !step.highlightFullScreen)
          Positioned(
            left: borderDims.left,
            top: borderDims.top,
            width: borderDims.width,
            height: borderDims.height,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primaryColor, width: 3),
                  borderRadius: step.shape == TourHighlightShape.circle
                      ? BorderRadius.circular(borderDims.width / 2)
                      : BorderRadius.circular(AppTheme.sizeSmall),
                ),
              ),
            ),
          ),

        // Tour content
        Positioned(
          left: contentPosition.dx,
          top: contentPosition.dy,
          child: GestureDetector(
            onTap: () {},
            behavior: HitTestBehavior.opaque,
            child: Material(
              type: MaterialType.transparency,
              child: TourStepContent(step: step, stepNumber: stepNumber, totalSteps: totalSteps),
            ),
          ),
        ),

        // Navigation buttons
        TourNavigationButtons(
          isFirstStep: isFirstStep,
          isLastStep: isLastStep,
          isFinalPageOfTour: isFinalPageOfTour,
          showBackButton: showBackButton,
          onNext: onNext,
          onPrevious: onPrevious,
          onSkip: onSkip,
          onBack: onBack,
          translationService: translationService,
        ),
      ],
    );
  }
}
