// ignore_for_file: avoid_print

import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

/// Test driver entry point for Flutter integration tests.
///
/// This file enables running integration tests via `flutter drive`:
/// ```
/// flutter drive \
///   --driver=test_driver/integration_test.dart \
///   --target=integration_test/screenshot_test.dart
/// ```
///
/// Screenshots are saved to the fastlane screenshots directory.
Future<void> main() async {
  // Create fastlane screenshots directory
  const screenshotsPath = '../fastlane/metadata/android/en-US/images/phoneScreenshots';
  final screenshotsDir = Directory(screenshotsPath);
  if (!await screenshotsDir.exists()) {
    await screenshotsDir.create(recursive: true);
  }

  await integrationDriver(
    onScreenshot: (String screenshotName, List<int> screenshotBytes, [Map<String, Object?>? args]) async {
      final File image = File('$screenshotsPath/$screenshotName.png');
      await image.writeAsBytes(screenshotBytes);
      print('📸 Screenshot saved: $screenshotsPath/$screenshotName.png');
      return true;
    },
  );
}
