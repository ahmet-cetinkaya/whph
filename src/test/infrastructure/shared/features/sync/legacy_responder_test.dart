// T22 acceptance 4, 5 and 6: the legacy v0.24.3 responder of the LAN server.
// The legacy clients are the in-tree code (identical to v0.24.3, D10).
// Set RECORD_LEGACY_FIXTURES=1 to re-record the frame fixtures.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/core/application/features/sync/models/sync_status.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_session_host.dart';
import 'package:whph/core/application/features/sync/services/device_handshake_service.dart';
import 'package:whph/core/application/features/sync/services/sync_communication_service/sync_communication_service.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/infrastructure/shared/features/sync/legacy_sync_responder.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_server.dart';
import 'package:whph/presentation/ui/shared/utils/device_info_helper.dart';
import 'package:whph/main.mapper.g.dart' show initializeJsonMapper;
import 'package:yaml/yaml.dart';

import 'lan_test_support.dart';
import 'legacy_client_harness.dart';

const String _fixtureDirectory = 'test/fixtures/sync/legacy_v0_24_3';
const String _localeFile =
    'lib/presentation/ui/features/sync/assets/locales/en.yaml';
const String _fixtureClientName = 'Legacy Desktop';
const String _fixtureHostId = 'fixture-host-member';
const String _fixtureAppVersion = '0.25.0';
const int _pushCount = 10;
const List<String> _fixtureFiles = [
  'discovery_device_info',
  'desktop_client_session',
  'push_paginated_sync'
];
final DateTime _fixtureNow = DateTime.utc(2026);

