import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:whph/src/core/shared/utils/logger.dart';

class DeviceInfoHelper {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static const MethodChannel _appInfoChannel = MethodChannel('me.ahmetcetinkaya.whph/app_info');

  static Future<String> getDeviceName() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        String deviceName = '${androidInfo.brand.toUpperCase()} ${androidInfo.model}';
        
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
        final linuxInfo = await _deviceInfo.linuxInfo;
        return userName != null ? '${linuxInfo.prettyName} ($userName)' : linuxInfo.prettyName;
      }

      if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        return userName != null ? '${windowsInfo.computerName} ($userName)' : windowsInfo.computerName;
      }

      if (Platform.isMacOS) {
        final macOsInfo = await _deviceInfo.macOsInfo;
        return userName != null ? '${macOsInfo.computerName} ($userName)' : macOsInfo.computerName;
      }

      return Platform.localHostname;
    } catch (e) {
      Logger.error('Failed to get device name: $e');
      return 'Unknown Device';
    }
  }
}
