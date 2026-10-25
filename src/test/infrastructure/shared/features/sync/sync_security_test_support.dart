// Shared devices for the T20 tests: a real Drift database, the file key store
// in temp directories, and the membership service.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_peer_state_store.dart';
import 'package:whph/infrastructure/shared/features/sync/file_sync_key_store.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import '../../../persistence/sync/drift_sync_test_support.dart';

const _originHexLength = 32;

/// One device: Drift database + key files + membership service.
class SecurityDevice {
  final String name;
  SyncTestDevice database;
  FileSyncKeyStore keyStore;
  DriftSyncPeerStateStore peerStates;
  SyncMembershipService service;
  final Directory root;

  SecurityDevice._(this.name, this.database, this.keyStore, this.peerStates,
      this.service, this.root);

  static Future<SecurityDevice> open(String name, Directory parent,
      {bool createIdentity = true}) async {
    final root = await parent.createTemp('$name-');
    final originHex = name.codeUnits
        .map((c) => c.toRadixString(16).padLeft(2, '0'))
        .join()
        .padRight(_originHexLength, '0');
    final database = await SyncTestDevice.open(name,
        origin: originHex.substring(0, _originHexLength));
    final keyStore = FileSyncKeyStore(
      keyDirectory: Directory('${root.path}/data'),
      ledgerDirectory: Directory('${root.path}/state'),
    );
    final peerStates = DriftSyncPeerStateStore(database.db);
    final service = SyncMembershipService(
        keyStore: keyStore,
        changeStore: database.store,
        peerStateStore: peerStates);
    if (createIdentity) await service.createFreshIdentity(name: name);
    return SecurityDevice._(
        name, database, keyStore, peerStates, service, root);
  }

  Membership get membership => service.membership;
  String get memberId => membership.memberId;
  MemberEntry get entry => membership.identity.entry(addedBy: memberId);

  Future<void> close() async {
    await database.close();
    await root.delete(recursive: true);
  }
}

/// Pairs [joiner] into [inviter]'s group through the real handover.
Future<void> pairDevices(SecurityDevice inviter, SecurityDevice joiner,
    {bool confirmGroupSwitch = false}) async {
  final joinerEntry =
      joiner.membership.identity.entry(addedBy: inviter.memberId);
  if (joiner.service
          .requiresGroupSwitchConfirmation(inviter.membership.groupId) &&
      !confirmGroupSwitch) {
    throw const SyncMembershipException(
        'joining leaves the current group; confirmation required');
  }
  final handover = await inviter.service.prepareHandover(joinerEntry);
  final registration = await joiner.service
      .acceptHandover(handover, confirmGroupSwitch: confirmGroupSwitch);
  handover.destroy();
  await inviter.service.completePairing(registration);
}

/// One full exchange between two devices: registrations, every origin's
/// changes, then the membership rebuild on both.
Future<void> syncDevices(SecurityDevice a, SecurityDevice b) async {
  await a.database.store
      .mergeRegistrations(await b.database.store.readRegistrations());
  await b.database.store
      .mergeRegistrations(await a.database.store.readRegistrations());
  await pullChanges(a.database, b.database);
  await pullChanges(b.database, a.database);
  await a.service.refresh();
  await b.service.refresh();
}

/// Whether a Noise handshake from [initiator] to [responder] is refused by the
/// responder's membership check.
Future<bool> handshakeRefused(
    SecurityDevice initiator, SecurityDevice responder) async {
  final (initiatorEnd, responderEnd) = InMemoryTransport.pair();
  final responderRun = SecureChannel.handshake(
    transport: responderEnd,
    initiator: false,
    staticKey: responder.membership.identity.x25519,
    acceptRemoteStatic: responder.membership.acceptsStatic,
  );
  final initiatorRun = SecureChannel.handshake(
    transport: initiatorEnd,
    initiator: true,
    staticKey: initiator.membership.identity.x25519,
    acceptRemoteStatic: initiator.membership.acceptsStatic,
    hello: Uint8List(0),
  );
  var refused = false;
  Future<void> observe(Future<Object?> run) =>
      run.then<void>((_) {}, onError: (Object error) async {
        refused = refused || error is SyncCryptoException;
        // The side that rejects stops talking; closing wakes the other side.
        await initiatorEnd.close();
        await responderEnd.close();
      });
  await Future.wait([observe(responderRun), observe(initiatorRun)]);
  await initiatorEnd.close();
  await responderEnd.close();
  return refused;
}

Matcher throwsMembership() => throwsA(isA<SyncMembershipException>());
