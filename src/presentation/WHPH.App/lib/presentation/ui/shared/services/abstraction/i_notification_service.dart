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

class NotificationOptions {
  final String? actionButtonText;
  final String? channelId;

  const NotificationOptions({
    this.actionButtonText,
    this.channelId,
  });
}
