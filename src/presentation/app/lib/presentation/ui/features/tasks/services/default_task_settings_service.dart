import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:domain/features/settings/setting.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:domain/features/tasks/task_constants.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/features/tasks/services/abstraction/i_default_task_settings_service.dart';

/// Implementation of default task settings service using Mediator pattern.
/// Caches settings for performance and logs errors for debugging.
class DefaultTaskSettingsService implements IDefaultTaskSettingsService {
  final Mediator _mediator;
  final ILogger _logger;

  int? _cachedEstimatedTime;
  (ReminderTime, int?)? _cachedPlannedDateReminder;
  bool _estimatedTimeCacheLoaded = false;
  bool _plannedDateReminderCacheLoaded = false;

  DefaultTaskSettingsService(this._mediator, this._logger);

  @override
  Future<int?> getDefaultEstimatedTime() async {
    if (_estimatedTimeCacheLoaded && _cachedEstimatedTime != null) {
      return _cachedEstimatedTime;
    }

    try {
      final setting = await _mediator.send<GetSettingQuery, Setting?>(
        GetSettingQuery(key: SettingKeys.taskDefaultEstimatedTime),
      );

      if (setting != null) {
        final value = setting.getValue<int?>();
        if (value != null && value > 0) {
          _cachedEstimatedTime = value;
          _estimatedTimeCacheLoaded = true;
          return value;
        }
      }

      _estimatedTimeCacheLoaded = true;
      return null;
    } catch (e, stackTrace) {
      _logger.error('Failed to load default estimated time setting', e, stackTrace);
      _estimatedTimeCacheLoaded = true;
      return null;
    }
  }

  @override
  Future<(ReminderTime reminderTime, int? customOffset)> getDefaultPlannedDateReminder() async {
    if (_plannedDateReminderCacheLoaded && _cachedPlannedDateReminder != null) {
      return _cachedPlannedDateReminder!;
    }

    try {
      final setting = await _mediator.send<GetSettingQuery, Setting?>(
        GetSettingQuery(key: SettingKeys.taskDefaultPlannedDateReminder),
      );

      ReminderTime reminderTime;
      int? customOffset;

      if (setting != null) {
        final value = setting.getValue<String>();
        reminderTime = ReminderTimeExtension.fromString(value);

        if (reminderTime == ReminderTime.custom) {
          final offsetSetting = await _mediator.send<GetSettingQuery, Setting?>(
            GetSettingQuery(key: SettingKeys.taskDefaultPlannedDateReminderCustomOffset),
          );
          if (offsetSetting != null) {
            customOffset = offsetSetting.getValue<int?>();
          }
        }
      } else {
        reminderTime = TaskConstants.defaultReminderTime;
      }

      final result = (reminderTime, customOffset);
      _cachedPlannedDateReminder = result;
      _plannedDateReminderCacheLoaded = true;
      return result;
    } catch (e, stackTrace) {
      _logger.error('Failed to load default planned date reminder setting', e, stackTrace);
      _plannedDateReminderCacheLoaded = true;
      return (TaskConstants.defaultReminderTime, null);
    }
  }

  /// Clears cached settings, forcing a reload on next access.
  /// Useful when settings may have been updated externally.
  void clearCache() {
    _estimatedTimeCacheLoaded = false;
    _plannedDateReminderCacheLoaded = false;
    _cachedEstimatedTime = null;
    _cachedPlannedDateReminder = null;
  }
}
