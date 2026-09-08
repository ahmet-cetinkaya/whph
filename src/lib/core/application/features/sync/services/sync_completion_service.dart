import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/commands/save_sync_command.dart';
import 'package:whph/core/application/features/sync/queries/get_sync_query.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

/// Payload key carrying the server-generated sync completion timestamp back to the client.
///
/// Both devices store this single value so neither side depends on the other's clock.
const String syncCompletedAtPayloadKey = 'syncCompletedAt';

/// Generates, persists and publishes the completion timestamp of an incoming sync.
///
/// Used by every server-role emitter of `paginated_sync_complete` so the
/// "persist T + expose T" step exists exactly once.
class SyncCompletionService {
  final Mediator _mediator;

  SyncCompletionService(this._mediator);

  /// Records the completion of an incoming sync and returns the payload fragment
  /// to merge into the `paginated_sync_complete` message.
  ///
  /// Returns an empty map for partial or failed syncs so their timestamps are
  /// neither persisted nor advertised to the client.
  Future<Map<String, dynamic>> recordCompletion({
    required Map<String, dynamic>? syncDeviceData,
    required bool isComplete,
    required bool succeeded,
  }) async {
    if (!isComplete || !succeeded) return const {};

    final syncCompletedAt = DateTime.now().toUtc();
    await _persist(syncDeviceData, syncCompletedAt);

    return {syncCompletedAtPayloadKey: syncCompletedAt.toIso8601String()};
  }

  Future<void> _persist(Map<String, dynamic>? syncDeviceData, DateTime syncCompletedAt) async {
    try {
      if (syncDeviceData == null) {
        Logger.debug('Cannot persist sync completion: missing syncDevice information');
        return;
      }

      final clientIp = syncDeviceData['fromIp'] as String?;
      final serverIp = syncDeviceData['toIp'] as String?;
      if (clientIp == null || serverIp == null) {
        Logger.debug('Cannot persist sync completion: missing IP information in syncDevice');
        return;
      }

      final syncDevice = await _mediator.send<GetSyncDeviceQuery, GetSyncDeviceQueryResponse?>(GetSyncDeviceQuery(
        fromIP: clientIp,
        toIP: serverIp,
        fromDeviceId: syncDeviceData['fromDeviceId'] as String? ?? '',
        toDeviceId: syncDeviceData['toDeviceId'] as String? ?? '',
      ));

      if (syncDevice == null) {
        Logger.debug('Sync device not found for IP pair: $clientIp -> $serverIp');
        return;
      }

      await _mediator.send<SaveSyncDeviceCommand, SaveSyncDeviceCommandResponse>(SaveSyncDeviceCommand(
        id: syncDevice.id,
        name: syncDevice.name,
        fromIP: syncDevice.fromIp,
        toIP: syncDevice.toIp,
        fromDeviceId: syncDevice.fromDeviceId,
        toDeviceId: syncDevice.toDeviceId,
        lastSyncDate: syncCompletedAt,
      ));
      Logger.debug('Server-side lastSyncDate updated with completion timestamp: $syncCompletedAt');
    } catch (e) {
      Logger.error('Failed to persist sync completion timestamp: $e');
    }
  }
}
