import 'package:flutter/material.dart';
import 'package:acore/acore.dart' as acore;
import 'package:acore/utils/dialog_size.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/tasks/components/custom_reminder_dialog.dart';

/// Configuration for TaskDatePickerDialog
class TaskDatePickerConfig {
  final DateTime? initialDate;
  final DateTime? minDate;
  final DateTime? maxDate;
  final String titleText;
  final String? singleDateTitle;
  final bool showTime;
  final bool showQuickRanges;
  final bool useResponsiveDesign;
  final bool enableFooterActions;
  final ReminderTime? initialReminderTime;
  final int? initialReminderCustomOffset;
  final ITranslationService? translationService;
  final DialogSize dialogSize;
  final acore.DateFormatType formatType;
  final BuildContext? context; // Add context parameter

  const TaskDatePickerConfig({
    this.initialDate,
    this.minDate,
    this.maxDate,
    required this.titleText,
    this.singleDateTitle,
    this.showTime = true,
    this.showQuickRanges = true,
    this.useResponsiveDesign = true,
    this.enableFooterActions = true,
    this.initialReminderTime,
    this.initialReminderCustomOffset,
    this.translationService,
    this.dialogSize = DialogSize.large,
    this.formatType = acore.DateFormatType.dateTime,
    this.context, // Add context parameter
  });

  /// Creates a copy of this TaskDatePickerConfig with the given fields replaced
  TaskDatePickerConfig copyWith({
    DateTime? initialDate,
    DateTime? minDate,
    DateTime? maxDate,
    String? titleText,
    String? singleDateTitle,
    bool? showTime,
    bool? showQuickRanges,
    bool? useResponsiveDesign,
    bool? enableFooterActions,
    ReminderTime? initialReminderTime,
    int? initialReminderCustomOffset,
    ITranslationService? translationService,
    DialogSize? dialogSize,
    acore.DateFormatType? formatType,
    BuildContext? context,
  }) {
    return TaskDatePickerConfig(
      initialDate: initialDate ?? this.initialDate,
      minDate: minDate ?? this.minDate,
      maxDate: maxDate ?? this.maxDate,
      titleText: titleText ?? this.titleText,
      singleDateTitle: singleDateTitle ?? this.singleDateTitle,
      showTime: showTime ?? this.showTime,
      showQuickRanges: showQuickRanges ?? this.showQuickRanges,
      useResponsiveDesign: useResponsiveDesign ?? this.useResponsiveDesign,
      enableFooterActions: enableFooterActions ?? this.enableFooterActions,
      initialReminderTime: initialReminderTime ?? this.initialReminderTime,
      initialReminderCustomOffset: initialReminderCustomOffset ?? this.initialReminderCustomOffset,
      translationService: translationService ?? this.translationService,
      dialogSize: dialogSize ?? this.dialogSize,
      formatType: formatType ?? this.formatType,
      context: context ?? this.context,
    );
  }
}

/// Result from TaskDatePickerDialog
class TaskDatePickerResult {
  final DateTime? selectedDate;
  final ReminderTime? reminderTime;
  final int? reminderCustomOffset;
  final bool wasCancelled;

  const TaskDatePickerResult({
    this.selectedDate,
    this.reminderTime,
    this.reminderCustomOffset,
    this.wasCancelled = false,
  });

  factory TaskDatePickerResult.cancelled() {
    return const TaskDatePickerResult(wasCancelled: true);
  }
}

/// Reusable task date picker dialog with configurable features
class TaskDatePickerDialog {
  /// Full-featured method for components that need reminder functionality
  static Future<TaskDatePickerResult?> showWithReminder({
    required BuildContext context,
    required TaskDatePickerConfig config,
  }) async {
    // Create ValueNotifier for dynamic updates
    final reminderNotifier = ValueNotifier<ReminderTime?>(config.initialReminderTime ?? ReminderTime.none);
    final customOffsetNotifier = ValueNotifier<int?>(config.initialReminderCustomOffset);

    try {
      final result = await _showDatePickerDialog(
        context: context,
        config: config.copyWith(context: context),
        reminderNotifier: reminderNotifier,
        customOffsetNotifier: customOffsetNotifier,
      );

      if (result != null && !result.wasCancelled) {
        return TaskDatePickerResult(
          selectedDate: result.selectedDate,
          reminderTime: reminderNotifier.value,
          reminderCustomOffset: customOffsetNotifier.value,
          wasCancelled: false,
        );
      } else {
        return TaskDatePickerResult.cancelled();
      }
    } finally {
      reminderNotifier.dispose();
      customOffsetNotifier.dispose();
    }
  }

