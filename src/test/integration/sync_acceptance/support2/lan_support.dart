// LAN pieces for the part 2 suites: a host that records how every incoming
// session ended, a started real LAN server, and the plaintext control capture.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_session_host.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_client.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_server.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import '../../../infrastructure/shared/features/sync/lan_test_support.dart';
import 'lab.dart';

const String loopbackHost = '127.0.0.1';
const Duration _plaintextWait = Duration(seconds: 5);

/// Wraps the host of [device] and remembers the result of each session it
/// answered.
class RecordingHost implements ISyncSessionHost {
  final LabDevice device;
  final List<SessionResult> results = [];

  RecordingHost(this.device);

  @override
  Future<SyncPresence> presence() => device.host.presence();

  @override
  Future<SessionResult> respond(ISyncTransport transport, String source) async {
    final result = await device.host.respond(transport, source);
    results.add(result);
    return result;
  }

  @override
  Future<SessionResult> initiate(ISyncTransport transport, String peerMemberId) =>
      device.host.initiate(transport, peerMemberId);

  @override
  Future<void> pair(ISyncTransport transport, String source) => device.host.pair(transport, source);
}

/// Starts a real LAN server for [host] on a free loopback port; stopped when
/// the test ends.
Future<LanSyncServer> startLanServer(ISyncSessionHost host) async {
  final server = LanSyncServer(host: host, port: 0, bindAddress: InternetAddress.loopbackIPv4);
  expect(await server.start(), isTrue);
  addTearDown(server.stop);
  return server;
}

/// Syncs [from] with the server on [port] over a real WebSocket.
Future<SessionResult> syncOverLan(LabDevice from, LabDevice into, int port) =>
    const LanSyncClient().runSession(loopbackHost, (transport) => from.initiate(transport, into.memberId), port: port);

/// The SC-004 control: the same markers sent as plain WebSocket messages through
/// a recording proxy. A capture that cannot see them proves nothing.
Future<CapturedStreams> captureTestOnlyPlaintext(List<String> markers) async {
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
  final transport = await const LanSyncClient().connect(loopbackHost, port: proxy.port);
  for (final marker in markers) {
    await transport.send(Uint8List.fromList(utf8.encode(marker)));
  }
  await received.future.timeout(_plaintextWait);
  await transport.close();
  await proxy.stop();
  await sink.close(force: true);
  return proxy.captured;
}
