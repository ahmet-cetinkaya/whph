import 'dart:convert';

import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_session_host.dart';

/// Wire name of the legacy (v0.24.3) discovery request.
const String legacyDeviceInfoType = 'device_info';

/// Wire name of the legacy sync push and data page.
const String legacyPaginatedSyncType = 'paginated_sync';

/// Largest legacy text message the responder reads; bigger ones are dropped.
const int legacyMaxMessageChars = 4 * 1024 * 1024;

/// Most devices the registry remembers.
const int legacyRegistryCapacity = 64;

const String _legacyAppName = 'WHPH';
const String _legacyServerType = 'lan_server';

/// A v0.24.3 device that tried to sync and must update.
class LegacyDeviceSighting {
  final String? deviceId;
  final String? name;
  final String? appVersion;
  final String source;
  final DateTime lastSeen;

  const LegacyDeviceSighting({
    required this.deviceId,
    required this.name,
    required this.appVersion,
    required this.source,
    required this.lastSeen,
  });

  /// The device name, or its address when it never sent a name.
  String get displayName => name ?? 'Device at $source';
}

/// Devices that need an update, newest last (D10 "needs update").
class LegacyDeviceRegistry {
  final Map<String, LegacyDeviceSighting> _devices = {};

  List<LegacyDeviceSighting> get needsUpdate => List.unmodifiable(_devices.values);

  void record(LegacyDeviceSighting sighting) {
    final key = sighting.deviceId ?? sighting.displayName;
    _devices
      ..remove(key)
      ..[key] = sighting;
    if (_devices.length > legacyRegistryCapacity) _devices.remove(_devices.keys.first);
  }
}

/// Minimal responder for v0.24.3 JSON messages (D10).
///
/// It reads only `type`, `appVersion` and the device id and name fields. It
/// never logs, stores or applies a payload. Every sync request is answered so
/// that the old client ends in its own "version mismatch" error before it
/// processes any item: the data page carries no items and the new app
/// version.
class LegacySyncResponder {
  final Future<SyncPresence> Function() _presence;
  final LegacyDeviceRegistry _registry;
  final DateTime Function() _now;

  LegacySyncResponder({
    required Future<SyncPresence> Function() presence,
    required LegacyDeviceRegistry registry,
    DateTime Function()? now,
  })  : _presence = presence,
        _registry = registry,
        _now = now ?? DateTime.now;

  /// Handles one text message from [source]. Returns the reply text, or
  /// `null` when no reply is due.
  Future<String?> handle(String text, {required String source}) async {
    if (text.length > legacyMaxMessageChars) {
      Logger.warning('Legacy message dropped: too large', component: 'LegacySyncResponder');
      return null;
    }
    final message = _parse(text);
    final type = message?['type'];
    if (type is! String) return _reply('error', {'success': false, 'message': 'Invalid message'});
    // Only the type and the sender go to the log; the payload never does.
    Logger.debug('Legacy message "$type" from $source', component: 'LegacySyncResponder');
    final data = message?['data'];
    final fields = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    final presence = await _presence();
    switch (type) {
      case legacyDeviceInfoType:
        return _reply('device_info_response', _deviceInfo(presence));
      case 'test':
        return _reply('test_response', {'success': true, 'timestamp': _timestamp()});
      case 'connection_test':
        return _reply('connection_test_response', {'success': true, 'timestamp': _timestamp()});
      case 'heartbeat':
        return _reply('heartbeat_response', {'timestamp': _timestamp(), 'serverStatus': 'healthy'});
      case 'client_connect':
        _markNeedsUpdate(fields, source, nameKey: 'clientName', idKey: 'clientId');
        return _reply('client_connected', {
          'success': true,
          'serverId': presence.memberId,
          'serverName': presence.deviceName,
          'supportedOperations': const <String>[],
          'timestamp': _timestamp(),
        });
      case 'paginated_sync_start':
        _markNeedsUpdate(fields, source, idKey: 'clientId');
        return _reply('paginated_sync_started', {
          'success': true,
          'serverId': presence.memberId,
          'timestamp': _timestamp(),
        });
      case 'paginated_sync_request':
        _markNeedsUpdate(fields, source, idKey: 'clientId');
        return _versionMismatchPage(presence, entityType: fields['entityType']);
      case legacyPaginatedSyncType:
        _markPushSender(fields, source);
        return _versionMismatchPage(presence, entityType: fields['entityType']);
      default:
        return _reply('error', {'success': false, 'message': 'Unknown message type'});
    }
  }

  Map<String, dynamic>? _parse(String text) {
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic> _deviceInfo(SyncPresence presence) => {
        'success': true,
        // Legacy field names first so v0.24.3 scans still list this device.
        'deviceId': presence.memberId,
        'deviceName': presence.deviceName,
        'appName': _legacyAppName,
        'platform': presence.platform,
        'memberId': presence.memberId,
        'protocolVersion': presence.protocolVersion,
        'appVersion': presence.appVersion,
        'timestamp': _timestamp(),
      };

  String _versionMismatchPage(SyncPresence presence, {required Object? entityType}) {
    final now = _timestamp();
    return _reply(legacyPaginatedSyncType, {
      'success': true,
      'server_type': _legacyServerType,
      'timestamp': now,
      'paginatedSyncDataDto': {
        'appVersion': presence.appVersion,
        'syncDevice': {
          'id': '',
          'createdDate': now,
          'fromIp': '',
          'toIp': '',
          'fromDeviceId': presence.memberId,
          'toDeviceId': '',
        },
        'isDebugMode': false,
        'entityType': entityType is String ? entityType : 'tasks',
        'pageIndex': 0,
        'pageSize': 0,
        'totalPages': 0,
        'totalItems': 0,
        'isLastPage': true,
      },
    });
  }

  /// A push names no sender: its `syncDevice` is the sender's record of this
  /// device, so only the appVersion and the source address are used.
  void _markPushSender(Map<String, dynamic> fields, String source) {
    _record(appVersion: _text(fields['appVersion']), source: source);
  }

  void _markNeedsUpdate(Map<String, dynamic> fields, String source, {String? nameKey, required String idKey}) {
    _record(
      deviceId: _text(fields[idKey]),
      name: nameKey == null ? null : _text(fields[nameKey]),
      appVersion: _text(fields['appVersion']),
      source: source,
    );
  }

  void _record({String? deviceId, String? name, String? appVersion, required String source}) {
    _registry.record(LegacyDeviceSighting(
      deviceId: deviceId,
      name: name ?? _knownName(deviceId, source),
      appVersion: appVersion,
      source: source,
      lastSeen: _now(),
    ));
  }

  /// The name an earlier message of the same device or address carried.
  String? _knownName(String? deviceId, String source) {
    for (final sighting in _registry.needsUpdate.reversed) {
      final sameDevice = deviceId != null && sighting.deviceId == deviceId;
      if ((sameDevice || sighting.source == source) && sighting.name != null) return sighting.name;
    }
    return null;
  }

  String? _text(Object? value) => value is String && value.isNotEmpty ? value : null;

  String _timestamp() => _now().toIso8601String();

  String _reply(String type, Map<String, dynamic> data) => jsonEncode({'type': type, 'data': data});
}
