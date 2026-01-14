/// Error IDs for task-related errors used for Sentry tracking and monitoring.
/// Include error IDs in Logger.error() messages in brackets: "[task_completion_failed]"
class TaskErrorIds {
  // Recurrence Configuration Errors
  static const String recurrenceConfigInvalidJson = 'task_recurrence_config_invalid_json';
  static const String recurrenceConfigInvalidStructure = 'task_recurrence_config_invalid_structure';
  static const String recurrenceConfigDeserializeError = 'task_recurrence_config_deserialize_error';

  // Lock Errors
  static const String recurrenceLockStreamClosed = 'task_recurrence_lock_stream_closed';
  static const String recurrenceLockStreamError = 'task_recurrence_lock_stream_error';
  static const String recurrenceLockTimeout = 'task_recurrence_lock_timeout';

  // Recurrence Creation Errors
  static const String recurrenceTaskStateChanged = 'task_recurrence_task_state_changed';
  static const String recurrenceCreateInstanceFailed = 'task_recurrence_create_instance_failed';
  static const String recurrenceStateError = 'task_recurrence_state_error';
  static const String recurrenceCreationFailed = 'task_recurrence_creation_failed';
  static const String recurrenceDuplicateCheckError = 'task_recurrence_duplicate_check_error';

  // Task Errors
  static const String taskCompletedAtInvalidFormat = 'task_completed_at_invalid_format';
  static const String taskDuplicateCleanupFailed = 'task_duplicate_cleanup_failed';
  static const String taskCompletionFailed = 'task_completion_failed';
  static const String taskNotFound = 'task_not_found';
  static const String taskAlreadyCompleted = 'task_already_completed';

  // Notification Action Errors
  static const String notificationActionFailed = 'notification_action_failed';
  static const String pendingTaskProcessingFailed = 'pending_task_processing_failed';
  static const String pendingTaskMaxRetriesExceeded = 'pending_task_max_retries_exceeded';

  // Gesture Errors
  static const String swipeGestureFailed = 'swipe_gesture_failed';

  // Reminder Calculation Errors
  static const String reminderCalculateDateTimeFailed = 'task_reminder_calculate_datetime_failed';
  static const String reminderGetNextOccurrenceFailed = 'task_reminder_get_next_occurrence_failed';
  static const String reminderShouldTriggerCheckFailed = 'task_reminder_should_trigger_check_failed';

  // Save Command Errors
  static const String saveCommandDefaultEstimatedTimeFailed = 'task_save_command_default_estimated_time_failed';
  static const String saveCommandDefaultPlannedDateReminderFailed =
      'task_save_command_default_planned_date_reminder_failed';
  static const String saveCommandDefaultReminderCustomOffsetFailed =
      'task_save_command_default_reminder_custom_offset_failed';

  // Repository Errors
  static const String repositoryDuplicateCleanupFailed = 'task_repository_duplicate_cleanup_failed';

  TaskErrorIds._();
}
