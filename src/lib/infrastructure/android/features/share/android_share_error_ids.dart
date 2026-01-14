/// Error IDs for Android share feature
/// Used for tracking and monitoring share-related errors in Sentry
class AndroidShareErrorIds {
  /// Error when platform method call fails
  static const String platformCallFailed = 'android_share_platform_call_failed';

  /// Error when getting initial share intent from native side fails
  static const String initialIntentFailed = 'android_share_initial_intent_failed';

  /// Error when acknowledging share intent to native side fails
  static const String acknowledgeFailed = 'android_share_acknowledge_failed';

  /// Error when creating task or note from shared text fails
  static const String itemCreationFailed = 'android_share_item_creation_failed';

  /// Error when app context is not available for showing dialog
  static const String contextUnavailable = 'android_share_context_unavailable';

  /// Error when overlay notification cannot be shown
  static const String notificationShowFailed = 'android_share_notification_show_failed';

  /// Error when timeout occurs waiting for context to be available
  static const String contextTimeout = 'android_share_context_timeout';
}
