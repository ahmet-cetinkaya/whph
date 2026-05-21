abstract class INotificationService {
  /// Initialize the notification service
  Future<void> init();

  /// Clean up resources when the service is no longer needed
  Future<void> destroy();

  /// Show an immediate notification
  ///
  /// [title] - Title of the notification
  /// [body] - Body text of the notification
  /// [payload] - Optional data to pass with the notification
  /// [id] - Optional unique identifier for the notification
  /// [options] - Optional platform specific options
  Future<void> show({
    required String title,
    required String body,
    String? payload,
    int? id,
    NotificationOptions? options,
  });

  /// Clear all active notifications
  Future<void> clearAll();

  /// Check if notifications are enabled in app settings
  Future<bool> isEnabled();

  /// Enable or disable notifications in app settings
  Future<void> setEnabled(bool enabled);

  /// Check if the app has permission to display notifications
  /// Returns true if permission is granted, false otherwise
  Future<bool> checkPermissionStatus();

  /// Request permission to display notifications from the user
  /// Returns true if permission is granted, false otherwise
  Future<bool> requestPermission();

  /// Handle task completion from notification action button
  /// Mobile platforms (Android/iOS) should implement this to process task completions
  /// Desktop platforms provide a no-op implementation
  Future<void> handleNotificationTaskCompletion(String taskId);

  /// Handle habit completion from notification action button
  /// Mobile platforms (Android/iOS) should implement this to process habit completions
  /// Desktop platforms provide a no-op implementation
  Future<void> handleNotificationHabitCompletion(String habitId);
}

class NotificationAction {
  final String id;
  final String title;
  final bool showsUserInterface;

  NotificationAction(
    this.id,
    this.title, {
    this.showsUserInterface = false,
  }) {
    if (id.isEmpty) {
      throw ArgumentError('NotificationAction id cannot be empty');
    }
    if (title.isEmpty) {
      throw ArgumentError('NotificationAction title cannot be empty');
    }
  }
}

class NotificationOptions {
  final String? actionButtonText;
  final String? channelId;
  final List<NotificationAction>? actions;
  final bool ongoing;

  NotificationOptions({
    this.actionButtonText,
    this.channelId,
    List<NotificationAction>? actions,
    this.ongoing = false,
  }) : actions = actions != null ? List.unmodifiable(actions) : null {
    if (this.actions != null && this.actions!.length > 3) {
      throw ArgumentError('Maximum 3 actions allowed for notifications');
    }
  }
}
