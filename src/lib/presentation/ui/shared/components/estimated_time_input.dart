import 'package:acore/acore.dart' as acore;
import 'package:acore/utils/dialog_size.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// A comfortable estimated time input. Shows the current value as a tappable
/// summary field; tapping opens a wheel picker for days / hours / minutes.
class EstimatedTimeInput extends StatelessWidget {
  final int totalMinutes;
  final ValueChanged<int> onValueChanged;

  const EstimatedTimeInput({
    super.key,
    this.totalMinutes = 0,
    required this.onValueChanged,
  });

  Future<void> _openPicker(BuildContext context) async {
    final result = await acore.ResponsiveDialogHelper.showResponsiveDialog<int>(
      context: context,
      size: DialogSize.small,
      child: _EstimatedTimePickerSheet(initialMinutes: totalMinutes),
    );

    if (result != null) onValueChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    final theme = Theme.of(context);
    final label = SharedUiConstants.formatDurationHuman(totalMinutes, translationService);

    return InkWell(
      onTap: () => _openPicker(context),
      borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(
            top: AppTheme.sizeSmall, bottom: AppTheme.sizeSmall, left: AppTheme.sizeXLarge, right: AppTheme.sizeMedium),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.edit_outlined,
              size: AppTheme.iconSizeSmall,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _EstimatedTimePickerSheet extends StatefulWidget {
  final int initialMinutes;

  const _EstimatedTimePickerSheet({required this.initialMinutes});

  @override
  State<_EstimatedTimePickerSheet> createState() => _EstimatedTimePickerSheetState();
}

class _EstimatedTimePickerSheetState extends State<_EstimatedTimePickerSheet> {
  static const int _maxDays = 7;
  static const int _minutesPerDay = 1440;

  late int _days;
  late int _hours;
  late int _minutes;

  @override
  void initState() {
    super.initState();
    final clamped = widget.initialMinutes.clamp(0, _maxDays * _minutesPerDay - 1);
    _days = clamped ~/ _minutesPerDay;
    final remaining = clamped % _minutesPerDay;
    _hours = remaining ~/ 60;
    _minutes = remaining % 60;
  }

  int get _total => (_days * _minutesPerDay + _hours * 60 + _minutes).clamp(0, _maxDays * _minutesPerDay - 1);

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.sizeMedium, AppTheme.sizeMedium, AppTheme.sizeMedium, 0),
          child: Row(
            children: [
              Text(
                translationService.translate(SharedTranslationKeys.timeDisplayEstimated),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(_total),
                child: Text(
                  translationService.translate(SharedTranslationKeys.doneButton),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: Row(
            children: [
              Expanded(
                child: _WheelColumn(
                  label: translationService.translate(SharedTranslationKeys.days),
                  itemCount: _maxDays + 1,
                  selectedValue: _days,
                  onChanged: (value) => setState(() => _days = value),
                ),
              ),
              Expanded(
                child: _WheelColumn(
                  label: translationService.translate(SharedTranslationKeys.hours),
                  itemCount: 24,
                  selectedValue: _hours,
                  onChanged: (value) => setState(() => _hours = value),
                ),
              ),
              Expanded(
                child: _WheelColumn(
                  label: translationService.translate(SharedTranslationKeys.minutes),
                  itemCount: 60,
                  selectedValue: _minutes,
                  onChanged: (value) => setState(() => _minutes = value),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WheelColumn extends StatefulWidget {
  final String label;
  final int itemCount;
  final int selectedValue;
  final ValueChanged<int> onChanged;

  const _WheelColumn({
    required this.label,
    required this.itemCount,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  State<_WheelColumn> createState() => _WheelColumnState();
}

class _WheelColumnState extends State<_WheelColumn> {
  static const double _itemExtent = 40.0;

  late final FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: widget.selectedValue);
  }

  @override
  void didUpdateWidget(_WheelColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedValue != widget.selectedValue) {
      _controller.animateToItem(
        widget.selectedValue,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          widget.label,
          style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        Expanded(
          child: Stack(
            children: [
              Center(
                child: Container(
                  height: _itemExtent,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.sizeSmall),
                  ),
                ),
              ),
              ScrollConfiguration(
                behavior: _MouseEnabledScrollBehavior(),
                child: ListWheelScrollView.useDelegate(
                  controller: _controller,
                  itemExtent: _itemExtent,
                  squeeze: 1.2,
                  diameterRatio: 1.5,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: widget.onChanged,
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: widget.itemCount,
                    builder: (context, index) {
                      final isSelected = index == widget.selectedValue;
                      return Center(
                        child: Text(
                          index.toString().padLeft(2, '0'),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MouseEnabledScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
        PointerDeviceKind.mouse,
      };
}
