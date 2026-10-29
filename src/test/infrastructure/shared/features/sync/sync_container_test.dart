// T23 acceptance 1 (DI) and carry-over 1: the three containers resolve every
// sync service, the handlers are registered, and the legacy server of
// presentation/api no longer binds the sync port.
import 'dart:io';

import 'package:acore/acore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/demo/services/abstraction/i_demo_data_service.dart';
import 'package:whph/core/application/features/demo/models/demo_reset_blocked_exception.dart';
import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/queries/get_is_paired_query.dart';
import 'package:whph/core/application/features/sync/queries/get_list_sync_members_query.dart';
import 'package:whph/core/application/features/sync/queries/get_sync_pairing_status_query.dart';
import 'package:whph/core/application/features/sync/queries/get_sync_upgrade_progress_query.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_change_store.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_key_store.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_connector.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_state_store.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_status_store.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_runtime.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_session_host.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_upgrade_service.dart';
import 'package:whph/core/application/features/sync/services/reset_local_data_service.dart';
import 'package:whph/core/application/features/sync/services/sync_engine_service.dart';
import 'package:whph/core/application/features/sync/services/sync_ledger_mark_service.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph/core/application/features/sync/services/sync_pairing_service.dart';
import 'package:whph/core/application/features/sync/services/sync_scheduler.dart';
import 'package:whph/core/application/features/sync/services/sync_startup_check_service.dart';
import 'package:whph/core/application/features/sync/commands/start_sync_command.dart';
import 'package:whph/core/application/features/sync/commands/stop_sync_command.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_change_store.dart';
import 'package:whph/infrastructure/shared/features/sync/drift_async_session_device.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_client.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_server.dart';
import 'package:whph/infrastructure/shared/features/sync/legacy_sync_responder.dart';
import 'package:whph/infrastructure/shared/features/sync/pairing_rate_limiter.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'sync_container_test_support.dart';
import 'sync_security_test_support.dart';

void main() {
  late Directory root;
  late IContainer container;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sync-container-');
    container = await buildSyncTestContainer(root);
    await container.resolve<SyncMembershipService>().createFreshIdentity(name: 'Smoke');
  });
  tearDown(() => root.delete(recursive: true));

  test('every sync service resolves', () {
    final resolvers = <String, Object Function()>{
      'ISyncKeyStore': container.resolve<ISyncKeyStore>,
      'ISyncChangeStore': container.resolve<ISyncChangeStore>,
      'DriftSyncChangeStore': container.resolve<DriftSyncChangeStore>,
      'ISyncPeerStateStore': container.resolve<ISyncPeerStateStore>,
      'ISyncPeerStatusStore': container.resolve<ISyncPeerStatusStore>,
      'ISyncUpgradeService': container.resolve<ISyncUpgradeService>,
      'SyncMembershipService': container.resolve<SyncMembershipService>,
      'SyncLedgerMarkService': container.resolve<SyncLedgerMarkService>,
      'SyncStartupCheckService': container.resolve<SyncStartupCheckService>,
      'ResetLocalDataService': container.resolve<ResetLocalDataService>,
      'LegacyDeviceRegistry': container.resolve<LegacyDeviceRegistry>,
      'PairingRateLimiter': container.resolve<PairingRateLimiter>,
      'LanSyncClient': container.resolve<LanSyncClient>,
      'ISyncPeerConnector': container.resolve<ISyncPeerConnector>,
      'DriftAsyncSyncStore': container.resolve<DriftAsyncSyncStore>,
      'DriftAsyncSessionDevice': container.resolve<DriftAsyncSessionDevice>,
      'AsyncSessionDevice': container.resolve<AsyncSessionDevice>,
      'ISyncSessionHost': container.resolve<ISyncSessionHost>,
      'LanSyncServer': container.resolve<LanSyncServer>,
      'ISyncServerControl': container.resolve<ISyncServerControl>,
      'ISyncRuntime': container.resolve<ISyncRuntime>,
      'SyncPairingService': container.resolve<SyncPairingService>,
      'SyncEngineService': container.resolve<SyncEngineService>,
      'SyncScheduler': container.resolve<SyncScheduler>,
    };

    for (final entry in resolvers.entries) {
      expect(entry.value, returnsNormally, reason: entry.key);
    }
  });

  test('the engine services share the objects the server uses', () {
    expect(container.resolve<AsyncSessionDevice>(), same(container.resolve<DriftAsyncSessionDevice>()));
    expect(container.resolve<ISyncServerControl>(), same(container.resolve<LanSyncServer>()));
    expect(container.resolve<ISyncChangeStore>(), same(container.resolve<DriftSyncChangeStore>()));
    expect(container.resolve<AsyncSessionDevice>().name, 'Smoke');
  });

  test('the sync queries and commands run through the mediator', () async {
    final mediator = container.resolve<Mediator>();

    final paired = await mediator.send<GetIsPairedQuery, GetIsPairedQueryResponse>(GetIsPairedQuery());
    final members =
        await mediator.send<GetListSyncMembersQuery, GetListSyncMembersQueryResponse>(GetListSyncMembersQuery());
    final pairing = await mediator.send<GetSyncPairingStatusQuery, SyncPairingStatus>(GetSyncPairingStatusQuery());
    final upgrade =
        await mediator.send<GetSyncUpgradeProgressQuery, SyncUpgradeProgress>(GetSyncUpgradeProgressQuery());

    expect(paired.isPaired, isFalse);
    expect(members.members, isEmpty);
    expect(pairing.phase, SyncPairingPhase.idle);
    expect(upgrade, isA<SyncUpgradeProgress>());
  });

  test('start and stop run the runtime: identity, scheduler, no server on a test run', () async {
    final scheduler = container.resolve<SyncScheduler>();
    final server = container.resolve<ISyncServerControl>();
    final mediator = container.resolve<Mediator>();

    await mediator.send<StartSyncCommand, void>(StartSyncCommand());
    final started = (scheduler.isStarted, server.isRunning);
    await mediator.send<StopSyncCommand, StopSyncCommandResponse>(StopSyncCommand());

    expect(started.$1, isTrue);
    expect(scheduler.isStarted, isFalse);
    expect(server.isRunning, isFalse);
    addTearDown(server.stop);
  });

  test('the demo service gets the membership: a reset on a paired device is refused (U6)', () async {
    final inviter = container.resolve<SyncMembershipService>();
    final joiner = await SecurityDevice.open('joiner', root);
    addTearDown(joiner.close);
    final handover =
        await inviter.prepareHandover(joiner.membership.identity.entry(addedBy: inviter.membership.memberId));
    final registration = await joiner.service.acceptHandover(handover);
    handover.destroy();
    await inviter.completePairing(registration);

    await expectLater(
      container.resolve<IDemoDataService>().resetDemoData(),
      throwsA(isA<DemoResetBlockedException>()),
    );
  });

  test('presentation/api no longer binds the sync port; the LAN server owns it', () {
    final source = File('lib/presentation/api/api.dart').readAsStringSync();

    expect(source, isNot(contains('HttpServer')));
    expect(source, isNot(contains('bind(')));
    expect(syncLanPort, 44040);
    expect(lanSyncPort, syncLanPort);
  });
}
