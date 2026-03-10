/// Interface for handling notification payloads
abstract class INotificationPayloadHandler {
  /// Handles a notification payload and performs the appropriate action
  Future<void> handlePayload(String? payload);

  /// Creates a standardized payload for navigation events
  String createNavigationPayload({
    required String route,
    Map<String, dynamic>? arguments,
  });
}
