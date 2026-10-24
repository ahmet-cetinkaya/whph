// T22 acceptance 1, 2, 7, 8 and the connection limits: a real LAN server and
// client on 127.0.0.1 run the engine session over WebSocket.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_session_host.dart';
import 'package:whph/core/domain/features/sync/models/desktop_sync_mode.dart';
import 'package:whph/infrastructure/desktop/features/sync/desktop_lan_sync_adapter.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_connection_limits.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_client.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_server.dart';
import 'package:whph/infrastructure/shared/features/sync/pairing_rate_limiter.dart';
import 'package:whph/infrastructure/shared/features/sync/web_socket_sync_transport.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'drift_session_test_support.dart';
import 'lan_test_support.dart';
import 'sync_security_test_support.dart';

const int _markerCount = 50;
const String _loopback = '127.0.0.1';
const Duration _shortTimeout = Duration(milliseconds: 300);

void main() {
  late List<LanSyncServer> servers;

  setUp(() => servers = []);
  tearDown(() async {
    for (final server in servers) {
      await server.stop();
    }
  });

  Future<LanSyncServer> startServer(ISyncSessionHost host,
      {LanConnectionLimits? limits,
      PairingRateLimiter? pairingLimiter,
      Duration firstFrameTimeout = defaultFirstFrameTimeout}) async {
    final server = LanSyncServer(
      host: host,
      port: 0,
      bindAddress: InternetAddress.loopbackIPv4,
      limits: limits,
      pairingLimiter: pairingLimiter,
      firstFrameTimeout: firstFrameTimeout,
    );
    expect(await server.start(), isTrue);
    servers.add(server);
    return server;
  }

  Future<(SyncDevice, SyncDevice, List<String>)> pairedDevices() async {
    final a = await newDevice('A', seed: 1);
    final b = await newDevice('B', seed: 2);
    await SyncDevice.pair(inviter: a, joiner: b);
    return (a, b, seedMarkers(a, _markerCount));
  }

  late Directory scratch;
  setUp(() async => scratch = await Directory.systemTemp.createTemp('lan-drift-'));
  tearDown(() => scratch.delete(recursive: true));

  Future<(DriftEngineDevice, DriftEngineDevice, List<String>)> pairedDriftDevices() async {
    final a = await DriftEngineDevice.open('A', scratch);
    final b = await DriftEngineDevice.open('B', scratch);
    addTearDown(a.close);
    addTearDown(b.close);
    await pairDevices(a.security, b.security);
    return (a, b, await seedNoteMarkers(a.security, _markerCount));
  }

  Future<SessionResult> syncDrift(DriftEngineDevice a, DriftEngineDevice b, int port) =>
      const LanSyncClient().runSession(
        _loopback,
        (transport) => a.initiate(transport, b.memberId),
        port: port,
      );

  Future<Set<String>> driftTitles(DriftEngineDevice device) async => {
        for (final row in await device.security.database.rows('SELECT title FROM note_table')) '${row['title']}',
      };

  test('acceptance 1: a real session moves all seeded markers (positive control)', () async {
    final (a, b, markers) = await pairedDriftDevices();
    final server = await startServer(b.host);

    final result = await syncDrift(a, b, server.port!);

    expect(result, isA<SessionComplete>(), reason: '$result');
    expect((await driftTitles(b)).containsAll(markers), isTrue);
    expect(markers, hasLength(_markerCount));
    expect(await b.security.database.content(), await a.security.database.content());
  });

  group('acceptance 2: SC-004 raw bytes', () {
    test('the encrypted session shows 0 markers; a plaintext control shows all', () async {
      final (a, b, markers) = await pairedDriftDevices();
      final server = await startServer(b.host);
      final proxy = RecordingProxy(server.port!);
      await proxy.start();
      addTearDown(proxy.stop);

      final result = await syncDrift(a, b, proxy.port);
      expect(result, isA<SessionComplete>(), reason: '$result');
      expect((await driftTitles(b)).containsAll(markers), isTrue);

      for (final unmasked in [false, true]) {
        final seen = markers.where((m) => proxy.captured.occurrences(m, unmasked: unmasked) > 0);
        expect(seen, isEmpty, reason: 'unmasked=$unmasked');
      }
      expect(proxy.captured.clientToServer.length, greaterThan(0));

      final control = await _captureTestOnlyPlaintext(markers);
      final detected = markers.where((m) => control.occurrences(m, unmasked: true) > 0);
      expect(detected, hasLength(_markerCount));
    });
  });

  group('connection handling', () {
    test('connections above the limit are refused', () async {
      final (_, b, _) = await pairedDevices();
      final server = await startServer(DeviceHost(b), limits: LanConnectionLimits(maxTotal: 2, maxPerSource: 2));
      final open = <WebSocket>[];
      for (var i = 0; i < 2; i++) {
        open.add(await WebSocket.connect('ws://$_loopback:${server.port}', protocols: [lanSyncSubprotocol]));
      }

      await expectLater(
        WebSocket.connect('ws://$_loopback:${server.port}', protocols: [lanSyncSubprotocol]),
        throwsA(isA<WebSocketException>()),
      );
      for (final socket in open) {
        await socket.close();
      }
    });

    test('a connection that sends no handshake is closed after the first-frame timeout', () async {
      final (_, b, _) = await pairedDevices();
      final server = await startServer(DeviceHost(b), firstFrameTimeout: _shortTimeout);
      final socket = await WebSocket.connect('ws://$_loopback:${server.port}', protocols: [lanSyncSubprotocol]);

      final closedByServer = Completer<void>();
      socket.listen((_) {}, onDone: closedByServer.complete);
      await closedByServer.future.timeout(const Duration(seconds: 5));

      expect(socket.closeCode, isNotNull);
    });
  });

  test('acceptance 7: with the desktop toggle off nothing listens on the sync port', () async {
    final (_, b, _) = await pairedDevices();
    final server = LanSyncServer(host: DeviceHost(b), port: 0, bindAddress: InternetAddress.loopbackIPv4);
    servers.add(server);
    final adapter = DesktopLanSyncAdapter(server);

    expect(await adapter.applyMode(DesktopSyncMode.server), isTrue);
    final port = server.port!;
    (await Socket.connect(_loopback, port)).destroy();

    for (final mode in [DesktopSyncMode.disabled, DesktopSyncMode.client]) {
      expect(await adapter.applyMode(DesktopSyncMode.server), isTrue);
      final listeningPort = server.port!;
      await adapter.applyMode(mode);
      expect(adapter.isServerActive, isFalse);
      await expectLater(Socket.connect(_loopback, listeningPort), throwsA(isA<SocketException>()));
    }
  });

  group('acceptance 8: per-source pairing rate limit', () {
    test('a second handshake from one address within 1 s is refused', () {
      var now = DateTime(2026);
      final limiter = PairingRateLimiter(now: () => now);

      expect(limiter.tryAcquire('192.168.1.10'), isTrue);
      now = now.add(const Duration(milliseconds: 999));
      expect(limiter.tryAcquire('192.168.1.10'), isFalse);
      now = now.add(const Duration(milliseconds: 1));
      expect(limiter.tryAcquire('192.168.1.10'), isTrue);
    });

    test('200 attempts from 50 other addresses do not stop a scan from a new address', () {
      var now = DateTime(2026);
      final limiter = PairingRateLimiter(now: () => now);

      var allowed = 0;
      for (var attempt = 0; attempt < 200; attempt++) {
        now = now.add(const Duration(milliseconds: 250));
        if (limiter.tryAcquire('192.168.2.${attempt % 50}')) allowed++;
      }

      expect(allowed, 200);
      expect(limiter.tryAcquire('192.168.3.1'), isTrue);
    });

    test('a flood from one address is refused and does not block another address', () {
      var now = DateTime(2026);
      final limiter = PairingRateLimiter(now: () => now);

      final results = [for (var i = 0; i < 200; i++) limiter.tryAcquire('192.168.4.1')];

      expect(results.where((ok) => ok), hasLength(1));
      expect(limiter.tryAcquire('192.168.4.2'), isTrue);
    });

    test('the server applies the limit, and a failed psk3 attempt keeps the token usable', () async {
      final (_, b, _) = await pairedDevices();
      var now = DateTime(2026);
      final token = PairingToken.generate(now: DateTime.now());
      final serverKey = await X25519KeyPair.generate();
      final host = DeviceHost(b)
        ..onPair = (transport, source) async {
          final handshake = await token.startResponderHandshake(staticKey: serverKey, now: DateTime.now());
          try {
            await handshake!.readMessage(await transport.receive());
            await transport.send(await handshake.writeMessage());
            await handshake.readMessage(await transport.receive());
            token.consume(handshake, DateTime.now());
          } on Object {
            // A failed handshake ends the connection and keeps the token.
          }
        };
      final server = await startServer(host, pairingLimiter: PairingRateLimiter(now: () => now));
      final tokenBytes = token.exportForQr();

      Future<void> scan(Uint8List scannedToken) async {
        final transport = await const LanSyncClient().connect(_loopback, port: server.port!, forPairing: true);
        try {
          final scannerKey = await X25519KeyPair.generate();
          final handshake = await NoiseHandshake.xxPsk3(
            initiator: true,
            staticKey: scannerKey,
            psk: derivePairingPsk(scannedToken),
            expectedResponderFingerprint: x25519Fingerprint(serverKey.publicKey),
          );
          await transport.send(await handshake.writeMessage());
          await handshake.readMessage(await transport.receive());
          await transport.send(await handshake.writeMessage());
          await transport.receive().timeout(const Duration(milliseconds: 500), onTimeout: () => Uint8List(0));
        } on Object {
          // The wrong-token scan fails inside the handshake.
        } finally {
          await transport.close();
        }
      }

      await scan(Uint8List.fromList(List.filled(tokenBytes.length, 7)));
      expect(token.isConsumed, isFalse);

      await expectLater(
        const LanSyncClient().connect(_loopback, port: server.port!, forPairing: true),
        throwsA(isA<WebSocketException>()),
        reason: 'second pairing handshake within 1 s from the same address',
      );
      expect(token.isConsumed, isFalse);

      now = now.add(const Duration(seconds: 2));
      await scan(tokenBytes);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(token.isConsumed, isTrue);
    });
  });
}

/// Test-only plaintext transport: the same dataset as plain WebSocket frames
/// through a recording proxy. It proves the capture detects markers.
Future<CapturedStreams> _captureTestOnlyPlaintext(List<String> markers) async {
  final sink = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final received = Completer<void>();
  unawaited(sink.forEach((request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    var count = 0;
    socket.listen((_) {
      if (++count == markers.length && !received.isCompleted) received.complete();
    });
  }));
  final proxy = RecordingProxy(sink.port);
  await proxy.start();
  final transport = await const LanSyncClient().connect(_loopback, port: proxy.port);
  for (final marker in markers) {
    await transport.send(Uint8List.fromList(utf8.encode(marker)));
  }
  await received.future.timeout(const Duration(seconds: 5));
  await transport.close();
  await proxy.stop();
  await sink.close(force: true);
  return proxy.captured;
}
