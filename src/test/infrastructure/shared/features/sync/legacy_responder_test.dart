// T22 acceptance 4, 5 and 6: the legacy v0.24.3 responder of the LAN server.
// The frames under test/fixtures/sync/legacy_v0_24_3 were recorded from the
// v0.24.3 desktop and Android client code (D10) before that code was removed
// (T29); they are the frozen client side of these tests.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_session_host.dart';
import 'package:whph/core/application/features/sync/services/device_handshake_service.dart';
import 'package:whph/infrastructure/shared/features/sync/legacy_sync_responder.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_server.dart';
import 'package:whph/main.mapper.g.dart' show initializeJsonMapper;

import 'lan_test_support.dart';

const String _fixtureDirectory = 'test/fixtures/sync/legacy_v0_24_3';
const String _fixtureHostId = 'fixture-host-member';
const String _fixtureAppVersion = '0.25.0';
const int _pushCount = 10;
const String _pushFixture = 'push_paginated_sync';
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
  setUpAll(_mockDeviceInfoChannel);

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
        'push path (Android and desktop initiators): refused with versionMismatchError, no silent success',
        () async {
      final b = host.device;
      final checksumBefore = contentChecksum(b);

      final reply = await _sendLegacyFrame(server.port!, _loadFrames(_pushFixture).single['request']);

      final data = reply['data'] as Map<String, dynamic>;
      expect(reply['type'], 'paginated_sync');
      expect(data['success'], isFalse);
      expect(data['error'], SyncTranslationKeys.versionMismatchError);
      expect(host.results, isEmpty, reason: 'no engine session ran on the server');
      expect(contentChecksum(b), checksumBefore);
      expect(registry.needsUpdate.single.displayName, 'Device at 127.0.0.1');
    });

    test(
        'a new device reads a legacy responder as "needs update" and a new one as current',
        () async {
      final stub = _LegacyDeviceInfoStub();
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
        socket.add(jsonEncode(_pushFrameWithTitles([marker, '$marker-b'])));
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

Future<Map<String, dynamic>> _sendLegacyFrame(int port, Object frame) async {
  final socket = await WebSocket.connect('ws://127.0.0.1:$port');
  socket.add(jsonEncode(frame));
  final reply = jsonDecode(await socket.first as String) as Map<String, dynamic>;
  await socket.close();
  return reply;
}

/// The recorded legacy push frame with [titles] as the pushed task titles.
Map<String, dynamic> _pushFrameWithTitles(List<String> titles) {
  final frame = Map<String, dynamic>.from(_loadFrames(_pushFixture).single['request'] as Map);
  final data = Map<String, dynamic>.from(frame['data'] as Map);
  final tasks = [
    for (var index = 0; index < titles.length; index++)
      {'id': 'task-$index', 'createdDate': '2026-01-01T00:00:00.000Z', 'title': titles[index]},
  ];
  data['tasksSyncData'] = {
    'data': {'createSync': tasks, 'updateSync': <Object>[], 'deleteSync': <Object>[]},
  };
  return {...frame, 'data': data};
}

/// Answers the device-info plugin the server asks for its name.
void _mockDeviceInfoChannel() {
  const channel = MethodChannel('dev.fluttercommunity.plus/device_info');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (call) async => {
      'name': 'Test Linux',
      'version': '1',
      'id': 'test',
      'idLike': <String>[],
      'versionCodename': 'test',
      'versionId': '1',
      'prettyName': 'Test Linux',
      'buildId': 'test',
      'variant': 'test',
      'variantId': 'test',
      'machineId': 'test',
    },
  );
}

/// A v0.24.3 device: its device_info reply has no member id and no protocol
/// version, so a new device reads it as "needs update".
class _LegacyDeviceInfoStub {
  late final HttpServer _server;

  int get port => _server.port;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(_server.forEach((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((_) => socket.add(jsonEncode({
            'type': 'device_info_response',
            'data': {
              'success': true,
              'deviceId': 'stub',
              'deviceName': 'Stub',
              'appName': 'WHPH',
              'platform': 'linux',
            },
          })));
    }));
  }

  Future<void> stop() => _server.close(force: true);
}
