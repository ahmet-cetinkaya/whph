// T27 part 2, user story 2 (privacy and security): Scenarios 2.1 to 2.5 with
// SC-004, SC-005, SC-006 and SC-014 over real Drift devices, the real session
// engine and a real LAN server (WebSocket on 127.0.0.1). Every attack counts
// at least 100 attempts and every attempt must leave all members unchanged.
@Tags(['t27-slow'])
@Timeout(Duration(minutes: 10))
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_client.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_server.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import '../../infrastructure/shared/features/sync/lan_test_support.dart';
import 'support2/data_ops.dart';
import 'support2/lab.dart';
import 'support2/lan_support.dart';
import 'support2/pairing_support.dart';

const int _attempts = 100;
const int _markerCount = 50;
const Duration _pastExpiry = Duration(minutes: 5, seconds: 1);
const String _englishSyncLocale = 'lib/presentation/ui/features/sync/assets/locales/en.yaml';
const String _newCodeHint = 'Show a new code';
const Duration _attackWait = Duration(seconds: 2);

bool _contains(Uint8List haystack, String needle) {
  final pattern = needle.codeUnits;
  for (var i = 0; i + pattern.length <= haystack.length; i++) {
    var matches = true;
    for (var j = 0; j < pattern.length && matches; j++) {
      matches = haystack[i + j] == pattern[j];
    }
    if (matches) return true;
  }
  return false;
}

/// The device state an attack must not change: synced content and members.
Future<String> _fingerprint(LabDevice device) async =>
    '${await contentOf(device)}|${(device.security.membership.members.keys.toList()..sort()).join(',')}';

