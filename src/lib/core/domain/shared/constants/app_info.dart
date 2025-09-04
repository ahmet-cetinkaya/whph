import 'package:whph/core/domain/shared/constants/app_assets.dart';

/// Centralized app information constants.
///
/// These constants should be used throughout the application instead of hardcoded strings.
/// When updating these values, also update corresponding platform-specific files:
/// - Android: android/app/src/main/res/values/strings.xml
/// - iOS: ios/Runner/Info.plist
/// - Windows: windows/runner/app_constants.h
/// - Linux: linux/app_constants.h, linux/whph.desktop
class AppInfo {
  static const String name = "Work Hard Play Hard";
  static const String shortName = "WHPH";
  static const String version = "0.13.2";
  static const String websiteUrl = "https://whph.ahmetcetinkaya.me/";
  static const String sourceCodeUrl = "https://github.com/ahmet-cetinkaya/whph";
  static const String logoPath = AppAssets.logo;
  static const String supportUrl = "https://ahmetcetinkaya.me/donate";
  static const String updateCheckerUrl = "https://api.github.com/repos/ahmet-cetinkaya/whph/releases/latest";
  static const String supportEmail = "contact@ahmetcetinkaya.me";
  static const String feedbackUrl = "https://github.com/ahmet-cetinkaya/whph/issues";
}
