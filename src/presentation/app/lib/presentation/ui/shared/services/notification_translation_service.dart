import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/background_translation_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

/// Enhanced translation service for notifications that ensures translations work in background contexts
class NotificationTranslationService {
  final ITranslationService _translationService;
  final BackgroundTranslationService _backgroundService;

  NotificationTranslationService(this._translationService) : _backgroundService = BackgroundTranslationService();

  /// Initialize the notification translation service
  Future<void> initialize() async {
    await _backgroundService.initialize();
  }

  /// Translate with robust fallback for notification contexts
  String translate(String key, {Map<String, String>? namedArgs}) {
    try {
      // First try the main translation service (works when EasyLocalization is available)
      final mainTranslation = _translationService.translate(key, namedArgs: namedArgs);

      // If it returned something other than the key, it worked
      if (mainTranslation != key) {
        return mainTranslation;
      }

      // If main service failed, try background service
      final backgroundTranslation = _backgroundService.translate(key, namedArgs: namedArgs);
      if (backgroundTranslation != key) {
        DomainLogger.debug('NotificationTranslationService: Used background translation for key: $key');
        return backgroundTranslation;
      }

      // Both failed, log and return key
      DomainLogger.warning('NotificationTranslationService: No translation found for key: $key');
      return key;
    } catch (e) {
      // If there's any error, try background service as final fallback
      DomainLogger.error('NotificationTranslationService: Error in main translation, using background fallback: $e');

      try {
        final backgroundTranslation = _backgroundService.translate(key, namedArgs: namedArgs);
        return backgroundTranslation != key ? backgroundTranslation : key;
      } catch (e2) {
        DomainLogger.error('NotificationTranslationService: Background translation also failed: $e2');
        return key;
      }
    }
  }

  /// Get current locale from background service
  String get currentLocale => _backgroundService.currentLocale;

  /// Pre-translate notification strings to ensure they work when scheduled
  NotificationStrings preTranslateNotificationStrings({
    required String titleKey,
    required String bodyKey,
    Map<String, String>? titleArgs,
    Map<String, String>? bodyArgs,
  }) {
    final title = translate(titleKey, namedArgs: titleArgs);
    final body = translate(bodyKey, namedArgs: bodyArgs);

    return NotificationStrings(
      title: title,
      body: body,
      originalTitleKey: titleKey,
      originalBodyKey: bodyKey,
    );
  }
}

/// Container for pre-translated notification strings
class NotificationStrings {
  final String title;
  final String body;
  final String originalTitleKey;
  final String originalBodyKey;

  const NotificationStrings({
    required this.title,
    required this.body,
    required this.originalTitleKey,
    required this.originalBodyKey,
  });

  /// Check if translations were successful (didn't return the keys)
  bool get isTranslated => title != originalTitleKey && body != originalBodyKey;

  @override
  String toString() {
    return 'NotificationStrings(title: $title, body: $body, translated: $isTranslated)';
  }
}
