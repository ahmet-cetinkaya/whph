import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';

class HabitGoalResult {
  final bool hasGoal;
  final int targetFrequency;
  final int periodDays;

  const HabitGoalResult({
    required this.hasGoal,
    this.targetFrequency = 1,
    this.periodDays = 7,
  });
}

class HabitGoalDialog extends StatefulWidget {
  final bool hasGoal;
  final int targetFrequency;
  final int periodDays;
  final ITranslationService translationService;

  const HabitGoalDialog({
    required this.hasGoal,
    this.targetFrequency = 1,
    this.periodDays = 7,
    required this.translationService,
    super.key,
  });

  @override
  State<HabitGoalDialog> createState() => _HabitGoalDialogState();
}

class _HabitGoalDialogState extends State<HabitGoalDialog> {
  late bool _hasGoal;
  late int _targetFrequency;
  late int _periodDays;

  final _minValue = 1;
  final _maxValue = 99;

  @override
  void initState() {
    super.initState();
    _hasGoal = widget.hasGoal;
    _targetFrequency = widget.targetFrequency.clamp(_minValue, _maxValue);
    _periodDays = widget.periodDays.clamp(_minValue, _maxValue);
  }

  void _adjustValue(bool isFrequency, int delta) {
    setState(() {
      if (isFrequency) {
        _targetFrequency = (_targetFrequency + delta).clamp(_minValue, _maxValue);
      } else {
        _periodDays = (_periodDays + delta).clamp(_minValue, _maxValue);
      }
    });
  }

  bool _canIncrementTargetFrequency() {
    if (!_hasGoal) return false;
    // Target frequency can only be incremented if it's less than max value AND would not equal period days
    return _targetFrequency < _maxValue && (_targetFrequency + 1) < _periodDays;
  }

  bool _canIncrementPeriodDays() {
    if (!_hasGoal) return false;
    // Period days can only be incremented if it's less than max value AND would stay greater than target frequency
    return _periodDays < _maxValue && (_periodDays + 1) > _targetFrequency;
  }

  bool _canIncrement(bool isFrequency) {
    if (isFrequency) {
      return _canIncrementTargetFrequency();
    } else {
      return _canIncrementPeriodDays();
    }
  }

  bool _canDecrementTargetFrequency() {
    if (!_hasGoal) return false;
    // Target frequency can only be decremented if it's greater than min value
    return _targetFrequency > _minValue;
  }

  bool _canDecrementPeriodDays() {
    if (!_hasGoal) return false;
    // Period days can only be decremented if it's greater than min value AND would not equal target frequency
    return _periodDays > _minValue && (_periodDays - 1) > _targetFrequency;
  }

  bool _canDecrement(bool isFrequency) {
    if (isFrequency) {
      return _canDecrementTargetFrequency();
    } else {
      return _canDecrementPeriodDays();
    }
  }

  void _toggleGoal(bool value) {
    setState(() => _hasGoal = value);
  }

  String _getGoalDescription() {
    if (!_hasGoal) {
      return widget.translationService.translate(HabitTranslationKeys.enableGoals);
    }

    return widget.translationService.translate(HabitTranslationKeys.goalFormat, namedArgs: {
      'count': _targetFrequency.toString(),
      'dayCount': _periodDays.toString(),
    });
  }

  Widget _buildNumberInput({
    required String title,
    required String description,
    required int value,
    required bool isFrequency,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: _hasGoal,
      title: Text(title),
      subtitle: Text(
        description,
        style: AppTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: _hasGoal && _canDecrement(isFrequency) ? () => _adjustValue(isFrequency, -1) : null,
            tooltip: widget.translationService.translate(SharedTranslationKeys.deleteButton),
          ),
          const SizedBox(width: 4),
          Text('$value', style: AppTheme.bodyMedium),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _hasGoal && _canIncrement(isFrequency) ? () => _adjustValue(isFrequency, 1) : null,
            tooltip: widget.translationService.translate(SharedTranslationKeys.addButton),
          ),
        ],
      ),
    );
  }

  void _cancelDialog() {
    Navigator.of(context).pop();
  }

  void _confirmDialog() {
    Navigator.of(context).pop(HabitGoalResult(
      hasGoal: _hasGoal,
      targetFrequency: _targetFrequency,
      periodDays: _periodDays,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.translationService.translate(HabitTranslationKeys.goalSettings)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Goal description
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.translationService.translate(HabitTranslationKeys.goalDescription),
                      style: AppTheme.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Switch(
                value: _hasGoal,
                onChanged: _toggleGoal,
              ),
              title: Text(widget.translationService.translate(HabitTranslationKeys.goal)),
              subtitle: Text(
                _getGoalDescription(),
                style: AppTheme.bodySmall,
              ),
            ),
            if (_hasGoal) ...[
              const SizedBox(height: 16),
              _buildNumberInput(
                title: widget.translationService.translate(HabitTranslationKeys.targetFrequency),
                description: widget.translationService.translate(HabitTranslationKeys.timesUnit),
                value: _targetFrequency,
                isFrequency: true,
              ),
              const SizedBox(height: 16),
              _buildNumberInput(
                title: widget.translationService.translate(HabitTranslationKeys.periodDays),
                description: widget.translationService.translate(HabitTranslationKeys.daysUnit),
                value: _periodDays,
                isFrequency: false,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _cancelDialog,
          child: Text(widget.translationService.translate(SharedTranslationKeys.cancelButton)),
        ),
        FilledButton(
          onPressed: _confirmDialog,
          child: Text(widget.translationService.translate(SharedTranslationKeys.doneButton)),
        ),
      ],
    );
  }
}