  /// Simple method for components that don't need reminder functionality
  static Future<TaskDatePickerResult?> showSimple({
    required BuildContext context,
    required TaskDatePickerConfig config,
  }) async {
    final result = await _showDatePickerDialog(
      context: context,
      config: config.copyWith(context: context),
      reminderNotifier: null,
      customOffsetNotifier: null,
    );

    if (result != null && !result.wasCancelled) {
      return TaskDatePickerResult(
        selectedDate: result.selectedDate,
        reminderTime: null,
        reminderCustomOffset: null,
        wasCancelled: false,
      );
    } else {
      return TaskDatePickerResult.cancelled();
    }
  }

  /// Internal method that handles the actual dialog display
  static Future<acore.DatePickerResult?> _showDatePickerDialog({
    required BuildContext context,
    required TaskDatePickerConfig config,
    ValueNotifier<ReminderTime?>? reminderNotifier,
    ValueNotifier<int?>? customOffsetNotifier,
  }) async {
    if (config.useResponsiveDesign) {
      return await acore.DatePickerDialog.showResponsive(
        context: context,
        config: _buildDatePickerConfig(config, reminderNotifier, customOffsetNotifier),
      );
    } else {
      return await acore.DatePickerDialog.show(
        context: context,
        config: _buildDatePickerConfig(config, reminderNotifier, customOffsetNotifier),
      );
    }
  }

  /// Builds DatePickerConfig from TaskDatePickerConfig
  static acore.DatePickerConfig _buildDatePickerConfig(
    TaskDatePickerConfig config,
    ValueNotifier<ReminderTime?>? reminderNotifier,
    ValueNotifier<int?>? customOffsetNotifier,
  ) {
    final translationService = config.translationService;

    return acore.DatePickerConfig(
      dialogSize: config.dialogSize,
      selectionMode: acore.DateSelectionMode.single,
      initialDate: config.initialDate,
      minDate: config.minDate,
      maxDate: config.maxDate,
      showTime: config.showTime,
      showQuickRanges: config.showQuickRanges,
      useMobileScaffoldLayout: config.useResponsiveDesign,
      validationErrorAtTop: true,
      // quickRanges: null,
      singleDateTitle: config.singleDateTitle ?? config.titleText,
      titleText: config.titleText,
      doneButtonText: translationService?.translate(SharedTranslationKeys.doneButton),
      cancelButtonText: translationService?.translate(SharedTranslationKeys.cancelButton),
      footerActions: config.enableFooterActions && reminderNotifier != null
          ? _buildFooterActions(reminderNotifier, customOffsetNotifier, translationService, config.context)
          : null,
      formatType: config.formatType,
      translations: _buildTranslations(translationService),
    );
  }

  /// Builds footer actions for reminder functionality
  static List<acore.DatePickerFooterAction> _buildFooterActions(
    ValueNotifier<ReminderTime?> reminderNotifier,
    ValueNotifier<int?>? customOffsetNotifier,
    ITranslationService? translationService,
    BuildContext? context, // Add context parameter
  ) {
    return [
      acore.DatePickerFooterAction(
        icon: () => _getReminderIcon(reminderNotifier.value),
        label: () => _getReminderLabel(reminderNotifier.value, translationService, customOffsetNotifier?.value),
        onPressed: () async {
          if (context == null) return;
          final result = await showReminderSelectionDialog(
            context, // Pass the context parameter
            reminderNotifier.value,
            translationService,
            customOffsetNotifier?.value,
          );
          if (result != null) {
            reminderNotifier.value = result.reminderTime;
            if (customOffsetNotifier != null) {
              customOffsetNotifier.value = result.customOffset;
            }
          }
        },
        color: () => _getReminderColor(reminderNotifier.value),
        isPrimary: false,
      ),
    ];
  }

