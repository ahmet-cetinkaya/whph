// ignore_for_file: avoid_print

import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

/// Locale to fastlane folder mapping (matches actual folders in fastlane/metadata/android/)
const Map<String, String> localeFolderMap = {
  'cs': 'cs-CZ',
  'da': 'da-DK',
  'de': 'de-DE',
  'el': 'el-GR',
  'en': 'en-US',
  'es': 'es-ES',
  'fi': 'fi-FI',
  'fr': 'fr-FR',
  'it': 'it-IT',
  'ja': 'ja-JP',
  'ko': 'ko-KR',
  'nl': 'nl-NL',
  'no': 'no',
  'pl': 'pl-PL',
  'pt': 'pt-PT',
  'ro': 'ro-RO',
  'ru': 'ru-RU',
  'sl': 'sl-SI',
  'sv': 'sv-SE',
  'tr': 'tr-TR',
  'uk': 'uk-UA',
  'zh': 'zh-CN',
};

/// Test driver entry point for Flutter integration tests.
///
/// Screenshots are saved to the fastlane screenshots directory for the specified locale.
/// Pass locale via SCREENSHOT_LOCALE environment variable (default: en).
Future<void> main() async {
  // Get locale from environment variable
  final locale = Platform.environment['SCREENSHOT_LOCALE'] ?? 'en';
  final fastlaneFolder = localeFolderMap[locale] ?? 'en-US';

  // Create fastlane screenshots directory for this locale
  final screenshotsPath = '../fastlane/metadata/android/$fastlaneFolder/images/phoneScreenshots';
  final screenshotsDir = Directory(screenshotsPath);
  if (!await screenshotsDir.exists()) {
    await screenshotsDir.create(recursive: true);
  }

  print('📍 Generating screenshots for locale: $locale -> $fastlaneFolder');

  await integrationDriver(
    onScreenshot: (String screenshotName, List<int> screenshotBytes, [Map<String, Object?>? args]) async {
      final File image = File('$screenshotsPath/$screenshotName.png');
      await image.writeAsBytes(screenshotBytes);
      print('📸 Screenshot saved: $screenshotsPath/$screenshotName.png');
      return true;
    },
  );
}
