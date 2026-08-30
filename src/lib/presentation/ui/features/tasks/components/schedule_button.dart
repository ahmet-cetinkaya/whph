import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/providers/drag_state_provider.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Options for scheduling a task
enum ScheduleOption {
  today,
  tomorrow,
}

/// A dropdown button component for scheduling tasks
class ScheduleButton extends StatefulWidget {
  final ITranslationService translationService;
  final Function(DateTime date) onScheduleSelected;
  final bool isDense;
  final DateTime? currentPlannedDate;

  const ScheduleButton({
    super.key,
    required this.translationService,
    required this.onScheduleSelected,
    this.isDense = false,
    this.currentPlannedDate,
  });

  @override
  State<ScheduleButton> createState() => _ScheduleButtonState();
}

class _ScheduleButtonState extends State<ScheduleButton> {
  final OverlayPortalController _tooltipController = OverlayPortalController();
  DragStateNotifier? _dragStateNotifier;

  String _getScheduleOptionLabel(ScheduleOption option) {
    switch (option) {
      case ScheduleOption.today:
        return widget.translationService.translate(TaskTranslationKeys.taskScheduleToday);
      case ScheduleOption.tomorrow:
        return widget.translationService.translate(TaskTranslationKeys.taskScheduleTomorrow);
    }
  }

  DateTime _getDateForOption(ScheduleOption option) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Check if current planned date is "All Day" (00:00)
    final isAllDay = widget.currentPlannedDate != null &&
        widget.currentPlannedDate!.hour == 0 &&
        widget.currentPlannedDate!.minute == 0;

    // If All Day, return just the date without time component
    if (isAllDay) {
      switch (option) {
        case ScheduleOption.today:
          return today;
        case ScheduleOption.tomorrow:
          return today.add(const Duration(days: 1));
      }
    }

    // Otherwise, use the time component
    final timeToUse = _getTimeToUse();

    switch (option) {
      case ScheduleOption.today:
        return DateTime(today.year, today.month, today.day, timeToUse.hour, timeToUse.minute);
      case ScheduleOption.tomorrow:
        final tomorrow = today.add(const Duration(days: 1));
        return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, timeToUse.hour, timeToUse.minute);
    }
  }

  /// Gets the time to use for scheduling
  /// If currentPlannedDate exists, use its time (convert from UTC to local)
  /// Otherwise, use 9:00 AM as default
  DateTime _getTimeToUse() {
    if (widget.currentPlannedDate != null) {
      // Convert UTC to local time to preserve the user's intended time
      final localPlannedDate = widget.currentPlannedDate!.toLocal();
      return localPlannedDate;
    }
    // Default to 9:00 AM
    return DateTime(0, 1, 1, 9, 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextDragStateNotifier = DragStateProvider.of(context);
    if (identical(nextDragStateNotifier, _dragStateNotifier)) return;

    _dragStateNotifier?.removeListener(_handleDragStateChange);
    _dragStateNotifier = nextDragStateNotifier;
    _dragStateNotifier?.addListener(_handleDragStateChange);
    _handleDragStateChange();
  }

  void _handleDragStateChange() {
    if ((_dragStateNotifier?.isDragging ?? false) && _tooltipController.isShowing) {
      _tooltipController.hide();
    }
  }

  @override
  void dispose() {
    _dragStateNotifier?.removeListener(_handleDragStateChange);
    super.dispose();
  }

  Widget _buildTooltipOverlay(BuildContext context, OverlayChildLayoutInfo layoutInfo, String message) {
    if (layoutInfo.childPaintTransform.determinant() == 0.0) {
      return const SizedBox.shrink();
    }

    final target = MatrixUtils.transformPoint(
      layoutInfo.childPaintTransform,
      layoutInfo.childSize.center(Offset.zero),
    );
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Positioned.fill(
      bottom: MediaQuery.maybeViewInsetsOf(context)?.bottom ?? 0,
      child: CustomSingleChildLayout(
        delegate: _ScheduleTooltipPositionDelegate(target: target),
        child: IgnorePointer(
          child: Container(
            constraints: const BoxConstraints(minHeight: 24),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.grey[700]!).withValues(alpha: 0.9),
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.black : Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tooltipMessage = widget.translationService.translate(TaskTranslationKeys.taskScheduleTooltip);
    final isDragging = _dragStateNotifier?.isDragging ?? false;
    final button = PopupMenuButton<ScheduleOption>(
      // PopupMenuButton delegates this value to IconButton.tooltip. Keep it
      // empty so Flutter does not create an unsafe localToGlobal tooltip.
      tooltip: '',
      icon: Icon(
        Icons.schedule,
        color: AppTheme.secondaryTextColor,
        size: widget.isDense ? AppTheme.iconSizeSmall : AppTheme.iconSizeMedium,
      ),
      onSelected: (ScheduleOption option) {
        final date = _getDateForOption(option);
        widget.onScheduleSelected(date);
      },
      itemBuilder: (BuildContext context) => ScheduleOption.values.map((option) {
        return PopupMenuItem<ScheduleOption>(
          value: option,
          child: Row(
            children: [
              Icon(
                option == ScheduleOption.today ? Icons.today : Icons.event,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(_getScheduleOptionLabel(option)),
            ],
          ),
        );
      }).toList(),
    );

    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _tooltipController,
      overlayChildBuilder: (context, layoutInfo) =>
          isDragging ? const SizedBox.shrink() : _buildTooltipOverlay(context, layoutInfo, tooltipMessage),
      child: MouseRegion(
        onEnter: isDragging ? null : (_) => _tooltipController.show(),
        onExit: (_) => _tooltipController.hide(),
        child: Listener(
          onPointerDown: (_) => _tooltipController.hide(),
          child: Semantics(tooltip: tooltipMessage, child: button),
        ),
      ),
    );
  }
}

class _ScheduleTooltipPositionDelegate extends SingleChildLayoutDelegate {
  const _ScheduleTooltipPositionDelegate({required this.target});

  final Offset target;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) => positionDependentBox(
        size: size,
        childSize: childSize,
        target: target,
        verticalOffset: 24,
        preferBelow: true,
      );

  @override
  bool shouldRelayout(_ScheduleTooltipPositionDelegate oldDelegate) => target != oldDelegate.target;
}
