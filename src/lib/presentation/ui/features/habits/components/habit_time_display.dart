import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/queries/get_total_duration_by_habit_id_query.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class HabitTimeDisplay extends StatefulWidget {
  final String habitId;
  final bool showActualTime;
  final DateTime? targetDate; // Defaults to today if not provided

  const HabitTimeDisplay({
    super.key,
    required this.habitId,
    this.showActualTime = true,
    this.targetDate,
  });

  @override
  State<HabitTimeDisplay> createState() => _HabitTimeDisplayState();
}

class _HabitTimeDisplayState extends State<HabitTimeDisplay> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _habitRepository = container.resolve<IHabitRepository>();

  int _actualTime = 0;
  int _estimatedTime = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTimeData();
  }

  @override
  void didUpdateWidget(HabitTimeDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.habitId != widget.habitId || oldWidget.targetDate != widget.targetDate) {
      _loadTimeData();
    }
  }

  Future<void> _loadTimeData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final targetDate = widget.targetDate ?? DateTime.now();
      final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final endOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

      // Get actual tracked time
      final actualTimeResponse =
          await _mediator.send<GetTotalDurationByHabitIdQuery, GetTotalDurationByHabitIdQueryResponse>(
        GetTotalDurationByHabitIdQuery(
          habitId: widget.habitId,
          startDate: startOfDay,
          endDate: endOfDay,
        ),
      );

      // Get habit details for estimated time calculation
      final habit = await _habitRepository.getById(widget.habitId);
      final estimatedTimeMinutes = habit?.estimatedTime ?? 0;

      if (mounted) {
        setState(() {
          _actualTime = actualTimeResponse.totalDuration;
          _estimatedTime = estimatedTimeMinutes * 60; // Convert to seconds
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _actualTime = 0;
          _estimatedTime = 0;
          _isLoading = false;
        });
      }
    }
  }

  String _getTimeDisplayText() {
    if (_isLoading) {
      return '...';
    }

    if (widget.showActualTime && _actualTime > 0) {
      // Show actual tracked time
      return SharedUiConstants.formatDurationHuman(_actualTime, _translationService);
    } else if (_estimatedTime > 0) {
      // Show estimated time with indicator
      final estimatedDisplay = SharedUiConstants.formatDurationHuman(_estimatedTime, _translationService);
      return '~$estimatedDisplay (${_translationService.translate(SharedTranslationKeys.timeDisplayEstimated)})';
    } else {
      // No time tracked or estimated
      return SharedUiConstants.formatDurationHuman(0, _translationService);
    }
  }

  String _getTooltipText() {
    if (_isLoading) return '';

    if (widget.showActualTime && _actualTime > 0) {
      return _translationService.translate(SharedTranslationKeys.timeDisplayElapsedTimeTooltip);
    } else if (_estimatedTime > 0) {
      return _translationService.translate(SharedTranslationKeys.timeDisplayEstimated);
    } else {
      return _translationService.translate(SharedTranslationKeys.timeDisplayNoTimeLoggedTooltip);
    }
  }

  Color _getTextColor() {
    if (_isLoading) return Theme.of(context).colorScheme.onSurface;

    if (widget.showActualTime && _actualTime > 0) {
      return Theme.of(context).colorScheme.primary; // Actual time in primary color
    } else if (_estimatedTime > 0) {
      return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7); // Estimated time in muted color
    } else {
      return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5); // No time in very muted color
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _getTooltipText(),
      child: Text(
        _getTimeDisplayText(),
        style: AppTheme.bodyMedium.copyWith(
          color: _getTextColor(),
          fontWeight: (_actualTime > 0 && widget.showActualTime) ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
