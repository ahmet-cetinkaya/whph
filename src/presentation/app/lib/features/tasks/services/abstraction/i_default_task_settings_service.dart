import 'package:domain/features/tasks/task.dart';

/// Service interface for loading default task settings from persistent storage.
/// Provides centralized access to default estimated time and reminder settings
/// used across task creation flows.
abstract class IDefaultTaskSettingsService {
  /// Loads the default estimated time for tasks from settings.
  /// Returns null if no default is configured or on error.
  Future<int?> getDefaultEstimatedTime();

  /// Loads the default planned date reminder settings.
  /// Returns a tuple of [ReminderTime] and optional custom offset.
  /// Defaults to [TaskConstants.defaultReminderTime] if no setting is found.
  Future<(ReminderTime reminderTime, int? customOffset)> getDefaultPlannedDateReminder();
}
