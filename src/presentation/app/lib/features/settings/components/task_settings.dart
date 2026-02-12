import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:application/features/settings/queries/get_setting_query.dart';
import 'package:domain/features/settings/setting.dart';
import 'package:domain/features/tasks/task_constants.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:whph/main.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/constants/setting_keys.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/features/settings/components/task_settings/default_estimated_time_setting.dart';
import 'package:whph/features/settings/components/task_settings/default_reminder_setting.dart';
import 'package:whph/features/settings/components/task_settings/skip_quick_add_setting.dart';
import 'package:whph/shared/components/loading_overlay.dart';
import 'package:whph/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/shared/utils/async_error_handler.dart';

class TaskSettings extends StatefulWidget {
  final VoidCallback? onLoaded;

  const TaskSettings({
    super.key,
    this.onLoaded,
  });

  @override
  State<TaskSettings> createState() => _TaskSettingsState();
}

class _TaskSettingsState extends State<TaskSettings> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

  bool _isLoading = true;
  int? _defaultEstimatedTime;
  ReminderTime? _defaultPlannedDateReminder;
  int? _defaultPlannedDateReminderCustomOffset;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await AsyncErrorHandler.executeWithLoading(
      context: context,
      setLoading: (isLoading) => setState(() {
        _isLoading = isLoading;
      }),
      errorMessage: _translationService.translate(SettingsTranslationKeys.taskDefaultEstimatedTimeLoadError),
      operation: () async {
        // Load Default Estimated Time
        try {
          final setting = await _mediator.send<GetSettingQuery, Setting?>(
            GetSettingQuery(key: SettingKeys.taskDefaultEstimatedTime),
          );

          if (setting != null) {
            _defaultEstimatedTime = setting.getValue<int?>();
          } else {
            _defaultEstimatedTime = TaskConstants.defaultEstimatedTime;
          }
        } catch (_) {
          // Setting not found or error, use default
          _defaultEstimatedTime = TaskConstants.defaultEstimatedTime;
        }

        // Load Default Planned Date Reminder
        try {
          final reminderSetting = await _mediator.send<GetSettingQuery, Setting?>(
            GetSettingQuery(key: SettingKeys.taskDefaultPlannedDateReminder),
          );

          if (reminderSetting != null) {
            final value = reminderSetting.getValue<String>();
            _defaultPlannedDateReminder = ReminderTimeExtension.fromString(value);
          } else {
            _defaultPlannedDateReminder = TaskConstants.defaultReminderTime;
          }
        } catch (_) {
          _defaultPlannedDateReminder = TaskConstants.defaultReminderTime;
        }

        // Load Default Planned Date Reminder Custom Offset
        try {
          final reminderOffsetSetting = await _mediator.send<GetSettingQuery, Setting?>(
            GetSettingQuery(key: SettingKeys.taskDefaultPlannedDateReminderCustomOffset),
          );

          if (reminderOffsetSetting != null) {
            _defaultPlannedDateReminderCustomOffset = reminderOffsetSetting.getValue<int?>();
          } else {
            _defaultPlannedDateReminderCustomOffset = null;
          }
        } catch (_) {
          _defaultPlannedDateReminderCustomOffset = null;
        }

        setState(() {});
        return true;
      },
      onSuccess: (_) {
        widget.onLoaded?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      title: _translationService.translate(SettingsTranslationKeys.taskSettingsTitle),
      showBackButton: true,
      hideSidebar: true,
      showLogo: false,
      builder: (context) => LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DefaultEstimatedTimeSetting(initialValue: _defaultEstimatedTime),
              const SizedBox(height: AppTheme.sizeMedium),
              DefaultReminderSetting(
                initialValue: _defaultPlannedDateReminder,
                initialCustomOffset: _defaultPlannedDateReminderCustomOffset,
              ),
              const SizedBox(height: AppTheme.sizeMedium),
              const SkipQuickAddSetting(),
            ],
          ),
        ),
      ),
    );
  }
}
