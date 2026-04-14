import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

class DeviceInfoHelper {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static const MethodChannel _appInfoChannel = MethodChannel('me.ahmetcetinkaya.whph/app_info');

  static Future<String> getDeviceName() async {
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.deviceInfo;
        String deviceName;
        if (info is AndroidDeviceInfo) {
          deviceName = '${info.brand.toUpperCase()} ${info.model}';
        } else {
          deviceName = Platform.localHostname;
        }

        // Check if running in work profile and add (Work) suffix
        try {
          final isWorkProfile = await _appInfoChannel.invokeMethod<bool>('isRunningInWorkProfile') ?? false;
          if (isWorkProfile) {
            deviceName += ' (Work)';
          }
        } catch (e) {
          Logger.error('Failed to check work profile status: $e');
          // Continue without work profile detection if it fails
        }

        return deviceName;
      }

      final userName = Platform.environment['USERNAME'] ?? Platform.environment['USER'];

      if (Platform.isLinux) {
        try {
          final info = await _deviceInfo.deviceInfo;
          if (info is LinuxDeviceInfo) {
            return userName != null ? '${info.prettyName} ($userName)' : info.prettyName;
          }
          return userName != null ? '${Platform.localHostname} ($userName)' : Platform.localHostname;
        } catch (e) {
          Logger.error('Failed to get Linux device info: $e');
          return userName != null ? '${Platform.localHostname} ($userName)' : Platform.localHostname;
        }
      }

      if (Platform.isWindows) {
        try {
          final info = await _deviceInfo.deviceInfo;
          if (info is WindowsDeviceInfo) {
            return userName != null ? '${info.computerName} ($userName)' : info.computerName;
          }
          return userName != null ? '${Platform.localHostname} ($userName)' : Platform.localHostname;
        } catch (e) {
          Logger.error('Failed to get Windows device info: $e');
          return userName != null ? '${Platform.localHostname} ($userName)' : Platform.localHostname;
        }
      }

      if (Platform.isMacOS) {
        try {
          final info = await _deviceInfo.deviceInfo;
          if (info is MacOsDeviceInfo) {
            return userName != null ? '${info.computerName} ($userName)' : info.computerName;
          }
          return userName != null ? '${Platform.localHostname} ($userName)' : Platform.localHostname;
        } catch (e) {
          Logger.error('Failed to get macOS device info: $e');
          return userName != null ? '${Platform.localHostname} ($userName)' : Platform.localHostname;
        }
      }

      if (Platform.isIOS) {
        try {
          final info = await _deviceInfo.deviceInfo;
          if (info is IosDeviceInfo) {
            return info.name;
          }
          return Platform.localHostname;
        } catch (e) {
          Logger.error('Failed to get iOS device info: $e');
          return Platform.localHostname;
        }
      }

      // For web and other platforms
      try {
        if (Platform.environment.containsKey('FLUTTER_WEB')) {
          final webInfo = await _deviceInfo.webBrowserInfo;
          return '${webInfo.browserName} on ${webInfo.platform}';
        }
      } catch (e) {
        Logger.error('Failed to get web browser info: $e');
      }

      return Platform.localHostname;
    } catch (e) {
      Logger.error('Failed to get device name: $e');
      return 'Unknown Device';
    }
  }
}