  /// Builds translation mappings for the date picker
  static Map<acore.DateTimePickerTranslationKey, String> _buildTranslations(
    ITranslationService? translationService,
  ) {
    if (translationService == null) return {};

    return {
      acore.DateTimePickerTranslationKey.confirm: translationService.translate(SharedTranslationKeys.doneButton),
      acore.DateTimePickerTranslationKey.cancel: translationService.translate(SharedTranslationKeys.cancelButton),
      acore.DateTimePickerTranslationKey.setTime: translationService.translate(SharedTranslationKeys.change),
      acore.DateTimePickerTranslationKey.selectTimeTitle: translationService
          .translate(SharedTranslationKeys.mapDateTimePickerKey(acore.DateTimePickerTranslationKey.selectTimeTitle)),
      acore.DateTimePickerTranslationKey.selectedTime: translationService
          .translate(SharedTranslationKeys.mapDateTimePickerKey(acore.DateTimePickerTranslationKey.selectedTime)),
      acore.DateTimePickerTranslationKey.allDay: translationService.translate(SharedTranslationKeys.allDay),
      // Quick selection translations
      acore.DateTimePickerTranslationKey.quickSelectionToday: translationService.translate(SharedTranslationKeys.today),
      acore.DateTimePickerTranslationKey.quickSelectionTomorrow:
          translationService.translate(TaskTranslationKeys.tomorrow),
      acore.DateTimePickerTranslationKey.quickSelectionWeekend:
          translationService.translate(TaskTranslationKeys.weekend),
      acore.DateTimePickerTranslationKey.quickSelectionNextWeekday:
          translationService.translate(TaskTranslationKeys.nextWeekday),
      acore.DateTimePickerTranslationKey.quickSelectionNextWeek:
          translationService.translate(TaskTranslationKeys.nextWeek),
      acore.DateTimePickerTranslationKey.quickSelectionNoDate:
          translationService.translate(SharedTranslationKeys.notSetTime),
      acore.DateTimePickerTranslationKey.quickSelectionLastWeek:
          translationService.translate(SharedTranslationKeys.lastWeek),
      acore.DateTimePickerTranslationKey.quickSelectionLastMonth:
          translationService.translate(SharedTranslationKeys.lastMonth),
      // Time picker unit translations
      acore.DateTimePickerTranslationKey.weekdayMonShort:
          translationService.translate(SharedTranslationKeys.weekDayMonShort),
      acore.DateTimePickerTranslationKey.weekdayTueShort:
          translationService.translate(SharedTranslationKeys.weekDayTueShort),
      acore.DateTimePickerTranslationKey.weekdayWedShort:
          translationService.translate(SharedTranslationKeys.weekDayWedShort),
      acore.DateTimePickerTranslationKey.weekdayThuShort:
          translationService.translate(SharedTranslationKeys.weekDayThuShort),
      acore.DateTimePickerTranslationKey.weekdayFriShort:
          translationService.translate(SharedTranslationKeys.weekDayFriShort),
      acore.DateTimePickerTranslationKey.weekdaySatShort:
          translationService.translate(SharedTranslationKeys.weekDaySatShort),
      acore.DateTimePickerTranslationKey.weekdaySunShort:
          translationService.translate(SharedTranslationKeys.weekDaySunShort),
      // Time picker hour/minute labels
      acore.DateTimePickerTranslationKey.timePickerHourLabel:
          translationService.translate(SharedTranslationKeys.timePickerHourLabel),
      acore.DateTimePickerTranslationKey.timePickerMinuteLabel:
          translationService.translate(SharedTranslationKeys.timePickerMinuteLabel),
      acore.DateTimePickerTranslationKey.timePickerAllDayLabel:
          translationService.translate(SharedTranslationKeys.allDay),
      // Validation translations
      acore.DateTimePickerTranslationKey.selectedDateMustBeAtOrAfter:
          translationService.translate(SharedTranslationKeys.selectedDateMustBeAtOrAfter),
      acore.DateTimePickerTranslationKey.selectedDateMustBeAtOrBefore:
          translationService.translate(SharedTranslationKeys.selectedDateMustBeAtOrBefore),
    };
  }

