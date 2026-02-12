import 'package:flutter/material.dart';
import 'package:whph/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/components/styled_icon.dart';

class HabitGoalResult {
  final bool hasGoal;
  final int targetFrequency;
  final int periodDays;
  final int dailyTarget;

  const HabitGoalResult({
    required this.hasGoal,
    this.targetFrequency = 1,
    this.periodDays = 1,
    this.dailyTarget = 1,
  });
}

class HabitGoalDialog extends StatefulWidget {
  final bool hasGoal;
  final int targetFrequency;
  final int periodDays;
  final int dailyTarget;
  final ITranslationService translationService;

  const HabitGoalDialog({
    required this.hasGoal,
    this.targetFrequency = 1,
    this.periodDays = 1,
    this.dailyTarget = 1,
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
  late int _dailyTarget;

  final _minValue = 1;
  final _maxValue = 99;

  @override
  void initState() {
    super.initState();
    _hasGoal = widget.hasGoal;
    _targetFrequency = widget.targetFrequency.clamp(_minValue, _maxValue);
    _periodDays = widget.periodDays.clamp(_minValue, _maxValue);
    _dailyTarget = widget.dailyTarget.clamp(_minValue, _maxValue);
  }

  void _adjustValue(String field, int delta) {
    setState(() {
      switch (field) {
        case 'frequency':
          _targetFrequency = (_targetFrequency + delta).clamp(_minValue, _maxValue);
          break;
        case 'period':
          _periodDays = (_periodDays + delta).clamp(_minValue, _maxValue);
          break;
        case 'daily':
          _dailyTarget = (_dailyTarget + delta).clamp(_minValue, _maxValue);
          break;
      }
    });
  }

  bool _canIncrementTargetFrequency() {
    if (!_hasGoal) return false;
    // Target frequency can only be incremented if it's less than max value AND would not exceed period days
    return _targetFrequency < _maxValue && (_targetFrequency + 1) <= _periodDays;
  }

  bool _canIncrementPeriodDays() {
    if (!_hasGoal) return false;
    // Period days can only be incremented if it's less than max value AND would stay greater than or equal to target frequency
    return _periodDays < _maxValue;
  }

  bool _canIncrementDailyTarget() {
    // Daily target can be incremented if goal is enabled and value is less than max
    if (!_hasGoal) return false;
    return _dailyTarget < _maxValue;
  }

  bool _canIncrement(String field) {
    switch (field) {
      case 'frequency':
        return _canIncrementTargetFrequency();
      case 'period':
        return _canIncrementPeriodDays();
      case 'daily':
        return _canIncrementDailyTarget();
      default:
        return false;
    }
  }

  bool _canDecrementTargetFrequency() {
    if (!_hasGoal) return false;
    // Target frequency can only be decremented if it's greater than min value
    return _targetFrequency > _minValue;
  }

  bool _canDecrementPeriodDays() {
    if (!_hasGoal) return false;
    // Period days can only be decremented if it's greater than min value AND would not be less than target frequency
    return _periodDays > _minValue && (_periodDays - 1) >= _targetFrequency;
  }

  bool _canDecrementDailyTarget() {
    // Daily target can be decremented if goal is enabled and value is greater than min
    if (!_hasGoal) return false;
    return _dailyTarget > _minValue;
  }

  bool _canDecrement(String field) {
    switch (field) {
      case 'frequency':
        return _canDecrementTargetFrequency();
      case 'period':
        return _canDecrementPeriodDays();
      case 'daily':
        return _canDecrementDailyTarget();
      default:
        return false;
    }
  }

  void _toggleGoal(bool value) {
    setState(() => _hasGoal = value);
  }

  String _getGoalDescription() {
    if (!_hasGoal) {
      return '$_dailyTarget ${widget.translationService.translate(HabitTranslationKeys.dailyTargetHint)}';
    }

    return '$_dailyTarget ${widget.translationService.translate(HabitTranslationKeys.dailyTargetHint)}, ${widget.translationService.translate(HabitTranslationKeys.goalFormat, namedArgs: {
          'count': _targetFrequency.toString(),
          'dayCount': _periodDays.toString(),
        })}';
  }

  Widget _buildNumberInput({
    required String sectionTitle,
    required String title,
    required String description,
    required int value,
    required String field,
    required IconData icon,
  }) {
    // All fields require goal to be enabled
    final isEnabled = _hasGoal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppTheme.sizeSmall, bottom: AppTheme.sizeSmall),
          child: Text(sectionTitle, style: AppTheme.labelLarge),
        ),
        Container(
          padding: const EdgeInsets.all(AppTheme.sizeLarge),
          decoration: BoxDecoration(
            color: AppTheme.surface1,
            borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
          ),
          child: Row(
            children: [
              StyledIcon(icon, isActive: isEnabled),
              const SizedBox(width: AppTheme.sizeLarge),
              Expanded(
                child: _buildInputContent(
                  title: title,
                  description: description,
                  value: value,
                  field: field,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputContent({
    required String title,
    required String description,
    required int value,
    required String field,
  }) {
    final isEnabled = _hasGoal;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.labelLarge),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppTheme.sizeLarge),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: isEnabled && _canDecrement(field) ? () => _adjustValue(field, -1) : null,
              tooltip: widget.translationService.translate(SharedTranslationKeys.deleteButton),
            ),
            const SizedBox(width: 4),
            Text('$value', style: AppTheme.bodyMedium),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: isEnabled && _canIncrement(field) ? () => _adjustValue(field, 1) : null,
              tooltip: widget.translationService.translate(SharedTranslationKeys.addButton),
            ),
          ],
        ),
      ],
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
      dailyTarget: _dailyTarget,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.translationService.translate(HabitTranslationKeys.goalSettings)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _cancelDialog,
          tooltip: widget.translationService.translate(SharedTranslationKeys.backButton),
        ),
        actions: [
          TextButton(
            onPressed: _confirmDialog,
            child: Text(
              widget.translationService.translate(SharedTranslationKeys.doneButton),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.sizeLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Goal Switch
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface1,
                  borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                ),
                child: SwitchListTile.adaptive(
                  value: _hasGoal,
                  onChanged: _toggleGoal,
                  title: Text(
                    widget.translationService.translate(HabitTranslationKeys.goal),
                    style: AppTheme.labelLarge,
                  ),
                  subtitle: _hasGoal
                      ? Text(
                          _getGoalDescription(),
                          style: AppTheme.bodySmall,
                        )
                      : Text(
                          widget.translationService.translate(HabitTranslationKeys.goalDescription),
                          style: AppTheme.bodySmall,
                        ),
                  secondary: StyledIcon(Icons.flag, isActive: _hasGoal),
                  contentPadding: const EdgeInsets.all(AppTheme.sizeMedium),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                  ),
                ),
              ),

              if (_hasGoal) ...[
                const SizedBox(height: AppTheme.sizeLarge),
                _buildNumberInput(
                  sectionTitle: widget.translationService.translate(HabitTranslationKeys.dailyTargetLabel),
                  title: widget.translationService.translate(HabitTranslationKeys.dailyTargetLabel),
                  description: widget.translationService.translate(HabitTranslationKeys.dailyTargetHint),
                  value: _dailyTarget,
                  field: 'daily',
                  icon: Icons.adjust,
                ),
                const SizedBox(height: AppTheme.sizeLarge),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: AppTheme.sizeSmall, bottom: AppTheme.sizeSmall),
                      child: Text(
                        widget.translationService.translate(HabitTranslationKeys.periodDays),
                        style: AppTheme.labelLarge,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.sizeLarge),
                      decoration: BoxDecoration(
                        color: AppTheme.surface1,
                        borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              StyledIcon(Icons.date_range, isActive: _hasGoal),
                              const SizedBox(width: AppTheme.sizeLarge),
                              Expanded(
                                child: _buildInputContent(
                                  title: widget.translationService.translate(HabitTranslationKeys.periodDays),
                                  description: widget.translationService.translate(HabitTranslationKeys.daysUnit),
                                  value: _periodDays,
                                  field: 'period',
                                ),
                              ),
                            ],
                          ),
                          if (_periodDays > 1) ...[
                            const SizedBox(height: AppTheme.sizeLarge),
                            Row(
                              children: [
                                StyledIcon(Icons.repeat, isActive: _hasGoal),
                                const SizedBox(width: AppTheme.sizeLarge),
                                Expanded(
                                  child: _buildInputContent(
                                    title: widget.translationService.translate(HabitTranslationKeys.targetFrequency),
                                    description: widget.translationService.translate(HabitTranslationKeys.timesUnit),
                                    value: _targetFrequency,
                                    field: 'frequency',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
