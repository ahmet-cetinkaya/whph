/// T10 acc. 4: version negotiation matrix (FR-040, FR-041, FR-043).
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import '../model/model_fixtures.dart';

Hello _hello(int version, int min, String member, String name, {String app = '1.0.0'}) => Hello(
      protocolVersion: version,
      minCompatible: min,
      appVersion: app,
      memberId: member,
      deviceName: name,
      wallMs: 1790000000000,
    );

final class _Outcome {
  _Outcome(this.initiator, this.responder, this.wire);

  final NegotiationResult initiator;
  final NegotiationResult responder;

  /// Every frame both sides put on the wire, in order.
  final List<Uint8List> wire;

  int get changesExchanged =>
      wire.map(SyncCodec.decode).whereType<ChangeBatchMessage>().fold(0, (sum, batch) => sum + batch.envelopes.length);
}

/// Runs the version check over encoded frames; each side sends one change
/// batch only when its own result is [Compatible].
_Outcome _session(Hello initiator, Hello responder) {
  final wire = <Uint8List>[];
  Uint8List send(SyncMessage m) {
    final frame = SyncCodec.encode(m);
    wire.add(frame);
    return frame;
  }

  final helloFrame = send(initiator);
  final receivedHello = SyncCodec.decode(helloFrame) as Hello;
  final responderResult = negotiate(responder, receivedHello);
  final answerFrame = send(answerHello(local: responder, remote: receivedHello));
  final initiatorResult = evaluateHelloAnswer(local: initiator, answer: SyncCodec.decode(answerFrame));

  ChangeBatchMessage oneChange() => ChangeBatchMessage(
        batchId: 1,
        ranges: {
          originA: [SeqRange(41, 42)]
        },
        envelopes: [sealForTest(goldenChangeWithoutCause())],
      );
  if (initiatorResult is Compatible) send(oneChange());
  if (responderResult is Compatible) send(oneChange());
  return _Outcome(initiatorResult, responderResult, wire);
}

void main() {
  test('this build speaks v3 with minimum v3', () {
    expect(syncProtocolVersion, 3);
    expect(minCompatibleProtocolVersion, 3);
    final hello = Hello.current(appVersion: '1', memberId: 'm', deviceName: 'd', wallMs: 0);
    expect([hello.protocolVersion, hello.minCompatible], [3, 3]);
  });

  test('v2 <-> v2 is compatible at v2, whatever the app versions (FR-043)', () {
    final outcome = _session(
      _hello(2, 2, 'member-a', 'Laptop', app: '0.21.0'),
      _hello(2, 2, 'member-b', 'Phone', app: '0.22.3'),
    );
    expect(outcome.initiator, isA<Compatible>().having((c) => c.agreedVersion, 'agreed', 2));
    expect(outcome.responder, isA<Compatible>().having((c) => c.agreedVersion, 'agreed', 2));
    expect(outcome.changesExchanged, 2);
  });

  for (final newerInitiates in [true, false]) {
    final label = newerInitiates ? 'newer initiates' : 'older initiates';

    test('v3(min 2) <-> v2 is compatible at v2 ($label)', () {
      final v3 = _hello(3, 2, 'member-new', 'New laptop');
      final v2 = _hello(2, 2, 'member-old', 'Old phone');
      final outcome = newerInitiates ? _session(v3, v2) : _session(v2, v3);
      expect(outcome.initiator, isA<Compatible>().having((c) => c.agreedVersion, 'agreed', 2));
      expect(outcome.responder, isA<Compatible>().having((c) => c.agreedVersion, 'agreed', 2));
      expect(outcome.changesExchanged, 2);
    });

    test('v3(min 3) <-> v2 requires updating the older device on both sides, 0 changes ($label)', () {
      final v3 = _hello(3, 3, 'member-new', 'New laptop');
      final v2 = _hello(2, 2, 'member-old', 'Old phone');
      final outcome = newerInitiates ? _session(v3, v2) : _session(v2, v3);
      const older = DeviceRef('member-old', 'Old phone');
      expect(outcome.initiator, isA<Incompatible>().having((i) => i.mustUpdate, 'mustUpdate', older));
      expect(outcome.responder, isA<Incompatible>().having((i) => i.mustUpdate, 'mustUpdate', older));
      expect(outcome.changesExchanged, 0);
      final types = outcome.wire.map((f) => SyncCodec.decode(f).type).toList();
      expect(types, [SyncMessageType.hello, SyncMessageType.updateRequired]);
      final update = SyncCodec.decode(outcome.wire.last) as UpdateRequired;
      expect([update.memberId, update.deviceName], ['member-old', 'Old phone']);
    });
  }

  test('negotiation is symmetric', () {
    final hellos = [
      for (final (v, m) in [(1, 1), (2, 1), (2, 2), (3, 2), (3, 3), (4, 2), (4, 4)]) _hello(v, m, 'm$v$m', 'd$v$m'),
    ];
    for (final a in hellos) {
      for (final b in hellos) {
        final ab = negotiate(a, b);
        final ba = negotiate(b, a);
        expect('$ab', '$ba', reason: '${a.memberId} vs ${b.memberId}');
      }
    }
  });

  test('the initiator rejects an inconsistent HelloAck or an unexpected message', () {
    final local = _hello(3, 2, 'a', 'A');
    final forged = HelloAck(hello: _hello(3, 2, 'b', 'B'), agreedVersion: 2);
    expect(() => evaluateHelloAnswer(local: local, answer: forged), throwsA(isA<MalformedMessageException>()));
    expect(() => evaluateHelloAnswer(local: local, answer: const Busy()), throwsA(isA<MalformedMessageException>()));
  });
}
