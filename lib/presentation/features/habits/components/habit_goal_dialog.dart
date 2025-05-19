import 'package:flutter/material.dart';
import 'package:whph/presentation/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

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
            onPressed: _hasGoal ? () => _adjustValue(isFrequency, -1) : null,
            tooltip: widget.translationService.translate(SharedTranslationKeys.deleteButton),
          ),
          const SizedBox(width: 4),
          Text('$value', style: AppTheme.bodyMedium),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _hasGoal ? () => _adjustValue(isFrequency, 1) : null,
            tooltip: widget.translationService.translate(SharedTranslationKeys.addButton),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.translationService.translate(HabitTranslationKeys.goalSettings)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Switch(
                value: _hasGoal,
                onChanged: (value) => setState(() => _hasGoal = value),
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
                description: 'kez',
                value: _targetFrequency,
                isFrequency: true,
              ),
              const SizedBox(height: 16),
              _buildNumberInput(
                title: widget.translationService.translate(HabitTranslationKeys.periodDays),
                description: 'gün',
                value: _periodDays,
                isFrequency: false,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.translationService.translate(SharedTranslationKeys.cancelButton)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(HabitGoalResult(
            hasGoal: _hasGoal,
            targetFrequency: _targetFrequency,
            periodDays: _periodDays,
          )),
          child: Text(widget.translationService.translate(SharedTranslationKeys.doneButton)),
        ),
      ],
    );
  }
}
