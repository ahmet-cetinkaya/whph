import 'package:flutter/services.dart';
import 'package:whph/infrastructure/desktop/features/app_usages/abstractions/base_desktop_app_usage_service.dart';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/infrastructure/linux/constants/linux_app_constants.dart';

class LinuxAppUsageService extends BaseDesktopAppUsageService {
  static final MethodChannel _channel = MethodChannel(LinuxAppConstants.channels.appUsage);

  LinuxAppUsageService(
    super.appUsageRepository,
    super.appUsageTimeRecordRepository,
    super.appUsageTagRuleRepository,
    super.appUsageTagRepository,
    super.settingRepository,
  );

  @override
  Future<String?> getActiveWindow() async {
    try {
      // Use native method channel instead of bash script
      final String? result = await _channel.invokeMethod('getActiveWindow');
      return result;
    } on PlatformException catch (e) {
      Logger.error('Platform error: ${e.message}');
      return null;
    } catch (e) {
      Logger.error('Error getting active window: $e');
      return null;
    }
  }
}
