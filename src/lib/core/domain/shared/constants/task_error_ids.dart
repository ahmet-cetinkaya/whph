/// Error IDs for task-related errors.
///
/// These IDs are used for Sentry tracking and monitoring to enable
/// efficient error aggregation and alerting.
///
/// Usage:
/// ```dart
/// Logger.error('Message with context',
///   error: e,
///   stackTrace: stackTrace,
///   component: DomainLogComponents.task,
/// );
/// // Include error ID in message: "[task_recurrence_config_invalid_json]"
/// ```
///
/// Note: The Logger.error() method doesn't have an errorId parameter yet,
/// so error IDs should be included in the message string in brackets.
class TaskErrorIds {
  // ======================================================================
  // Recurrence Configuration Errors
  // ======================================================================

  /// Invalid JSON syntax in recurrence_configuration data
  static const String recurrenceConfigInvalidJson = 'task_recurrence_config_invalid_json';

  /// Invalid data structure for recurrence_configuration
  static const String recurrenceConfigInvalidStructure = 'task_recurrence_config_invalid_structure';

  /// Unexpected error during recurrence_configuration deserialization
  static const String recurrenceConfigDeserializeError = 'task_recurrence_config_deserialize_error';

  // ======================================================================
  // Lock Errors
  // ======================================================================

  /// Lock stream closed unexpectedly
  static const String recurrenceLockStreamClosed = 'task_recurrence_lock_stream_closed';

  /// Unexpected error waiting for lock stream
  static const String recurrenceLockStreamError = 'task_recurrence_lock_stream_error';

  /// Timeout waiting for recurrence lock acquisition
  static const String recurrenceLockTimeout = 'task_recurrence_lock_timeout';

  // ======================================================================
  // Recurrence Creation Errors
  // ======================================================================

  /// Task state changed during recurrence processing (expected in some scenarios)
  static const String recurrenceTaskStateChanged = 'task_recurrence_task_state_changed';

  /// Failed to create recurring task instance
  static const String recurrenceCreateInstanceFailed = 'task_recurrence_create_instance_failed';

  /// State error during recurrence creation
  static const String recurrenceStateError = 'task_recurrence_state_error';

  /// Failed to create recurring task instance (legacy ID)
  static const String recurrenceCreationFailed = 'task_recurrence_creation_failed';

  /// Error checking for duplicate recurrence
  static const String recurrenceDuplicateCheckError = 'task_recurrence_duplicate_check_error';

  // ======================================================================
  // Task Errors
  // ======================================================================

  /// Invalid completedAt date format
  static const String taskCompletedAtInvalidFormat = 'task_completed_at_invalid_format';

  /// Duplicate task cleanup failed
  static const String taskDuplicateCleanupFailed = 'task_duplicate_cleanup_failed';

  // ======================================================================
  // Reminder Calculation Errors
  // ======================================================================

  /// Error calculating reminder datetime
  static const String reminderCalculateDateTimeFailed = 'task_reminder_calculate_datetime_failed';

  /// Error getting next reminder occurrence
  static const String reminderGetNextOccurrenceFailed = 'task_reminder_get_next_occurrence_failed';

  /// Error checking if reminder should trigger
  static const String reminderShouldTriggerCheckFailed = 'task_reminder_should_trigger_check_failed';

  // ======================================================================
  // Save Command Errors
  // ======================================================================

  /// Error getting default estimated time setting
  static const String saveCommandDefaultEstimatedTimeFailed = 'task_save_command_default_estimated_time_failed';

  /// Error getting default planned date reminder setting
  static const String saveCommandDefaultPlannedDateReminderFailed =
      'task_save_command_default_planned_date_reminder_failed';

  /// Error getting default planned date reminder custom offset
  static const String saveCommandDefaultReminderCustomOffsetFailed =
      'task_save_command_default_reminder_custom_offset_failed';

  // ======================================================================
  // Repository Errors
  // ======================================================================

  /// Failed to cleanup duplicate tasks in background
  static const String repositoryDuplicateCleanupFailed = 'task_repository_duplicate_cleanup_failed';

  // ======================================================================
  // Private constructor to prevent instantiation
  // ======================================================================

  TaskErrorIds._();
}
