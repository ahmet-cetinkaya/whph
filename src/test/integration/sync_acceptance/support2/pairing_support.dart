// One side of a pairing for Scenario 2.5: a lab device, its real pairing
// service and the clock the invitation expires on.
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_network_interface_service.dart';
import 'package:whph/core/application/features/sync/services/sync_pairing_service.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_peer_status_store.dart';

import '../../../infrastructure/shared/features/sync/sync_app_test_support.dart';
import 'lab.dart';

class _LoopbackNetwork extends Fake implements INetworkInterfaceService {
  @override
  Future<List<String>> getPreferredIPAddresses() async => [loopbackAddress];
}

class PairingSide {
  final LabDevice device;
  final SyncPairingService service;
  final LoopbackConnector connector;

  PairingSide._(this.device, this.service, this.connector);

  factory PairingSide.of(LabDevice device, DateTime Function() now) {
    final connector = LoopbackConnector();
    return PairingSide._(
      device,
      SyncPairingService(
        membershipService: device.security.service,
        connector: connector,
        statusStore: DriftSyncPeerStatusStore(device.db.db),
        networkInterfaces: _LoopbackNetwork(),
        upgradeService: DoneUpgradeService(),
        platform: labPlatform,
        now: now,
      ),
      connector,
    );
  }

  /// This side connects to [answering].
  void connectTo(PairingSide answering) {
    connector.responder = (transport) => answering.service.respond(transport, loopbackAddress);
  }
}
