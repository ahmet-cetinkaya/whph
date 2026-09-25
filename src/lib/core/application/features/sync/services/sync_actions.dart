import 'dart:io';

import 'package:whph/core/application/features/sync/models/sync_status.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_network_interface_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_service.dart';
import 'package:whph/core/application/features/sync/services/device_handshake_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_transaction_service.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';

sealed class FieldUpdate<T> {
  const FieldUpdate();
}

final class PreserveField<T> extends FieldUpdate<T> {
  const PreserveField();
}

final class ReplaceField<T> extends FieldUpdate<T> {
  const ReplaceField(this.value);

  final T value;
}

final class SyncDeviceUpdate {
  const SyncDeviceUpdate({
    required this.id,
    required this.expectedRevision,
    this.name = const PreserveField(),
    this.fromIp = const PreserveField(),
    this.toIp = const PreserveField(),
  });

  final String id;
  final DateTime expectedRevision;
  final FieldUpdate<String?> name;
  final FieldUpdate<String> fromIp;
  final FieldUpdate<String> toIp;
}

final class SyncPeer {
  const SyncPeer({
    required this.deviceId,
    required this.name,
    required this.ipAddress,
    required this.port,
  });

  final String deviceId;
  final String name;
  final String ipAddress;
  final int port;
}

final class SyncDevicePage {
  SyncDevicePage({required List<SyncDevice> items, required this.nextCursor, required this.total})
      : items = List.unmodifiable(items);

  final List<SyncDevice> items;
  final String? nextCursor;
  final int total;
}

final class SyncRevisionConflictException implements Exception {
  const SyncRevisionConflictException(this.id);
  final String id;
}

final class SyncPairingException implements Exception {
  const SyncPairingException(this.message);
  final String message;
}

final class SyncCommitResult<T> {
  const SyncCommitResult({required this.value, required this.syncSucceeded});

  final T value;
  final bool syncSucceeded;
}

final class SyncActions {
  const SyncActions({
    required ISyncDeviceRepository repository,
    required IApplicationTransactionService transactions,
    required ISyncService syncService,
    required IDeviceIdService deviceIds,
    required INetworkInterfaceService networkInterfaces,
    required DeviceHandshakeService handshake,
  })  : _repository = repository,
        _transactions = transactions,
        _syncService = syncService,
        _deviceIds = deviceIds,
        _networkInterfaces = networkInterfaces,
        _handshake = handshake;

  final ISyncDeviceRepository _repository;
  final IApplicationTransactionService _transactions;
  final ISyncService _syncService;
  final IDeviceIdService _deviceIds;
  final INetworkInterfaceService _networkInterfaces;
  final DeviceHandshakeService _handshake;

  SyncStatus get status => _syncService.currentSyncStatus;

  Future<SyncDevicePage> list({required int pageIndex, required int pageSize}) async {
    final page = await _repository.getList(pageIndex, pageSize);
    final hasNext = (pageIndex + 1) * pageSize < page.totalItemCount;
    return SyncDevicePage(
      items: page.items,
      nextCursor: hasNext ? '${pageIndex + 1}' : null,
      total: page.totalItemCount,
    );
  }

  Future<SyncDevice?> read(String id) => _repository.getById(id);

  Future<SyncCommitResult<SyncDevice>> update(
    SyncDeviceUpdate update,
    Future<void> Function() beforeCommit,
  ) async {
    final updated = await _transactions.run(() async {
      final current = await _requireCurrent(update.id, update.expectedRevision);
      await beforeCommit();
      final replacement = SyncDevice(
        id: current.id,
        createdDate: current.createdDate,
        modifiedDate: current.modifiedDate,
        fromIp: _replace(current.fromIp, update.fromIp),
        toIp: _replace(current.toIp, update.toIp),
        fromDeviceId: current.fromDeviceId,
        toDeviceId: current.toDeviceId,
        name: _replace(current.name, update.name),
        lastSyncDate: current.lastSyncDate,
      );
      final revision = await _repository.updateIfRevision(replacement, update.expectedRevision);
      if (revision == null) throw SyncRevisionConflictException(update.id);
      return SyncDevice(
        id: replacement.id,
        createdDate: replacement.createdDate,
        modifiedDate: revision,
        fromIp: replacement.fromIp,
        toIp: replacement.toIp,
        fromDeviceId: replacement.fromDeviceId,
        toDeviceId: replacement.toDeviceId,
        name: replacement.name,
        lastSyncDate: replacement.lastSyncDate,
      );
    });
    return SyncCommitResult(value: updated, syncSucceeded: await _syncAfterCommit());
  }