void main() {
  group('Scenario 2.1 / SC-004: a recording of the network shows no user data', () {
    late Lab lab;
    late LabDevice a;
    late LabDevice b;
    late List<String> markers;

    setUp(() async {
      lab = await Lab.create();
      a = await lab.add('A');
      b = await lab.add('B', pairWith: a);
      markers = await seedFiftyMarkers(a);
    });
    tearDown(() => lab.close());

    test('Scenario 2.1 / SC-004: 0 of 50 markers in the raw bytes, all 50 on B, plaintext control sees all 50',
        () async {
      final server = await startLanServer(RecordingHost(b));
      final proxy = RecordingProxy(server.port!);
      await proxy.start();
      addTearDown(proxy.stop);

      final result = await syncOverLan(a, b, proxy.port);

      expect(result, isA<SessionComplete>(), reason: '$result');
      expect(markers, hasLength(_markerCount));
      expect(await contentOf(b), await contentOf(a), reason: 'positive control: the data really crossed');
      for (final unmasked in [false, true]) {
        final seen = markers.where((marker) => proxy.captured.occurrences(marker, unmasked: unmasked) > 0);
        expect(seen, isEmpty, reason: 'unmasked=$unmasked');
      }
      expect(proxy.captured.clientToServer.length, greaterThan(0));
      final control = await captureTestOnlyPlaintext(markers);
      final detected = markers.where((marker) => control.occurrences(marker, unmasked: true) > 0);
      expect(detected, hasLength(_markerCount), reason: 'the capture can see plaintext');
    });
  });

  group('Scenarios 2.2 and 2.3 / SC-005: attacks on a real LAN server', () {
    late Lab lab;
    late LabDevice sender;
    late LabDevice target;
    late LabDevice recorder;
    late LabDevice outsider;
    late RecordingHost targetHost;
    late LanSyncServer targetServer;
    late List<Uint8List> capturedFrames;
    late int dataFrameIndex;
    late String targetFingerprint;
    final random = Random(27);

    setUpAll(() async {
      lab = await Lab.create();
      sender = await lab.add('Sender');
      target = await lab.add('Target', pairWith: sender);
      recorder = await lab.add('Recorder', pairWith: sender);
      outsider = await lab.add('Outsider');
      await seedFiftyMarkers(sender, prefix: 'SC005');
      await addNote(outsider, 'outsider-note', 'OUTSIDER-DATA');
      targetHost = RecordingHost(target);
      targetServer = await _startForGroup(targetHost);
      final recorderServer = await _startForGroup(RecordingHost(recorder));

      // One legitimate session towards the recorder yields the frames to attack with.
      final transport = await const LanSyncClient().connect(loopbackHost, port: recorderServer.port!);
      final tap = TappingTransport(transport);
      final result = await sender.initiate(tap, recorder.memberId);
      await transport.close();
      expect(result, isA<SessionComplete>(), reason: '$result');
      capturedFrames = tap.sent;
      dataFrameIndex = _largestFrameIndex(capturedFrames);
      targetFingerprint = await _fingerprint(target);
    });

    tearDownAll(() async {
      for (final server in _servers) {
        await server.stop();
      }
      await lab.close();
    });

    /// Runs [attack] and waits until the target ended that session; the target
    /// must have refused it and stayed unchanged.
    Future<void> attempt(Future<void> Function() attack) async {
      final before = targetHost.results.length;
      await attack();
      await eventually(() => targetHost.results.length > before);
      expect(targetHost.results.last.exchanged, isFalse, reason: 'rejected: ${targetHost.results.last}');
      expect(await _fingerprint(target), targetFingerprint, reason: 'the target changed');
    }

    test('Scenario 2.2 / SC-005: $_attempts non-member connections are refused and disclose presence only', () async {
      for (var i = 0; i < _attempts; i++) {
        await attempt(() async {
          final transport = await const LanSyncClient().connect(loopbackHost, port: targetServer.port!);
          final tap = TappingTransport(transport);
          final outsiderKey = await X25519KeyPair.generate();
          try {
            await SecureChannel.handshake(
              transport: tap,
              initiator: true,
              staticKey: outsiderKey,
              acceptRemoteStatic: (_) => true,
              hello: Uint8List(0),
            );
            await tap.receive().timeout(_attackWait);
            fail('the server must close the connection');
          } on TransportClosedException {
            // Refused: the server ended the connection.
          } finally {
            await transport.close();
          }
          for (final frame in tap.received) {
            expect(_contains(frame, target.memberId), isFalse);
            expect(_contains(frame, target.name), isFalse);
          }
          expect(tap.received.length, lessThanOrEqualTo(1), reason: 'only the handshake answer before auth');
        });
        expect((targetHost.results.last as SessionFailed).category, SessionFailure.notAuthorized);
      }
    });

    test('Scenario 2.2 / SC-005: $_attempts changes injected by a non-member with its own data are not applied',
        () async {
      for (var i = 0; i < _attempts; i++) {
        await attempt(() async {
          final transport = await const LanSyncClient().connect(loopbackHost, port: targetServer.port!);
          final garbage = Uint8List.fromList(List.generate(64 + random.nextInt(200), (_) => random.nextInt(256)));
          final tap = TappingTransport(transport, injectBefore: (index) => index == 1 ? garbage : null);
          // The engine of a device from another group; it also refuses the unknown peer itself.
          final result = await outsider.initiate(tap, target.memberId);
          await transport.close();
          expect(result.exchanged, isFalse);
        });
      }
      expect(await titlesOfNotes(target), isNot(contains('OUTSIDER-DATA')));
    });

    test('Scenario 2.3 / SC-005: $_attempts injected forged frames are rejected', () async {
      for (var i = 0; i < _attempts; i++) {
        final position = i % (dataFrameIndex + 1);
        await attempt(() async {
          final transport = await const LanSyncClient().connect(loopbackHost, port: targetServer.port!);
          final forged = Uint8List.fromList(List.generate(16 + random.nextInt(200), (_) => random.nextInt(256)));
          final tap = TappingTransport(transport, injectBefore: (index) => index == position ? forged : null);
          final result = await sender.initiate(tap, target.memberId);
          await transport.close();
          expect(result.exchanged, isFalse);
        });
      }
    });

    test('Scenario 2.3 / SC-005: $_attempts altered captured frames are rejected', () async {
      for (var i = 0; i < _attempts; i++) {
        final position = i % (dataFrameIndex + 1);
        await attempt(() async {
          final transport = await const LanSyncClient().connect(loopbackHost, port: targetServer.port!);
          final tap = TappingTransport(transport, rewriteSent: (index, frame) {
            if (index != position) return frame;
            return Uint8List.fromList(frame)..[random.nextInt(frame.length)] ^= 1 << random.nextInt(8);
          });
          final result = await sender.initiate(tap, target.memberId);
          await transport.close();
          expect(result.exchanged, isFalse);
        });
      }
    });

    test('Scenario 2.3 / SC-005: $_attempts replayed captured frames are rejected', () async {
      for (var i = 0; i < _attempts; i++) {
        await attempt(() async {
          final transport = await const LanSyncClient().connect(loopbackHost, port: targetServer.port!);
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

    test('Scenarios 2.2 and 2.3: after the attacks a genuine member still syncs (positive control)', () async {
      final result = await syncOverLan(sender, target, targetServer.port!);

      expect(result, isA<SessionComplete>(), reason: '$result');
      expect(await _fingerprint(target), isNot(targetFingerprint));
      await eventually(() => targetHost.results.where((r) => r.exchanged).length == 1);
      expect(targetHost.results.where((r) => r.exchanged), hasLength(1), reason: 'only the genuine session exchanged');
      expect(targetHost.results.length, greaterThanOrEqualTo(5 * _attempts));
    });
  });

  group('Scenario 2.4 / SC-006: a removed device', () {
    late Lab lab;
    late LabDevice a;
    late LabDevice b;
    late LabDevice c;
    final capturedAfterRemoval = <ChangeBatchMessage>[];

    setUpAll(() async {
      lab = await Lab.create();
      a = await lab.add('A');
      b = await lab.add('B', pairWith: a);
      c = await lab.add('C', pairWith: a);
      await addNote(a, 'before-removal', 'BEFORE-REMOVAL');
      await lab.converge();
      expect(await sameContent(lab.devices), isTrue);
      expect(a.security.membership.members.keys, contains(c.memberId));

      await a.security.service.removeMember(c.memberId);
      a.setHooks(SessionHooks(outgoingBatch: (batch) {
        capturedAfterRemoval.add(batch);
        return batch;
      }));
      for (var i = 0; i < 40; i++) {
        await addNote(a, 'after-removal-$i', 'AFTER-REMOVAL-$i', content: 'secret after removal $i');
      }
      expect((await lab.session(a, b)).bothComplete, isTrue, reason: 'B learns the removal and the new data');
    });

    tearDownAll(() => lab.close());

    test('Scenario 2.4 / SC-006: $_attempts attempts of C with each remaining member fail', () async {
      final aBefore = await _fingerprint(a);
      final bBefore = await _fingerprint(b);
      for (final remaining in [a, b]) {
        for (var i = 0; i < _attempts; i++) {
          final pair = await lab.session(c, remaining);
          expect(pair.exchangedNothing, isTrue, reason: '${remaining.name} attempt $i: $pair');
          expect(pair.responder, isA<SessionFailed>());
        }
      }
      expect(await _fingerprint(a), aBefore);
      expect(await _fingerprint(b), bBefore);
      expect(await titlesOfNotes(c), isNot(contains('AFTER-REMOVAL-0')));
    });

    test('Scenario 2.4 / SC-006: the remaining members do not start sessions with C either', () async {
      for (final remaining in [a, b]) {
        final pair = await lab.session(remaining, c);
        expect(pair.exchangedNothing, isTrue, reason: '${remaining.name}: $pair');
      }
    });

    test('Scenario 2.4 / SC-006: a change captured after the removal cannot be read by C', () async {
      final newest = a.security.membership.keyring.highest!;
      expect(b.security.membership.keyring.holds(newest), isTrue);
      expect(c.security.membership.keyring.holds(newest), isFalse);

      final afterRemoval = [
        for (final batch in capturedAfterRemoval)
          for (final envelope in batch.envelopes)
            if (envelope.epoch == newest) envelope,
      ];
      expect(afterRemoval.length, greaterThanOrEqualTo(_attempts));
      final cipher = EnvelopeCipher(groupId: c.security.membership.groupId!, keyring: c.security.membership.keyring);
      final readable = afterRemoval.where((envelope) => cipher.open(envelope) is EnvelopeOpened);
      expect(readable, isEmpty);
    });
  });

  group('SC-014: change data given to a non-member yields nothing', () {
    late Lab lab;
    late LabDevice a;
    late LabDevice b;
    late LabDevice outsider;
    final outgoing = <ChangeEnvelope>[];

    setUpAll(() async {
      lab = await Lab.create();
      a = await lab.add('A');
      b = await lab.add('B', pairWith: a);
      outsider = await lab.add('Outsider');
      for (var i = 0; i < 40; i++) {
        await addNote(a, 'sc14-$i', 'SC014-TITLE-$i', content: 'SC014-BODY-$i');
      }
      a.setHooks(SessionHooks(outgoingBatch: (batch) {
        outgoing.addAll(batch.envelopes);
        return batch;
      }));
      expect((await lab.session(a, b)).bothComplete, isTrue);
    });

    tearDownAll(() => lab.close());

    test('SC-014: $_attempts outgoing envelopes opened with a non-member keyring yield 0 readable items', () {
      expect(outgoing.length, greaterThanOrEqualTo(_attempts));
      final cipher = EnvelopeCipher(
        groupId: a.security.membership.groupId!,
        keyring: outsider.security.membership.keyring,
      );
      for (final envelope in outgoing.take(_attempts)) {
        expect(cipher.open(envelope), isNot(isA<EnvelopeOpened>()));
        expect(_contains(envelope.ciphertext, 'SC014-'), isFalse);
      }
    });

    test('SC-014: a stored held envelope is ciphertext only and unreadable for a non-member', () async {
      final laterEpoch = EpochId(9, a.memberId);
      final laterKey = Uint8List.fromList(List.generate(32, (i) => i * 7 + 3));
      final sideRing = GroupKeyring()..add(laterEpoch, laterKey);
      final groupId = a.security.membership.groupId!;
      await addNote(a, 'sc14-held', 'SC014-HELD-TITLE');
      a.setHooks(SessionHooks(outgoingBatch: (batch) {
        final open = EnvelopeCipher(groupId: groupId, keyring: a.security.membership.keyring);
        final seal = EnvelopeCipher(groupId: groupId, keyring: sideRing);
        final nonces = NonceSource();
        return ChangeBatchMessage(
          batchId: batch.batchId,
          ranges: batch.ranges,
          manifests: batch.manifests,
          envelopes: [
            for (final e in batch.envelopes)
              if (e.pk == 'sc14-held')
                seal.seal((open.open(e) as EnvelopeOpened).change, nonces, epoch: laterEpoch)
              else
                e,
          ],
        );
      }));
      expect((await lab.session(a, b)).bothComplete, isTrue, reason: 'a missing key is held, not a failure');

      final rows = await b.db.rows("SELECT envelope FROM sync_held_envelope WHERE reason = 'missingKey'");
      expect(rows, isNotEmpty);
      final outsiderCipher = EnvelopeCipher(groupId: groupId, keyring: outsider.security.membership.keyring);
      for (final row in rows) {
        final stored = row['envelope'] as Uint8List;
        expect(_contains(stored, 'SC014-HELD'), isFalse);
        expect(outsiderCipher.open(ChangeEnvelope.decode(stored)), isNot(isA<EnvelopeOpened>()));
      }
    });

    test('SC-014: $_attempts sessions of the non-member with the captured data apply 0 items on members', () async {
      final aBefore = await _fingerprint(a);
      final bBefore = await _fingerprint(b);
      for (var i = 0; i < _attempts; i++) {
        final target = i.isEven ? a : b;
        final pair = await lab.session(outsider, target);
        expect(pair.exchangedNothing, isTrue, reason: '$pair');
      }
      expect(await _fingerprint(a), aBefore);
      expect(await _fingerprint(b), bBefore);
    });
  });

  group('Scenario 2.5: a QR code that expired or was already used', () {
    late Lab lab;
    late DateTime clock;

    setUp(() async {
      lab = await Lab.create();
      clock = DateTime.utc(2026, 1, 1);
    });
    tearDown(() => lab.close());

    Future<PairingSide> sideOf(String name) async => PairingSide.of(await lab.add(name), () => clock);

    String englishMessage(String key) {
      final lines = File(_englishSyncLocale).readAsLinesSync();
      final line = lines.firstWhere((l) => l.trimLeft().startsWith('$key:'));
      return line.substring(line.indexOf(':') + 1).trim();
    }

    test('Scenario 2.5: a scan after the code expired fails and tells the user to show a new code', () async {
      final inviter = await sideOf('inviter');
      final scanner = await sideOf('scanner');
      scanner.connectTo(inviter);
      final invitation = await inviter.service.createInvitation();
      clock = clock.add(_pastExpiry);

      final status = await scanner.service.pairFromInvitation(invitation);

      expect(status.phase, SyncPairingPhase.failed);
      expect(status.errorCode, SyncPairingErrorCode.codeExpiredOrUsed);
      expect(englishMessage('code_expired_or_used'), contains(_newCodeHint));
      expect(await inviter.device.security.service.isPaired(), isFalse);
      expect(await scanner.device.security.service.isPaired(), isFalse);
    });

    test('Scenario 2.5: a scan of a code that was already used fails and tells the user to show a new code', () async {
      final inviter = await sideOf('inviter');
      final first = await sideOf('first');
      final second = await sideOf('second');
      first.connectTo(inviter);
      second.connectTo(inviter);
      final invitation = await inviter.service.createInvitation();
      expect((await first.service.pairFromInvitation(invitation)).phase, SyncPairingPhase.completed);

      final status = await second.service.pairFromInvitation(invitation);

      expect(status.phase, SyncPairingPhase.failed);
      expect(status.errorCode, SyncPairingErrorCode.codeExpiredOrUsed);
      expect(englishMessage('code_expired_or_used'), contains(_newCodeHint));
      expect(inviter.device.security.membership.members.keys, isNot(contains(second.device.memberId)));
      expect(await second.device.security.service.isPaired(), isFalse);
    });
  });
}

final List<LanSyncServer> _servers = [];

Future<LanSyncServer> _startForGroup(RecordingHost host) async {
  final server = LanSyncServer(host: host, port: 0, bindAddress: InternetAddress.loopbackIPv4);
  expect(await server.start(), isTrue);
  _servers.add(server);
  return server;
}

int _largestFrameIndex(List<Uint8List> frames) {
  var largest = 0;
  for (var i = 1; i < frames.length; i++) {
    if (frames[i].length > frames[largest].length) largest = i;
  }
  return largest;
}

Future<Set<String>> titlesOfNotes(LabDevice device) async => {
      for (final row in await device.db.rows('SELECT title FROM note_table')) '${row['title']}',
    };
