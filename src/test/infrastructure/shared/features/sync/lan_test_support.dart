// Shared helpers for the T22 tests: engine devices behind a real LAN server,
// a recording TCP proxy and a WebSocket frame reader.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_session_host.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

const int _baseWallMs = 1767225600000;
const String _testAppVersion = '9.9.9';
const String _testPlatform = 'linux';

/// A session host backed by an in-memory engine device.
class DeviceHost implements ISyncSessionHost {
  final SyncDevice device;
  final SessionHooks hooks;
  final List<SessionResult> results = [];
  Future<void> Function(ISyncTransport transport, String source)? onPair;

  DeviceHost(this.device, {this.hooks = const SessionHooks()});

  @override
  Future<SyncPresence> presence() async => SyncPresence(
        memberId: device.memberId,
        deviceName: device.name,
        platform: _testPlatform,
        appVersion: _testAppVersion,
        protocolVersion: syncProtocolVersion,
      );

  @override
  Future<SessionResult> respond(ISyncTransport transport, String source) async {
    final result = await device.respond(transport, hooks: hooks);
    results.add(result);
    return result;
  }

  @override
  Future<void> pair(ISyncTransport transport, String source) async {
    final handler = onPair;
    if (handler != null) await handler(transport, source);
  }
}

Future<SyncDevice> newDevice(String name, {required int seed}) => SyncDevice.create(
      name: name,
      clock: () => _baseWallMs,
      ids: SyncIdSource(Random(seed)),
      config: SyncEngineConfig(delay: (_) async {}),
    );

/// A checksum of the synced (non-security) content of [device].
String contentChecksum(SyncDevice device) {
  final lines = [
    for (final cell in device.store.cells)
      if (!SecurityTables.contains(cell.key.table)) '${cell.key}=${cell.value}@${cell.clock}',
  ]..sort();
  return lines.join('\n');
}

/// Writes [count] task rows whose titles each contain a unique marker.
List<String> seedMarkers(SyncDevice device, int count, {String prefix = 'MARKER'}) {
  final markers = <String>[];
  for (var i = 0; i < count; i++) {
    final marker = '$prefix-${i.toString().padLeft(3, '0')}-secret-title';
    markers.add(marker);
    final rowId = '$prefix-row-$i';
    device
      ..write(CellKey('task', rowId, CellKey.existenceCol), null)
      ..write(CellKey('task', rowId, 'title'), marker);
  }
  return markers;
}

Set<String> titlesOf(SyncDevice device) => {
      for (final cell in device.store.cells)
        if (cell.key.col == 'title') '${cell.value}',
    };

/// Bytes that crossed a TCP proxy, per direction.
class CapturedStreams {
  final BytesBuilder clientToServer = BytesBuilder();
  final BytesBuilder serverToClient = BytesBuilder();

  int occurrences(String needle, {required bool unmasked}) {
    final streams = [clientToServer.toBytes(), serverToClient.toBytes()];
    final haystacks = unmasked ? streams.map(webSocketPayloads) : streams;
    return haystacks.fold(0, (total, bytes) => total + _count(bytes, needle));
  }

  static int _count(Uint8List haystack, String needle) {
    final pattern = needle.codeUnits;
    var found = 0;
    for (var i = 0; i + pattern.length <= haystack.length; i++) {
      var matches = true;
      for (var j = 0; j < pattern.length && matches; j++) {
        matches = haystack[i + j] == pattern[j];
      }
      if (matches) found++;
    }
    return found;
  }
}

/// A TCP proxy on loopback that copies every byte to [target] and records it.
class RecordingProxy {
  final int targetPort;
  final CapturedStreams captured = CapturedStreams();
  late final ServerSocket _listener;

  RecordingProxy(this.targetPort);

  int get port => _listener.port;

  Future<void> start() async {
    _listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _listener.listen(_forward);
  }

  Future<void> stop() => _listener.close();

  Future<void> _forward(Socket client) async {
    final upstream = await Socket.connect(InternetAddress.loopbackIPv4, targetPort);
    client.listen(
      (data) {
        captured.clientToServer.add(data);
        upstream.add(data);
      },
      onDone: upstream.destroy,
      onError: (_) => upstream.destroy(),
    );
    upstream.listen(
      (data) {
        captured.serverToClient.add(data);
        client.add(data);
      },
      onDone: client.destroy,
      onError: (_) => client.destroy(),
    );
  }
}

/// The payload bytes of every WebSocket frame in a captured stream (the
/// client's masking is removed, as any observer can).
Uint8List webSocketPayloads(Uint8List stream) {
  final out = BytesBuilder();
  var offset = _afterHttpHeader(stream);
  while (offset + 2 <= stream.length) {
    final masked = stream[offset + 1] & 0x80 != 0;
    var length = stream[offset + 1] & 0x7f;
    var cursor = offset + 2;
    if (length == 126 && cursor + 2 <= stream.length) {
      length = (stream[cursor] << 8) | stream[cursor + 1];
      cursor += 2;
    } else if (length == 127 && cursor + 8 <= stream.length) {
      length = ByteData.sublistView(stream, cursor, cursor + 8).getUint64(0);
      cursor += 8;
    }
    final key = masked ? stream.sublist(cursor, cursor + 4) : null;
    cursor += masked ? 4 : 0;
    final end = min(cursor + length, stream.length);
    for (var i = cursor; i < end; i++) {
      out.addByte(key == null ? stream[i] : stream[i] ^ key[(i - cursor) % 4]);
    }
    offset = end;
  }
  return out.toBytes();
}

int _afterHttpHeader(Uint8List stream) {
  final marker = '\r\n\r\n'.codeUnits;
  for (var i = 0; i + marker.length <= stream.length; i++) {
    if (stream[i] == marker[0] &&
        stream[i + 1] == marker[1] &&
        stream[i + 2] == marker[2] &&
        stream[i + 3] == marker[3]) {
      return i + marker.length;
    }
  }
  return stream.length;
}

/// Records the frames a session sends and receives, and can rewrite a sent
/// frame or inject an extra one before it.
class TappingTransport implements ISyncTransport {
  final ISyncTransport inner;
  final List<Uint8List> sent = [];
  final List<Uint8List> received = [];
  final Uint8List Function(int index, Uint8List frame)? rewriteSent;
  final Uint8List? Function(int index)? injectBefore;

  TappingTransport(this.inner, {this.rewriteSent, this.injectBefore});

  @override
  bool get isClosed => inner.isClosed;

  @override
  Future<void> send(Uint8List frame) async {
    final index = sent.length;
    sent.add(Uint8List.fromList(frame));
    final forged = injectBefore?.call(index);
    if (forged != null) await inner.send(forged);
    await inner.send(rewriteSent?.call(index, frame) ?? frame);
  }

  @override
  Future<Uint8List> receive() async {
    final frame = await inner.receive();
    received.add(Uint8List.fromList(frame));
    return frame;
  }

  @override
  Future<void> close() => inner.close();
}

/// Waits until [condition] holds, or fails after [timeout].
Future<void> eventually(bool Function() condition, {Duration timeout = const Duration(seconds: 10)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('condition not met within $timeout');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