  Future<SyncCommitResult<DateTime>> delete(
    String id,
    DateTime expectedRevision,
    Future<void> Function() beforeCommit,
  ) async {
    final deletedAt = await _transactions.run(() async {
      final current = await _requireCurrent(id, expectedRevision);
      await beforeCommit();
      final deletedAt = await _repository.deleteIfRevision(current.id, expectedRevision);
      if (deletedAt == null) throw SyncRevisionConflictException(id);
      return deletedAt;
    });
    return SyncCommitResult(value: deletedAt, syncSucceeded: await _syncAfterCommit());
  }

  Future<SyncStatus> start() async {
    await _syncService.startSync();
    return status;
  }

  SyncStatus stop() {
    _syncService.stopSync();
    return status;
  }

  Future<SyncCommitResult<SyncDevice>> pair(SyncPeer peer) async {
    final handshake = await _handshake.getDeviceInfo(peer.ipAddress, peer.port);
    if (handshake == null || handshake.deviceId != peer.deviceId) {
      throw const SyncPairingException('The peer did not complete a matching WHPH handshake.');
    }
    final localAddresses = await _networkInterfaces.getPreferredIPAddresses();
    if (localAddresses.isEmpty) {
      throw const SyncPairingException('A local network address is required to pair this device.');
    }
    final localDeviceId = await _deviceIds.getDeviceId();
    final paired = await _transactions.run(() async {
      final allDevices = await _repository.getAll(includeDeleted: true);
      final existing = allDevices.where((device) {
        return device.fromDeviceId == peer.deviceId && device.toDeviceId == localDeviceId;
      }).firstOrNull;
      if (existing != null && existing.deletedDate == null) {
        throw const SyncPairingException('The peer is already paired.');
      }
      final replacement = SyncDevice(
        id: existing?.id ?? KeyHelper.generateStringId(),
        createdDate: existing?.createdDate ?? DateTime.now().toUtc(),
        fromIp: peer.ipAddress,
        toIp: localAddresses.first,
        fromDeviceId: peer.deviceId,
        toDeviceId: localDeviceId,
        name: peer.name,
      );
      if (existing == null) {
        await _repository.add(replacement);
      } else {
        await _repository.update(replacement);
      }
      return replacement;
    });
    return SyncCommitResult(value: paired, syncSucceeded: await _syncAfterCommit());
  }

  Future<bool> _syncAfterCommit() async {
    try {
      await _syncService.runSync(isManual: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<SyncDevice> _requireCurrent(String id, DateTime expectedRevision) async {
    final device = await _repository.getById(id);
    if (device == null) throw StateError('Sync device not found.');
    final revision = device.modifiedDate ?? device.createdDate;
    if (!revision.toUtc().isAtSameMomentAs(expectedRevision.toUtc())) {
      throw SyncRevisionConflictException(id);
    }
    return device;
  }

  T _replace<T>(T current, FieldUpdate<T> update) => switch (update) {
        PreserveField<T>() => current,
        ReplaceField<T>(value: final value) => value,
      };
}

bool isPairableIpAddress(String value) {
  final address = InternetAddress.tryParse(value);
  if (address == null || address.type != InternetAddressType.IPv4) return false;
  final octets = value.split('.').map(int.parse).toList(growable: false);
  return octets.first == 10 ||
      octets.first == 127 ||
      (octets.first == 172 && octets[1] >= 16 && octets[1] <= 31) ||
      (octets.first == 192 && octets[1] == 168) ||
      (octets.first == 169 && octets[1] == 254);
}
