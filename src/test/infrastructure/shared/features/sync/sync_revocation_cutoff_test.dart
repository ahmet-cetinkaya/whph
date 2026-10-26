// T23 carry-over 5 (T20 acceptance 4): the Drift session apply path refuses a
// change above the revocation cutoff of its author. C writes, A receives it,
// B removes C before it saw that change, and A then relays the change to B:
// B rejects it and its data stays as it was.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'drift_session_test_support.dart';
import 'sync_app_test_support.dart';
import 'sync_security_test_support.dart';

void main() {
  late Directory scratch;

  setUp(() async => scratch = await Directory.systemTemp.createTemp('sync-cutoff-'));
  tearDown(() => scratch.delete(recursive: true));

  Future<(SessionResult, SessionResult)> run(DriftEngineDevice initiator, DriftEngineDevice responder) async {
    final (initiatorEnd, responderEnd) = InMemoryTransport.pair();
    final results = await Future.wait([
      initiator.initiate(initiatorEnd, responder.memberId),
      responder.respond(responderEnd),
    ]);
    return (results[0], results[1]);
  }

  test('a change above the cutoff of a removed member is rejected at apply', () async {
    final a = await DriftEngineDevice.open('A', scratch);
    final b = await DriftEngineDevice.open('B', scratch);
    final c = await DriftEngineDevice.open('C', scratch);
    for (final device in [a, b, c]) {
      addTearDown(device.close);
    }
    await pairDevices(a.security, b.security);
    await pairDevices(a.security, c.security);
    expect((await run(a, b)).$1.isComplete, isTrue, reason: 'B learns that C is a member');
    expect((await run(a, c)).$1.isComplete, isTrue);

    await c.security.database.insertNote('from-c', 'written by C');
    expect((await run(a, c)).$1.isComplete, isTrue);
    expect(await noteTitles(a), contains('written by C'));
    await b.security.service.removeMember(c.memberId);

    final (_, atB) = await run(a, b);

    expect(atB, isA<SessionPartial>(), reason: '$atB');
    expect((atB as SessionPartial).reasons, contains(PartialReason.itemsRejected));
    expect(atB.stats.rejectedByReason, containsPair('revokedAboveCutoff', greaterThan(0)));
    expect(await noteTitles(b), isNot(contains('written by C')));
  });
}
