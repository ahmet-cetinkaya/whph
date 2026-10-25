// T22 acceptance 3 (SC-005): over a real LAN server, 100 attempts each of a
// non-member connection, an injected forged frame, an altered captured frame
// and a replayed captured frame are all rejected and change no member.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_client.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_server.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import '../infrastructure/shared/features/sync/lan_test_support.dart';

const int _attempts = 100;
const int _markerCount = 5;
const String _loopback = '127.0.0.1';

void main() {
  late SyncDevice sender;
  late SyncDevice target;
  late SyncDevice recorder;
  late DeviceHost targetHost;
  late LanSyncServer targetServer;
  late LanSyncServer recorderServer;
  late List<Uint8List> capturedFrames;
  late int dataFrameIndex;
  late String targetChecksum;
  final random = Random(5);

  setUpAll(() async {
    sender = await newDevice('Sender', seed: 11);
    target = await newDevice('Target', seed: 12);
    recorder = await newDevice('Recorder', seed: 13);
    await SyncDevice.pair(inviter: sender, joiner: target);
    await SyncDevice.pair(inviter: sender, joiner: recorder);
    seedMarkers(sender, _markerCount, prefix: 'SC005');

    targetHost = DeviceHost(target);
    targetServer = await _start(targetHost);
    final recorderHost = DeviceHost(recorder);
    recorderServer = await _start(recorderHost);

    // One legitimate session towards the recorder yields the frames to attack.
    final transport = await const LanSyncClient().connect(_loopback, port: recorderServer.port!);
    final tap = TappingTransport(transport);
    final result = await sender.initiate(tap, peerMemberId: recorder.memberId);
    expect(result, isA<SessionComplete>(), reason: '$result');
    await transport.close();
    capturedFrames = tap.sent;
    dataFrameIndex = _largestFrameIndex(capturedFrames);
    targetChecksum = contentChecksum(target);
    expect(dataFrameIndex, greaterThan(2), reason: 'the data batch follows the handshake and exchange frames');
  });

  tearDownAll(() async {
    await targetServer.stop();
    await recorderServer.stop();
  });

  /// Runs [attack] and waits until the target server has ended that session.
  Future<void> attempt(Future<void> Function() attack) async {
    final before = targetHost.results.length;
    await attack();
    await eventually(() => targetHost.results.length > before);
    final ended = targetHost.results.last;
    expect(ended.exchanged, isFalse, reason: 'rejected: $ended');
    expect(contentChecksum(target), targetChecksum, reason: 'the target changed');
  }

  test('non-member connections are rejected and disclose presence only', () async {
    for (var i = 0; i < _attempts; i++) {
      final before = targetHost.results.length;
      await attempt(() async {
        final transport = await const LanSyncClient().connect(_loopback, port: targetServer.port!);
        final tap = TappingTransport(transport);
        // The outsider skips its own membership check and speaks plain Noise.
        final outsiderKey = await X25519KeyPair.generate();
        try {
          await SecureChannel.handshake(
            transport: tap,
            initiator: true,
            staticKey: outsiderKey,
            acceptRemoteStatic: (_) => true,
            hello: Uint8List(0),
          );
          await tap.receive().timeout(const Duration(seconds: 2));
          fail('the server must close the connection');
        } on TransportClosedException {
          // Rejected: the server ended the connection.
        } finally {
          await transport.close();
        }
        await eventually(() => targetHost.results.length > before);
        expect((targetHost.results.last as SessionFailed).category, SessionFailure.notAuthorized);
        expect(tap.received.length, lessThanOrEqualTo(1), reason: 'only the handshake answer before auth');
        for (final frame in tap.received) {
          expect(_contains(frame, target.memberId), isFalse);
          expect(_contains(frame, target.name), isFalse);
        }
      });
    }
  });

  test('injected forged frames are rejected', () async {
    for (var i = 0; i < _attempts; i++) {
      final position = i % (dataFrameIndex + 1);
      await attempt(() async {
        final transport = await const LanSyncClient().connect(_loopback, port: targetServer.port!);
        final forged = Uint8List.fromList(List.generate(16 + random.nextInt(200), (_) => random.nextInt(256)));
        final tap = TappingTransport(transport, injectBefore: (index) => index == position ? forged : null);
        final result = await sender.initiate(tap, peerMemberId: target.memberId);
        await transport.close();
        expect(result.exchanged, isFalse);
      });
    }
  });

  test('altered captured frames are rejected', () async {
    for (var i = 0; i < _attempts; i++) {
      final position = i % (dataFrameIndex + 1);
      await attempt(() async {
        final transport = await const LanSyncClient().connect(_loopback, port: targetServer.port!);
        final tap = TappingTransport(transport, rewriteSent: (index, frame) {
          if (index != position) return frame;
          final altered = Uint8List.fromList(frame)..[random.nextInt(frame.length)] ^= 1 << random.nextInt(8);
          return altered;
        });
        final result = await sender.initiate(tap, peerMemberId: target.memberId);
        await transport.close();
        expect(result.exchanged, isFalse);
      });
    }
  });

  test('replayed captured frames are rejected', () async {
    for (var i = 0; i < _attempts; i++) {
      await attempt(() async {
        final transport = await const LanSyncClient().connect(_loopback, port: targetServer.port!);
        try {
          for (final frame in capturedFrames.take(dataFrameIndex + 1)) {
            await transport.send(frame);
          }
          await transport.receive().timeout(const Duration(milliseconds: 200), onTimeout: () => Uint8List(0));
        } on TransportClosedException {
          // The server ended the replayed session.
        } finally {
          await transport.close();
        }
      });
    }
  });

  test('after the attacks a genuine member still syncs (positive control)', () async {
    final transport = await const LanSyncClient().connect(_loopback, port: targetServer.port!);
    final result = await sender.initiate(transport, peerMemberId: target.memberId);
    await transport.close();

    expect(result, isA<SessionComplete>(), reason: '$result');
    expect(contentChecksum(target), isNot(targetChecksum));
    await eventually(() => targetHost.results.length == 4 * _attempts + 1);
    expect(targetHost.results.where((r) => r.exchanged), hasLength(1), reason: 'only the genuine session exchanged');
    expect(titlesOf(target).where((title) => title.startsWith('SC005')), hasLength(_markerCount));
  });
}

Future<LanSyncServer> _start(DeviceHost host) async {
  final server = LanSyncServer(host: host, port: 0, bindAddress: InternetAddress.loopbackIPv4);
  expect(await server.start(), isTrue);
  return server;
}

int _largestFrameIndex(List<Uint8List> frames) {
  var largest = 0;
  for (var i = 1; i < frames.length; i++) {
    if (frames[i].length > frames[largest].length) largest = i;
  }
  return largest;
}

bool _contains(Uint8List frame, String text) {
  final pattern = text.codeUnits;
  for (var i = 0; i + pattern.length <= frame.length; i++) {
    var matches = true;
    for (var j = 0; j < pattern.length && matches; j++) {
      matches = frame[i + j] == pattern[j];
    }
    if (matches) return true;
  }
  return false;
}
