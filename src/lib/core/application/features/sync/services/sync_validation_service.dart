import 'package:flutter/foundation.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_validation_service.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/presentation/ui/shared/utils/network_utils.dart';

/// Implementation of sync validation service
class SyncValidationService implements ISyncValidationService {
  final IDeviceIdService _deviceIdService;

  SyncValidationService({
    required IDeviceIdService deviceIdService,
  }) : _deviceIdService = deviceIdService;

  @override
  Future<void> validateVersion(String remoteVersion) async {
    if (remoteVersion != AppInfo.version) {
      Logger.error('🚫 Version mismatch detected: local=${AppInfo.version}, remote=$remoteVersion');
      throw SyncValidationException(
        'Version mismatch detected: local=${AppInfo.version}, remote=$remoteVersion',
        code: 'VERSION_MISMATCH',
      );
    }
    Logger.debug('✅ Version validation passed: $remoteVersion');
  }

  @override
  Future<void> validateDeviceId(SyncDevice remoteDevice) async {
    final localDeviceIP = await NetworkUtils.getLocalIpAddress();
    final localDeviceID = await _deviceIdService.getDeviceId();

    // Check if this device is involved in the sync relationship (either as from or to)
    final isFromDevice = remoteDevice.fromIp == localDeviceIP && remoteDevice.fromDeviceId == localDeviceID;
    final isToDevice = remoteDevice.toIp == localDeviceIP && remoteDevice.toDeviceId == localDeviceID;

    // Also check if device IDs match but IPs might be different (for mobile-mobile sync scenarios)
    final deviceIdMatches = remoteDevice.fromDeviceId == localDeviceID || remoteDevice.toDeviceId == localDeviceID;

    if (isFromDevice || isToDevice || deviceIdMatches) {
      Logger.debug('✅ Device validation passed');
      return;
    }

    Logger.error('❌ Device validation failed:');
    Logger.error('   Local: IP=$localDeviceIP, ID=$localDeviceID');
    Logger.error('   Remote: fromIP=${remoteDevice.fromIp}, fromID=${remoteDevice.fromDeviceId}');
    Logger.error('   Remote: toIP=${remoteDevice.toIp}, toID=${remoteDevice.toDeviceId}');

    throw SyncValidationException(
      'Device ID mismatch: This device is not part of the sync relationship',
      code: 'DEVICE_MISMATCH',
    );
  }

  @override
  void validateEnvironmentMode(PaginatedSyncDataDto dto) {
    final localIsDebug = _isDeviceInDebugMode();
    final remoteIsDebug = dto.isDebugMode;

    Logger.debug('🔍 Environment mode validation:');
    Logger.debug('   Local device debug mode: $localIsDebug (kDebugMode: $kDebugMode)');
    Logger.debug('   Remote device debug mode: $remoteIsDebug');
    Logger.debug('   Local kReleaseMode: $kReleaseMode, kProfileMode: $kProfileMode');

    if (localIsDebug != remoteIsDebug) {
      final localMode = localIsDebug ? 'debug' : 'production';
      final remoteMode = remoteIsDebug ? 'debug' : 'production';

      Logger.error('🚫 Environment mode mismatch detected:');
      Logger.error('   Local device: $localMode mode');
      Logger.error('   Remote device: $remoteMode mode');
      Logger.error('');
      Logger.error('🔒 SECURITY: Sync between debug and production modes is not allowed');
      Logger.error('📝 This prevents accidental data mixing between development and production environments');
      Logger.error('');
      Logger.error('💡 If both devices should be in debug mode:');
      Logger.error('   - Ensure both are running from IDEs like VSCode in debug mode');
      Logger.error('   - Check that both use the same Flutter build configuration');
      Logger.error('   - Restart both applications if build mode detection seems incorrect');

      throw SyncValidationException(
        'Environment mode mismatch: local=$localMode, remote=$remoteMode. '
        'Sync between debug and production modes is not allowed for security reasons.',
        code: 'ENVIRONMENT_MODE_MISMATCH',
      );
    }

    final mode = localIsDebug ? 'debug' : 'production';
    Logger.debug('✅ Environment mode validation passed: both devices in $mode mode');
  }

  @override
  bool validateSyncDataIntegrity(PaginatedSyncDataDto dto) {
    try {
      // Basic integrity checks
      if (dto.appVersion.isEmpty) {
        Logger.warning('⚠️ Sync data integrity check failed: empty app version');
        return false;
      }

      if (dto.entityType.isEmpty) {
        Logger.warning('⚠️ Sync data integrity check failed: empty entity type');
        return false;
      }

      if (dto.pageIndex < 0) {
        Logger.warning('⚠️ Sync data integrity check failed: negative page index');
        return false;
      }

      if (dto.pageSize <= 0) {
        Logger.warning('⚠️ Sync data integrity check failed: invalid page size');
        return false;
      }

      if (dto.totalPages < 0) {
        Logger.warning('⚠️ Sync data integrity check failed: negative total pages');
        return false;
      }

      if (dto.totalItems < 0) {
        Logger.warning('⚠️ Sync data integrity check failed: negative total items');
        return false;
      }

      Logger.debug('✅ Sync data integrity validation passed');
      return true;
    } catch (e) {
      Logger.error('❌ Sync data integrity validation failed: $e');
      return false;
    }
  }

  @override
  Future<void> validateSyncPrerequisites() async {
    try {
      // Check if device ID service is available
      final deviceId = await _deviceIdService.getDeviceId();
      if (deviceId.isEmpty) {
        throw SyncValidationException(
          'Device ID is not available',
          code: 'DEVICE_ID_UNAVAILABLE',
        );
      }

      // Check if network utilities are functional
      final localIp = await NetworkUtils.getLocalIpAddress();
      if (localIp?.isEmpty ?? true) {
        throw SyncValidationException(
          'Local IP address is not available',
          code: 'LOCAL_IP_UNAVAILABLE',
        );
      }

      Logger.debug('✅ Sync prerequisites validation passed');
    } catch (e) {
      Logger.error('❌ Sync prerequisites validation failed: $e');
      if (e is SyncValidationException) {
        rethrow;
      }
      throw SyncValidationException(
        'Sync prerequisites validation failed: $e',
        code: 'PREREQUISITES_FAILED',
      );
    }
  }

  /// Detects if the device is running in debug mode using Flutter's built-in constants
  bool _isDeviceInDebugMode() {
    // Use Flutter's kDebugMode constant for reliable detection
    final isDebug = kDebugMode;
    Logger.debug('🔍 Debug mode detection: $isDebug (kDebugMode: $kDebugMode)');
    return isDebug;
  }
}
