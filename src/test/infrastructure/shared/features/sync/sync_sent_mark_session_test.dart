// T21 sent-seq mark (acceptance 10) inside a real session: the engine writes
// the file-backed mark before it sends above it, retries a failing write 3
// times, then ends `partial(storage error)` while it still applies incoming
// changes; the next session sends once the write succeeds.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:whph/infrastructure/shared/features/sync/file_sync_key_store.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_client.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_server.dart';
import 'package:whph/infrastructure/shared/utils/owner_only_file_utils.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'lan_test_support.dart';

const String _loopback = '127.0.0.1';
const int _firstAttempt = 1;
const Duration _retryWait = Duration(milliseconds: 100);

void main() {
  late Directory root;
  late bool failWrites;
  late int writeAttempts;
  late FileSyncKeyStore ledger;
  late SyncDevice sender;
  late SyncDevice peer;
  late LanSyncServer server;
  final marksWhenSending = <int>[];

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sent-mark-session');
    failWrites = false;
    writeAttempts = 0;
    marksWhenSending.clear();
    ledger = FileSyncKeyStore(
      keyDirectory: Directory('${root.path}/data'),
      ledgerDirectory: Directory('${root.path}/state'),
      writer: OwnerOnlyAtomicWriter(beforeRename: (temporaryPath) async {
        if (_raisesSentMark(temporaryPath, ledger)) writeAttempts++;
        if (failWrites) throw StateError('simulated ledger failure');
      }),
    );
    sender = await SyncDevice.create(
      name: 'Sender',
      clock: () => 1767225600000,
      ids: SyncIdSource(Random(31)),
      // The retries wait long enough for the peer's batches to arrive; after the
      // failure the engine acks later batches without committing them (U11/Efe-R1).
      config: SyncEngineConfig(delay: (_) => Future<void>.delayed(_retryWait)),
      ledger: ledger,
    );
    peer = await newDevice('Peer', seed: 32);
    await SyncDevice.pair(inviter: sender, joiner: peer);
    server = LanSyncServer(host: DeviceHost(peer), port: 0, bindAddress: InternetAddress.loopbackIPv4);
    expect(await server.start(), isTrue);
  });

  tearDown(() async {
    await server.stop();
    await root.delete(recursive: true);
  });

  Future<SessionResult> runSession() async {
    final transport = await const LanSyncClient().connect(_loopback, port: server.port!);
    final result = await sender.initiate(
      transport,
      peerMemberId: peer.memberId,
      hooks: SessionHooks(
        afterBatchSent: (_) => marksWhenSending.add(ledger.entryOf(sender.store.localOrigin)!.maxSentSeq),
      ),
    );
    await transport.close();
    return result;
  }

  int mark() => ledger.entryOf(sender.store.localOrigin)!.maxSentSeq;

  test('a failing mark write stops the send, keeps applying incoming and the next session sends', () async {
    seedMarkers(sender, 3, prefix: 'OUT');
    seedMarkers(peer, 3, prefix: 'IN');
    final markBefore = mark();
    failWrites = true;

    final failed = await runSession();

    expect(failed, isA<SessionPartial>(), reason: '$failed');
    expect((failed as SessionPartial).reasons, contains(PartialReason.storageError));
    expect(writeAttempts, _firstAttempt + 3, reason: 'one sent-mark write and 3 retries');
    expect(mark(), markBefore, reason: 'the mark never moved');
    expect(titlesOf(peer).where((t) => t.startsWith('OUT')), isEmpty, reason: 'nothing above the mark was sent');
    expect(titlesOf(sender).where((t) => t.startsWith('IN')), hasLength(3), reason: 'incoming changes still applied');

    failWrites = false;
    final recovered = await runSession();

    expect(recovered, isA<SessionComplete>(), reason: '$recovered');
    expect(titlesOf(peer).where((t) => t.startsWith('OUT')), hasLength(3));
    expect(mark(), greaterThanOrEqualTo(sender.store.highestOwnSeq));
    expect(marksWhenSending, isNotEmpty);
    expect(marksWhenSending.every((sentMark) => sentMark >= sender.store.highestOwnSeq), isTrue,
        reason: 'the mark was on disk before the batch left');
  });

  test('the mark is never lowered by a later session', () async {
    seedMarkers(sender, 2, prefix: 'OUT');
    expect(await runSession(), isA<SessionComplete>());
    final highest = mark();

    seedMarkers(peer, 2, prefix: 'IN');
    expect(await runSession(), isA<SessionComplete>());

    expect(mark(), greaterThanOrEqualTo(highest));
  });
}

/// Whether the ledger file about to be renamed carries a higher sent mark
/// than the one in [ledger] (a sent-mark write, not a watermark flush).
bool _raisesSentMark(String temporaryPath, FileSyncKeyStore ledger) {
  final document = jsonDecode(File(temporaryPath).readAsStringSync()) as Map<String, dynamic>;
  if (ledger.entries.isEmpty) return false;
  final written = (document['origins'] as List).cast<Map<String, dynamic>>().last['max_sent_seq'] as int;
  final current = ledger.entries.last.maxSentSeq;
  return written > current;
}
