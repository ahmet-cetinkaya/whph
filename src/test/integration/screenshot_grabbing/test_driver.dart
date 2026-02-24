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
  'no': 'no-NO',
  'pl': 'pl-PL',
  'pt': 'pt-PT',
  'ro': 'ro',
  'ru': 'ru-RU',
  'sl': 'sl',
  'sv': 'sv-SE',
  'tr': 'tr-TR',
  'uk': 'uk',
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

  final isDesktop = const bool.fromEnvironment('DESKTOP_SCREENSHOT', defaultValue: false);

  String screenshotsPath;
  if (isDesktop) {
    screenshotsPath = '../packaging/screenshots/desktop/$fastlaneFolder';
  } else {
    screenshotsPath = '../fastlane/metadata/android/$fastlaneFolder/images/phoneScreenshots';
  }

  final screenshotsDir = Directory(screenshotsPath);
  if (!await screenshotsDir.exists()) {
    await screenshotsDir.create(recursive: true);
  }

  print('📍 Generating screenshots for locale: $locale -> ${isDesktop ? 'desktop' : fastlaneFolder}');

  await integrationDriver(
    onScreenshot: (String screenshotName, List<int> screenshotBytes, [Map<String, Object?>? args]) async {
      final imagePath = '$screenshotsPath/$screenshotName.png';

      if (isDesktop) {
        // Use scrot to capture the active window with shadows and decorations
        print('📸 Taking desktop window screenshot: $imagePath');
        try {
          final result = await Process.run('scrot', [
            '-u', // active window
            '-b', // with window border
            imagePath, // Output file
          ]);

          if (result.exitCode != 0) {
            print('⚠️ scrot error: ${result.stderr}');
          }
        } catch (e) {
          print('⚠️ Failed to run scrot: $e');
        }
      } else {
        final File image = File(imagePath);
        await image.writeAsBytes(screenshotBytes);
      }

      print('📸 Screenshot saved: $imagePath');
      return true;
    },
  );
}
