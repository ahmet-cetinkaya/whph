import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:infrastructure_android/constants/android_app_constants.dart';
import 'package:domain/shared/utils/logger.dart';

/// Callback type for handling shared text
typedef SharedTextCallback = Future<void> Function(String text, String? subject);

/// Service responsible for handling share intents from Android
class AndroidShareService {
  /// Sets up the share intent listener for Android platform
  static void setupShareListener({
    SharedTextCallback? onSharedText,
  }) {
    if (!Platform.isAndroid) {
      DomainLogger.debug('AndroidShareService: Not Android platform, skipping share listener setup');
      return;
    }

    DomainLogger.debug('AndroidShareService: Setting up Android share listener...');

    final platform = MethodChannel(AndroidAppConstants.channels.share);
    platform.setMethodCallHandler((call) async {
      try {
        switch (call.method) {
          case 'onSharedText':
            final args = call.arguments as Map?;
            if (args != null) {
              final text = args['text'] as String?;
              final subject = args['subject'] as String?;
              if (text != null && text.isNotEmpty && onSharedText != null) {
                await onSharedText(text, subject);
              }
            }
            break;
          default:
            DomainLogger.warning('AndroidShareService: Unknown method call: ${call.method}');
        }
      } catch (e, stackTrace) {
        DomainLogger.error('AndroidShareService: Error handling platform call: ${call.method}',
            error: e, stackTrace: stackTrace);
      }
      return null;
    });

    DomainLogger.debug('AndroidShareService: Android share listener setup completed');
  }

  /// Handles the initial share intent when the app is launched from a share
  static Future<({String text, String? subject})?> getInitialShareIntent() async {
    DomainLogger.debug('AndroidShareService: Checking for initial share intent...');

    if (!Platform.isAndroid) {
      return null;
    }

    try {
      final platform = MethodChannel(AndroidAppConstants.channels.share);
      final result = await platform.invokeMethod<Map<dynamic, dynamic>>('getInitialShareIntent');

      if (result != null) {
        final text = result['text'] as String?;
        final subject = result['subject'] as String?;

        if (text != null && text.isNotEmpty) {
          DomainLogger.debug('AndroidShareService: Found initial share intent: text="$text", subject="$subject"');
          return (text: text, subject: subject);
        }
      }

      DomainLogger.debug('AndroidShareService: No initial share intent found');
      return null;
    } catch (e) {
      DomainLogger.error('AndroidShareService: Error getting initial share intent: $e');
      return null;
    }
  }

  /// Acknowledges receipt of share intent to the native side
  static Future<void> acknowledgeShareIntent() async {
    try {
      if (Platform.isAndroid) {
        final platform = MethodChannel(AndroidAppConstants.channels.share);
        await platform.invokeMethod('acknowledgeShareIntent');
        DomainLogger.debug('AndroidShareService: Acknowledged share intent');
      }
    } catch (e) {
      DomainLogger.error('AndroidShareService: Error acknowledging share intent: $e');
    }
  }

  /// Extracts a title from shared text
  /// Returns the first line (up to 50 chars) as title, and the remainder as description
  static (String title, String? description) extractTitleFromText(String text) {
    const int maxTitleLength = 50;

    // Split by newlines and get the first line
    final lines = text.split('\n');
    final firstLineOriginal = lines.isNotEmpty ? lines[0] : '';
    final firstLine = firstLineOriginal.trim();

    if (firstLine.isEmpty) {
      // Find the first non-empty line as the title candidate
      String effectiveTitleCandidate = '';
      int titleLineEndIndex = -1;
      for (int i = 0; i < lines.length; i++) {
        final trimmedLine = lines[i].trim();
        if (trimmedLine.isNotEmpty) {
          effectiveTitleCandidate = trimmedLine;
          // Calculate end index in original text to determine description start
          titleLineEndIndex = text.indexOf(lines[i]) + lines[i].length;
          break;
        }
      }

      if (effectiveTitleCandidate.isEmpty) {
        // If no non-empty line found, use a truncated version of the whole text
        final fallbackTitle = text.trim();
        if (fallbackTitle.length > maxTitleLength) {
          return ('${fallbackTitle.substring(0, maxTitleLength)}...', null);
        }
        return (fallbackTitle, null);
      }

      // Use the effective title candidate for subsequent processing
      String title = effectiveTitleCandidate;

      // Strip leading and trailing quotes from the title
      if (title.startsWith('"') && title.endsWith('"')) {
        title = title.substring(1, title.length - 1);
      } else if (title.startsWith("'") && title.endsWith("'")) {
        title = title.substring(1, title.length - 1);
      }
      title = title.trim();

      // If first line is longer than max length, truncate it
      if (title.length > maxTitleLength) {
        return ('${title.substring(0, maxTitleLength)}...', null);
      }

      // Use the text after the effective title line for description
      if (titleLineEndIndex >= 0 && titleLineEndIndex < text.length) {
        final description = text.substring(titleLineEndIndex).trim();
        return (title, description.isNotEmpty ? description : null);
      }

      return (title, null);
    }

    // Strip leading and trailing quotes from the title
    String title = firstLine;
    if (title.startsWith('"') && title.endsWith('"')) {
      title = title.substring(1, title.length - 1);
    } else if (title.startsWith("'") && title.endsWith("'")) {
      title = title.substring(1, title.length - 1);
    }
    title = title.trim();

    // If first line is longer than max length, truncate it
    if (title.length > maxTitleLength) {
      return ('${title.substring(0, maxTitleLength)}...', null);
    }

    // If there's more content after the first line, include it as description
    if (lines.length > 1) {
      final description = text.substring(firstLineOriginal.length).trim();
      return (title, description.isNotEmpty ? description : null);
    }

    return (title, null);
  }
}
