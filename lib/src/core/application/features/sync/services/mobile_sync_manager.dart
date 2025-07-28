import 'package:whph/src/core/shared/utils/logger.dart';
import 'package:whph/src/core/application/features/sync/models/sync_role.dart';
import 'package:whph/src/presentation/ui/features/sync/models/sync_qr_code_message.dart';
import 'package:whph/src/infrastructure/android/features/sync/android_server_sync_service.dart';
import 'package:whph/src/core/application/features/sync/services/abstraction/i_device_id_service.dart';

class MobileSyncManager {
  final IDeviceIdService _deviceIdService;

  MobileSyncManager(this._deviceIdService);

  /// Negotiate sync role between two mobile devices
  /// Strategy: Device with lexicographically smaller device ID becomes server
  Future<SyncRole> negotiateRole(SyncQrCodeMessage remoteDevice) async {
    try {
      final localDeviceId = await _deviceIdService.getDeviceId();

      Logger.debug('🤝 Negotiating sync role:');
      Logger.debug('   Local device ID: $localDeviceId');
      Logger.debug('   Remote device ID: ${remoteDevice.deviceId}');

      // Use string comparison to determine role
      final comparison = localDeviceId.compareTo(remoteDevice.deviceId);

      if (comparison < 0) {
        Logger.info('📱 Local device selected as SERVER (ID comparison: $comparison)');
        return SyncRole.server;
      } else if (comparison > 0) {
        Logger.info('📱 Local device selected as CLIENT (ID comparison: $comparison)');
        return SyncRole.client;
      } else {
        // Identical device IDs (unlikely but possible in testing)
        Logger.warning('⚠️ Identical device IDs detected, falling back to client mode');
        return SyncRole.client;
      }
    } catch (e) {
      Logger.error('❌ Error during role negotiation: $e');
      // Default to client mode on error
      return SyncRole.client;
    }
  }

  /// Attempt to start a mobile device as sync server
  Future<bool> tryStartAsServer(AndroidServerSyncService serverService) async {
    try {
      Logger.info('🚀 Attempting to start mobile device as sync server...');

      final success = await serverService.startAsServer();

      if (success) {
        Logger.info('✅ Mobile device successfully started as sync server');
        Logger.info('🌐 Server is listening on port 44040');
        Logger.info('📱 Ready to accept connections from other devices');
        return true;
      } else {
        Logger.warning('❌ Failed to start mobile device as sync server');
        Logger.info('📱 Device will operate in client mode instead');
        return false;
      }
    } catch (e) {
      Logger.error('💥 Exception while starting mobile sync server: $e');
      return false;
    }
  }

  /// Determine the best sync strategy for mobile-to-mobile sync
  Future<MobileSyncStrategy> determineSyncStrategy(
    SyncQrCodeMessage remoteDevice,
    AndroidServerSyncService? serverService,
  ) async {
    final negotiatedRole = await negotiateRole(remoteDevice);

    if (negotiatedRole == SyncRole.server && serverService != null) {
      final serverStarted = await tryStartAsServer(serverService);

      if (serverStarted) {
        return MobileSyncStrategy(
          role: SyncRole.server,
          serverService: serverService,
          isServerActive: true,
        );
      } else {
        // Fallback to client mode if server startup failed
        return MobileSyncStrategy(
          role: SyncRole.client,
          serverService: null,
          isServerActive: false,
        );
      }
    }

    return MobileSyncStrategy(
      role: SyncRole.client,
      serverService: null,
      isServerActive: false,
    );
  }
}

class MobileSyncStrategy {
  final SyncRole role;
  final AndroidServerSyncService? serverService;
  final bool isServerActive;

  MobileSyncStrategy({
    required this.role,
    required this.serverService,
    required this.isServerActive,
  });

  bool get isServer => role == SyncRole.server && isServerActive;
  bool get isClient => role == SyncRole.client || !isServerActive;

  @override
  String toString() {
    return 'MobileSyncStrategy(role: $role, isServerActive: $isServerActive)';
  }
}