  /// Shows reminder selection dialog
  static Future<ReminderSelectionResult?> showReminderSelectionDialog(
    BuildContext context,
    ReminderTime? currentReminder,
    ITranslationService? translationService,
    int? currentCustomOffset,
  ) async {
    final child = Scaffold(
      appBar: AppBar(
        title: Text(
          translationService?.translate(TaskTranslationKeys.reminderPlannedLabel) ?? 'Set Reminder',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: ReminderTime.values.map((reminderTime) {
          final isSelected = currentReminder == reminderTime;
          return ListTile(
            leading: Icon(
              _getReminderIcon(reminderTime),
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            title: Text(
              _getReminderLabel(reminderTime, translationService, currentCustomOffset),
              style: TextStyle(
                color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
            onTap: () async {
              if (reminderTime == ReminderTime.custom) {
                final customMinutes = await CustomReminderDialog.show(
                  context,
                  translationService!,
                  initialMinutes: currentCustomOffset,
                );

                if (customMinutes != null && context.mounted) {
                  Navigator.of(context).pop(ReminderSelectionResult(
                    reminderTime: ReminderTime.custom,
                    customOffset: customMinutes,
                  ));
                }
              } else {
                Navigator.of(context).pop(ReminderSelectionResult(reminderTime: reminderTime));
              }
            },
          );
        }).toList(),
      ),
    );

    return await ResponsiveDialogHelper.showResponsiveDialog<ReminderSelectionResult>(
      context: context,
      child: child,
      size: DialogSize.medium,
      isScrollable: true,
      isDismissible: true,
      enableDrag: true,
    );
  }

  /// Gets icon for reminder time
  static IconData _getReminderIcon(ReminderTime? reminderTime) {
    switch (reminderTime) {
      case ReminderTime.none:
        return Icons.notifications_off_outlined;
      case ReminderTime.atTime:
        return Icons.access_time;
      case ReminderTime.fiveMinutesBefore:
      case ReminderTime.fifteenMinutesBefore:
      case ReminderTime.oneHourBefore:
      case ReminderTime.oneDayBefore:
        return Icons.notifications_active;
      case ReminderTime.custom:
        return Icons.edit_notifications;
      case null:
        return Icons.notifications_off_outlined;
    }
  }

  /// Gets label for reminder time
  static String _getReminderLabel(ReminderTime? reminderTime, ITranslationService? translationService,
      [int? customOffset]) {
    switch (reminderTime) {
      case ReminderTime.none:
        return translationService?.translate(TaskTranslationKeys.reminderNone) ?? 'None';
      case ReminderTime.atTime:
        return translationService?.translate(TaskTranslationKeys.reminderAtTime) ?? 'At time';
      case ReminderTime.fiveMinutesBefore:
        return translationService?.translate(TaskTranslationKeys.reminderFiveMinutesBefore) ?? '5 minutes before';
      case ReminderTime.fifteenMinutesBefore:
        return translationService?.translate(TaskTranslationKeys.reminderFifteenMinutesBefore) ?? '15 minutes before';
      case ReminderTime.oneHourBefore:
        return translationService?.translate(TaskTranslationKeys.reminderOneHourBefore) ?? '1 hour before';
      case ReminderTime.oneDayBefore:
        return translationService?.translate(TaskTranslationKeys.reminderOneDayBefore) ?? '1 day before';
      case ReminderTime.custom:
        if (customOffset != null && translationService != null) {
          if (customOffset % (60 * 24 * 7) == 0) {
            final weeks = customOffset ~/ (60 * 24 * 7);
            return '$weeks ${translationService.translate(TaskTranslationKeys.weeks)} ${translationService.translate(TaskTranslationKeys.reminderBeforeSuffix)}';
          } else if (customOffset % (60 * 24) == 0) {
            final days = customOffset ~/ (60 * 24);
            return '$days ${translationService.translate(TaskTranslationKeys.days)} ${translationService.translate(TaskTranslationKeys.reminderBeforeSuffix)}';
          } else if (customOffset % 60 == 0) {
            final hours = customOffset ~/ 60;
            return '$hours ${translationService.translate(TaskTranslationKeys.hours)} ${translationService.translate(TaskTranslationKeys.reminderBeforeSuffix)}';
          } else {
            return '$customOffset ${translationService.translate(TaskTranslationKeys.minutes)} ${translationService.translate(TaskTranslationKeys.reminderBeforeSuffix)}';
          }
        }
        return translationService?.translate(TaskTranslationKeys.reminderCustom) ?? 'Custom';
      case null:
        return translationService?.translate(TaskTranslationKeys.reminderNone) ?? 'None';
    }
  }

  /// Gets color for reminder time
  static Color _getReminderColor(ReminderTime? reminderTime) {
    if (reminderTime == null || reminderTime == ReminderTime.none) {
      // Return a neutral color since we don't have context
      return Colors.grey;
    } else {
      // Return a primary color indicating active reminder
      return Colors.blue;
    }
  }
}

class ReminderSelectionResult {
  final ReminderTime reminderTime;
  final int? customOffset;

  const ReminderSelectionResult({
    required this.reminderTime,
    this.customOffset,
  });
}