const SyncPresence _fixturePresence = SyncPresence(
  memberId: _fixtureHostId,
  deviceName: 'Fixture Host',
  platform: 'linux',
  appVersion: _fixtureAppVersion,
  protocolVersion: 3,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initializeJsonMapper();
  setUpAll(mockDeviceInfoChannel);

  late LanSyncServer server;
  late DeviceHost host;
  late LegacyDeviceRegistry registry;

  setUp(() async {
    final b = await newDevice('B', seed: 2);
    host = DeviceHost(b);
    registry = LegacyDeviceRegistry();
    server = LanSyncServer(
        host: host,
        port: 0,
        bindAddress: InternetAddress.loopbackIPv4,
        legacyRegistry: registry);
    expect(await server.start(), isTrue);
  });
  tearDown(() => server.stop());

  group('acceptance 4: legacy clients against the new server', () {
    test(
        'desktop client path ends in versionMismatchError before any item is processed',
        () async {
      final b = host.device;
      final checksumBefore = contentChecksum(b);
      final side = LegacyClientSide();
      final client = side.desktopClient();

      unawaited(client.connectToServer('127.0.0.1', server.port!));
      await eventually(() => side.validation.thrown.isNotEmpty);
      // Gap (recorded in the T22 evidence): the legacy client drops the error
      // list of the command response and waits for a completion message, so
      // it keeps showing "syncing" instead of the mismatch text.
      expect(client.currentSyncStatus.state, SyncState.syncing);
      await client.disconnectFromServer();

      final error = side.validation.thrown.first;
      expect(error.code, SyncTranslationKeys.versionMismatchError);
      expect(error.params,
          {'currentVersion': AppInfo.version, 'remoteVersion': '9.9.9'});
      expect(side.processing.calls, 0);
      expect(host.results, isEmpty,
          reason: 'no engine session ran on the server');
      expect(contentChecksum(b), checksumBefore);

      final listed = registry.needsUpdate.single;
      expect(listed.displayName, await DeviceInfoHelper.getDeviceName());
      debugPrint('LEGACY UI MESSAGE: ${_observedUiMessage(error.params!)}');
    });

    test(
        'push path (Android and desktop initiators): refused with versionMismatchError, no silent success',
        () async {
      final markers = [for (var i = 0; i < 3; i++) 'LEGACY-PUSH-MARKER-$i'];
      final communication =
          SyncCommunicationService(websocketPort: server.port!, maxRetries: 1);

      final response = await communication.sendPaginatedDataToDevice(
          '127.0.0.1', syntheticPushDto(markers));

      // The legacy pagination code treats `success: false` as a failed page:
      // the entity sync returns false and the orchestrator reports
      // syncWithDeviceFailedError ("Failed to sync with device.") instead of
      // a silent success. The mismatch key is only logged by the old client.
      expect(response.success, isFalse);
      expect(response.error, SyncTranslationKeys.versionMismatchError);
      expect(response.responseData, isNull);
      expect(host.results, isEmpty);
      expect(registry.needsUpdate.single.displayName, 'Device at 127.0.0.1');
    });

    test(
        'a new device reads a legacy responder as "needs update" and a new one as current',
        () async {
      final stub = LegacyCaptureStub();
      await stub.start();
      addTearDown(stub.stop);

      final legacy =
          await DeviceHandshakeService().getDeviceInfo('127.0.0.1', stub.port);
      final current = await DeviceHandshakeService()
          .getDeviceInfo('127.0.0.1', server.port!);

      expect(legacy!.needsUpdate, isTrue);
      expect(current!.needsUpdate, isFalse);
      expect(current.protocolVersion, 3);
      expect(current.memberId, host.device.memberId);
      expect(current.appVersion, '9.9.9');
      expect(current.deviceName, 'B');
    });

    test('device_info discloses presence only', () async {
      final socket = await WebSocket.connect('ws://127.0.0.1:${server.port}');
      socket.add(jsonEncode({'type': 'device_info', 'data': {}}));

      final reply =
          jsonDecode(await socket.first as String) as Map<String, dynamic>;
      await socket.close();

      final data = reply['data'] as Map<String, dynamic>;
      expect(data.keys.toSet(), {
        'success',
        'deviceId',
        'deviceName',
        'appName',
        'platform',
        'memberId',
        'protocolVersion',
        'appVersion',
        'timestamp',
      });
    });
  });

  group('acceptance 5: recorded legacy_v0_24_3 fixtures', () {
    test('recording (only with RECORD_LEGACY_FIXTURES=1)', () async {
      final stub = LegacyCaptureStub();
      await stub.start();
      final side = LegacyClientSide();

      final marks = <int>[0];
      await DeviceHandshakeService().getDeviceInfo('127.0.0.1', stub.port);
      marks.add(stub.requests.length);
      final client = side.desktopClient();
      unawaited(client.connectToServer('127.0.0.1', stub.port));
      await eventually(() =>
          stub.requests.any((r) => r['type'] == 'paginated_sync_request'));
      await client.disconnectFromServer();
      marks.add(stub.requests.length);
      await SyncCommunicationService(websocketPort: stub.port, maxRetries: 1)
          .sendPaginatedDataToDevice('127.0.0.1',
              syntheticPushDto(['FIXTURE-TITLE-1', 'FIXTURE-TITLE-2']));
      marks.add(stub.requests.length);
      await stub.stop();

      final responder = _fixtureResponder();
      for (var i = 0; i < _fixtureFiles.length; i++) {
        final frames = <Map<String, dynamic>>[];
        for (final request in stub.requests.sublist(marks[i], marks[i + 1])) {
          _anonymize(request);
          final reply =
              await responder.handle(jsonEncode(request), source: '127.0.0.1');
          frames.add({
            'request': request,
            'expectedResponse': reply == null ? null : jsonDecode(reply)
          });
        }
        File('$_fixtureDirectory/${_fixtureFiles[i]}.json').writeAsStringSync(
            '${const JsonEncoder.withIndent('  ').convert({
              'frames': frames
            })}\n');
      }
    },
        skip: Platform.environment['RECORD_LEGACY_FIXTURES'] == '1'
            ? false
            : 'set RECORD_LEGACY_FIXTURES=1 to record');

    for (final name in _fixtureFiles) {
      test('replaying $name gives the recorded responder output', () async {
        final frames = _loadFrames(name);
        expect(frames, isNotEmpty);
        final responder = _fixtureResponder();

        for (final frame in frames) {
          final reply = await responder.handle(jsonEncode(frame['request']),
              source: '127.0.0.1');

          expect(reply == null ? null : jsonDecode(reply),
              frame['expectedResponse'],
              reason: '${frame['request']['type']}');
        }
      });
    }

    test('the fixtures replayed over the real server give the recorded replies',
        () async {
      for (final name in _fixtureFiles) {
        final socket = await WebSocket.connect('ws://127.0.0.1:${server.port}');
        final replies = StreamIterator(socket);
        for (final frame in _loadFrames(name)) {
          socket.add(jsonEncode(frame['request']));
          if (frame['expectedResponse'] == null) continue;
          expect(await replies.moveNext(), isTrue);
          final reply =
              jsonDecode(replies.current as String) as Map<String, dynamic>;
          expect(reply['type'], (frame['expectedResponse'] as Map)['type'],
              reason: name);
        }
        await socket.close();
      }
    });
  });

  group('acceptance 6: payload-free logging', () {
    test('$_pushCount legacy pushes with markers leave 0 markers in debug logs',
        () async {
      final logs = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
      addTearDown(() => debugPrint = originalDebugPrint);
      final markers = <String>[];

      for (var push = 0; push < _pushCount; push++) {
        final marker = 'LOG-MARKER-$push-do-not-log';
        markers.add(marker);
        final socket = await WebSocket.connect('ws://127.0.0.1:${server.port}');
        final page = syntheticPushDto([marker, '$marker-b']).toJson();
        socket.add(jsonEncode({'type': 'paginated_sync', 'data': page}));
        await socket.first;
        await socket.close();
      }

      final joined = logs.join('\n');
      expect(
          logs.any((line) => line.contains('Legacy message "paginated_sync"')),
          isTrue,
          reason: 'debug logging is on and the responder logs the type only');
      for (final marker in markers) {
        expect(joined.contains(marker), isFalse, reason: marker);
      }
      expect(joined.contains('Legacy Phone'), isFalse,
          reason: 'device names stay out of the logs too');
    });
  });
}

/// Fixtures hold synthetic data only: the recording host's name is replaced.
void _anonymize(Map<String, dynamic> request) {
  final data = request['data'];
  if (data is Map<String, dynamic> && data.containsKey('clientName'))
    data['clientName'] = _fixtureClientName;
}

LegacySyncResponder _fixtureResponder() => LegacySyncResponder(
      presence: () async => _fixturePresence,
      registry: LegacyDeviceRegistry(),
      now: () => _fixtureNow,
    );

List<Map<String, dynamic>> _loadFrames(String name) {
  final decoded =
      jsonDecode(File('$_fixtureDirectory/$name.json').readAsStringSync())
          as Map<String, dynamic>;
  return (decoded['frames'] as List).cast<Map<String, dynamic>>();
}

/// The text the legacy UI shows for the mismatch key (`sync_error_handler`
/// translates the key with the exception's params).
String _observedUiMessage(Map<String, String> params) {
  final locale = loadYaml(File(_localeFile).readAsStringSync()) as YamlMap;
  var text = (locale['sync']['errors']['version_mismatch'] as String);
  params.forEach((name, value) => text = text.replaceAll('{$name}', value));
  return text;
}
