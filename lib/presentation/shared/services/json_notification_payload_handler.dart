import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:whph/infrastructure/features/notification/abstractions/i_notification_payload_handler.dart';

/// Implementation of the notification payload handler that uses JSON payloads
class JsonNotificationPayloadHandler implements INotificationPayloadHandler {
  final GlobalKey<NavigatorState> _navigatorKey;

  // Track handled payload IDs to prevent duplicate navigation
  final Set<String> _handledPayloadHashes = {};

  JsonNotificationPayloadHandler(this._navigatorKey);

  @override
  Future<void> handlePayload(String? payload) async {
    debugPrint('JsonNotificationPayloadHandler: Handling payload: $payload');

    if (payload == null || payload.isEmpty) {
      debugPrint('JsonNotificationPayloadHandler: Payload is null or empty');
      return;
    }

    // Generate a unique hash for this payload to track if we've handled it already
    final payloadHash = _generatePayloadHash(payload);

    // Check if we've already handled this exact payload recently
    if (_handledPayloadHashes.contains(payloadHash)) {
      debugPrint('JsonNotificationPayloadHandler: Payload already handled, skipping');
      return;
    }

    // Try to get the current context
    final context = _navigatorKey.currentContext;
    if (context == null) {
      // If context is null, try again after a delay
      debugPrint('JsonNotificationPayloadHandler: Context is null, will retry after delay');
      await Future.delayed(const Duration(milliseconds: 500));
      return handlePayload(payload); // Recursive call with same payload
    }

    try {
      // Parse payload as JSON
      final Map<String, dynamic> payloadData = json.decode(payload);

      // Standard route navigation
      if (payloadData.containsKey('route')) {
        // Navigate with a slight delay to ensure app is ready
        await Future.microtask(() {
          if (context.mounted) _navigate(payloadData, context);
          // Mark this payload as handled to prevent duplicate navigation
          _handledPayloadHashes.add(payloadHash);

          // Clean up old handled payloads after some time
          _schedulePayloadCleanup(payloadHash);
        });
      } else {
        debugPrint('JsonNotificationPayloadHandler: Navigation payload missing route parameter');
      }
    } catch (e) {
      debugPrint('JsonNotificationPayloadHandler: Error parsing payload: $e');
      // Try to handle non-JSON payloads as a fallback
      if (context.mounted) _handleLegacyPayload(payload, context);

      // Still mark this payload as handled
      _handledPayloadHashes.add(payloadHash);
      _schedulePayloadCleanup(payloadHash);
    }
  }

  void _navigate(Map<String, dynamic> payloadData, BuildContext context) {
    final String route = payloadData['route'] as String;
    final Map<String, dynamic>? arguments = payloadData['arguments'] as Map<String, dynamic>?;

    debugPrint('JsonNotificationPayloadHandler: Navigating to route: $route with arguments: $arguments');

    // Make sure we pop any dialogs before navigation
    Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);

    // Use pushNamedAndRemoveUntil to clear the navigation stack and start fresh
    Navigator.of(context).pushNamedAndRemoveUntil(
      route,
      (route) => false, // Remove all previous routes
      arguments: arguments,
    );
  }

  /// Handle legacy payload formats for backwards compatibility
  void _handleLegacyPayload(String payload, BuildContext context) {
    debugPrint('JsonNotificationPayloadHandler: Attempting to handle as legacy payload');
    // This could handle older payload formats if needed
    // Example: if payload starts with "/tasks" or contains simple identifiers

    if (payload.startsWith('/')) {
      // Looks like a route, try to navigate
      Navigator.of(context).pushNamedAndRemoveUntil(
        payload,
        (route) => false,
      );
    }
  }

  /// Generate a unique hash for a payload to track if we've handled it
  String _generatePayloadHash(String payload) {
    try {
      // For JSON payloads, we can check the actual content
      final Map<String, dynamic> data = json.decode(payload);
      final String route = data['route'] as String? ?? '';
      final arguments = data['arguments'] != null ? json.encode(data['arguments']) : '';

      // Create a unique hash based on route and arguments
      return '${route}_${arguments}_${DateTime.now().minute}';
    } catch (_) {
      // For non-JSON payloads, just use the payload itself
      return '${payload}_${DateTime.now().minute}';
    }
  }

  /// Schedule cleanup of handled payload hashes to prevent memory leaks
  void _schedulePayloadCleanup(String payloadHash) {
    // Clean up this payload hash after 10 seconds to prevent memory leaks
    // while still preventing duplicate navigation during a reasonable window
    Future.delayed(const Duration(seconds: 10), () {
      _handledPayloadHashes.remove(payloadHash);
    });
  }

  /// Create a standard navigation payload
  @override
  String createNavigationPayload({
    required String route,
    Map<String, dynamic>? arguments,
  }) {
    final Map<String, dynamic> payload = {
      'route': route,
      if (arguments != null) 'arguments': arguments,
    };

    return json.encode(payload);
  }
}
