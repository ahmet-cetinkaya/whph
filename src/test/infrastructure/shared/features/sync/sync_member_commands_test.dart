// T23 acceptance 1: unit tests of the commands and queries of the sync
// application layer, over real devices where the membership matters.
import 'dart:io';

import 'package:acore/acore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/commands/cancel_pairing_command.dart';
import 'package:whph/core/application/features/sync/commands/confirm_group_switch_command.dart';
import 'package:whph/core/application/features/sync/commands/confirm_pairing_code_command.dart';
import 'package:whph/core/application/features/sync/commands/pair_from_invitation_command.dart';
import 'package:whph/core/application/features/sync/commands/remove_sync_member_command.dart';
import 'package:whph/core/application/features/sync/commands/rename_sync_member_command.dart';
import 'package:whph/core/application/features/sync/commands/start_sync_command.dart';
import 'package:whph/core/application/features/sync/commands/stop_sync_command.dart';
import 'package:whph/core/application/features/sync/commands/sync_now_command.dart';
import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/core/application/features/sync/models/sync_run_report.dart';
import 'package:whph/core/application/features/sync/queries/get_list_sync_members_query.dart';
import 'package:whph/core/application/features/sync/queries/get_sync_member_query.dart';
import 'package:whph/core/application/features/sync/queries/get_sync_upgrade_progress_query.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_network_interface_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_connector.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_runner.dart';
import 'package:whph/core/application/features/sync/services/sync_ledger_mark_service.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph/core/application/features/sync/services/sync_pairing_service.dart';
import 'package:whph/core/application/features/sync/services/sync_runtime_service.dart';
import 'package:whph/core/application/features/sync/services/sync_scheduler.dart';
import 'package:whph/core/application/features/sync/services/sync_startup_check_service.dart';
import 'package:whph/core/application/shared/services/mcp_restore_barrier.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_peer_status_store.dart';
import 'package:whph_sync_core/whph_sync_core.dart' hide SyncDevice;

import 'drift_session_test_support.dart';
import 'sync_app_test_support.dart';
import 'sync_security_test_support.dart';

class _FakeLegacyDevices extends Fake implements ISyncDeviceRepository {
  final List<SyncDevice> devices;

  _FakeLegacyDevices([this.devices = const []]);

  @override
  Future<List<SyncDevice>> getAll(
          {bool includeDeleted = false, CustomWhereFilter? customWhereFilter, List<CustomOrder>? customOrder}) async =>
      List.of(devices);

  @override
  Future<SyncDevice?> getById(String id, {bool includeDeleted = false}) async {
    for (final device in devices) {
      if (device.id == id) return device;
    }
    return null;
  }

  @override
  Future<void> delete(SyncDevice id) async => devices.remove(id);
}

SyncDevice _legacyDevice(String id, String name) => SyncDevice(
      id: id,
      createdDate: DateTime.utc(2025, 1, 1),
      fromIp: '192.168.0.2',
      toIp: '192.168.0.3',
      fromDeviceId: 'from-$id',
      toDeviceId: 'to-$id',
      name: name,
      lastSyncDate: DateTime.utc(2025, 6, 1),
    );

class _RecordingServer implements ISyncServerControl {
  final List<String> events;
  @override
  bool isRunning = false;

  _RecordingServer(this.events);

  @override
  Future<bool> start() async {
    events.add('server start');
    return isRunning = true;
  }

  @override
  Future<void> stop() async {
    events.add('server stop');
    isRunning = false;
  }
}

class _RecordingRunner implements ISyncRunner {
  final List<String?> requests = [];

  @override
  Future<SyncRunReport> syncAll() async {
    requests.add(null);
    return const SyncRunReport();
  }

  @override
  Future<SyncRunReport> syncPeer(String memberId) async {
    requests.add(memberId);
    return SyncRunReport(
        peers: [SyncPeerReport(memberId: memberId, result: SessionComplete(SessionStats(), memberId))]);
  }
}

void main() {
  late Directory scratch;
  late EngineFixture fixture;
  late DriftSyncPeerStatusStore statusStore;

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('sync-members-');
    final a = await DriftEngineDevice.open('Alpha', scratch);
    final b = await DriftEngineDevice.open('Beta', scratch);
    addTearDown(a.close);
    addTearDown(b.close);
    await pairDevices(a.security, b.security);
    fixture = await EngineFixture.create(a, b);
    statusStore = fixture.statusStore;
  });
  tearDown(() => scratch.delete(recursive: true));

  SyncMemberSummaryReader reader({
    ISyncDeviceRepository? legacy,
    bool Function(String)? flag,
  }) =>
      SyncMemberSummaryReader(
        membershipService: fixture.local.security.service,
        statusStore: statusStore,
        legacyDeviceRepository: legacy ?? _FakeLegacyDevices(),
        itemsCannotBeApplied: flag ?? (_) => false,
      );

  group('GetListSyncMembersQuery and GetSyncMemberQuery', () {
    test('lists the peer with name, platform and last successful sync, not this device', () async {
      expect((await fixture.syncOnce()).category, isNull);
      await statusStore.savePlatform(fixture.remote.memberId, 'android');

      final members = (await GetListSyncMembersQueryHandler(reader()).call(GetListSyncMembersQuery())).members;

      final peer = members.single;
      expect(peer.memberId, fixture.remote.memberId);
      expect(peer.name, 'Beta');
      expect(peer.platform, 'android');
      expect(peer.lastSuccessfulSync, await fixture.lastSuccess());
      expect(peer.lastSuccessfulSync, isNotNull);
      expect(peer.lastResult, isNull);
      expect(peer.isLegacy, isFalse);
    });

    test('shows each category and keeps the last successful time', () async {
      await fixture.syncOnce();
      final success = await fixture.lastSuccess();
      for (final category in SyncResultCategory.values) {
        await statusStore.setResult(fixture.remote.memberId, category);

        final peer = (await reader().readAll()).single;

        expect(peer.lastResult, category);
        expect(peer.lastSuccessfulSync, success);
      }
    });

    test('a peer that needs re-pairing shows that category', () async {
      await fixture.local.security.peerStates.markNeedsRepairing(fixture.remote.memberId);
      await fixture.local.security.service.refresh();

      final peer = (await reader().readAll()).single;

      expect(peer.lastResult, SyncResultCategory.needsRepairing);
    });

    test('FR-017: the flag comes from the engine for the same peer', () async {
      final peer = (await reader(flag: (id) => id == fixture.remote.memberId).readAll()).single;

      expect(peer.itemsCannotBeApplied, isTrue);
    });

    test('legacy needs_repair rows follow the group members', () async {
      final legacy = _FakeLegacyDevices([_legacyDevice('legacy-1', 'Old phone')]);

      final members = await reader(legacy: legacy).readAll();

      expect(members.map((m) => m.memberId), [fixture.remote.memberId, 'legacy-1']);
      final old = members.last;
      expect(old.isLegacy, isTrue);
      expect(old.name, 'Old phone');
      expect(old.lastResult, SyncResultCategory.needsRepairing);
      expect(old.lastSuccessfulSync, DateTime.utc(2025, 6, 1));
    });

    test('GetSyncMemberQuery finds a member and returns null for an unknown id', () async {
      final handler = GetSyncMemberQueryHandler(reader());

      expect((await handler.call(GetSyncMemberQuery(memberId: fixture.remote.memberId)))?.name, 'Beta');
      expect(await handler.call(GetSyncMemberQuery(memberId: 'nobody')), isNull);
    });

    test('a device without an identity lists no members', () async {
      final fresh = await SecurityDevice.open('fresh', scratch, createIdentity: false);
      addTearDown(fresh.close);
      final emptyReader = SyncMemberSummaryReader(
        membershipService: fresh.service,
        statusStore: DriftSyncPeerStatusStore(fresh.database.db),
        legacyDeviceRepository: _FakeLegacyDevices(),
        itemsCannotBeApplied: (_) => false,
      );

      expect(await emptyReader.readAll(), isEmpty);
    });
  });

  group('member commands', () {
    test('RenameSyncMemberCommand changes the name and rejects an empty one', () async {
      final handler = RenameSyncMemberCommandHandler(fixture.local.security.service);

      await handler.call(RenameSyncMemberCommand(memberId: fixture.remote.memberId, name: '  Kitchen tablet '));

      expect((await reader().readAll()).single.name, 'Kitchen tablet');
      await expectLater(
        handler.call(RenameSyncMemberCommand(memberId: fixture.remote.memberId, name: '   ')),
        throwsA(isA<SyncMembershipException>()),
      );
      await expectLater(
        handler.call(RenameSyncMemberCommand(memberId: 'nobody', name: 'x')),
        throwsA(isA<SyncMembershipException>()),
      );
    });

    test('RemoveSyncMemberCommand revokes the member; a legacy row is deleted instead', () async {
      final legacy = _FakeLegacyDevices([_legacyDevice('legacy-1', 'Old phone')]);
      final handler = RemoveSyncMemberCommandHandler(fixture.local.security.service, legacy);

      await handler.call(RemoveSyncMemberCommand(memberId: 'legacy-1'));
      expect(legacy.devices, isEmpty);
      expect((await reader().readAll()).map((m) => m.memberId), [fixture.remote.memberId]);

      await handler.call(RemoveSyncMemberCommand(memberId: fixture.remote.memberId));
      expect(await reader().readAll(), isEmpty);
      expect(await fixture.local.security.service.isPaired(), isFalse);
    });

    test('SyncNowCommandHandler syncs all peers or one and reports completion', () async {
      final runner = _RecordingRunner();
      final handler = SyncNowCommandHandler(SyncScheduler(runner));

      final all = await handler.call(SyncNowCommand());
      final one = await handler.call(SyncNowCommand(memberId: 'peer-1'));

      expect(runner.requests, [null, 'peer-1']);
      expect(all.isComplete, isTrue, reason: 'nothing to do counts as complete');
      expect(one.isComplete, isTrue);
      expect(one.syncedDeviceCount, 1);
      expect(one.hasErrors, isFalse);
    });
  });

  group('pairing commands without a pairing in progress', () {
    late SyncPairingService pairing;

    setUp(() {
      pairing = SyncPairingService(
        membershipService: fixture.local.security.service,
        connector: fixture.connector,
        statusStore: statusStore,
        networkInterfaces: _NoNetwork(),
        upgradeService: DoneUpgradeService(),
        platform: 'linux',
      );
    });

    test('an unreadable scan fails without connecting', () async {
      final status = await PairFromInvitationCommandHandler(pairing).call(PairFromInvitationCommand(qrText: 'garbage'));

      expect(status.phase, SyncPairingPhase.failed);
      expect(status.errorCode, SyncPairingErrorCode.invalidInvitation);
    });

    test('confirming with nothing to confirm is refused; cancelling is harmless', () async {
      await expectLater(
        ConfirmPairingCodeCommandHandler(pairing).call(ConfirmPairingCodeCommand()),
        throwsA(isA<SyncPairingException>().having((e) => e.code, 'code', SyncPairingErrorCode.noActivePairing)),
      );
      await expectLater(
        ConfirmGroupSwitchCommandHandler(pairing).call(ConfirmGroupSwitchCommand()),
        throwsA(isA<SyncPairingException>()),
      );
      await CancelPairingCommandHandler(pairing).call(CancelPairingCommand());
      expect(pairing.status.phase, SyncPairingPhase.idle);
    });
  });

  group('start and stop', () {
    late List<String> events;
    late _RecordingServer server;
    late SyncScheduler scheduler;

    setUp(() {
      events = [];
      server = _RecordingServer(events);
      scheduler = SyncScheduler(_RecordingRunner());
    });

    SyncRuntimeService runtime({required bool serves}) => SyncRuntimeService(
          startupCheck: SyncStartupCheckService(
            membershipService: fixture.local.security.service,
            keyStore: fixture.local.security.keyStore,
            changeStore: fixture.local.security.database.store,
            marks: SyncLedgerMarkService(
              keyStore: fixture.local.security.keyStore,
              changeStore: fixture.local.security.database.store,
            ),
          ),
          membershipService: fixture.local.security.service,
          server: server,
          scheduler: scheduler,
          deviceName: () async => 'Alpha',
          databaseCreatedThisLaunch: () => false,
          runServerOnStart: serves,
        );

    test('desktop start runs the identity check, the server and the scheduler; stop undoes both', () async {
      final subject = runtime(serves: true);

      await subject.start();
      expect(events, ['server start']);
      expect(scheduler.isStarted, isTrue);

      await subject.stop();
      expect(events, ['server start', 'server stop']);
      expect(scheduler.isStarted, isFalse);
    });

    test('Android start leaves the server to the user', () async {
      await runtime(serves: false).start();

      expect(events, isEmpty);
      expect(scheduler.isStarted, isTrue);
      scheduler.stop();
    });

    test('StartSyncCommandHandler holds the restore barrier while the runtime starts', () async {
      final subject = runtime(serves: true);

      await StartSyncCommandHandler(subject, restoreBarrier: McpRestoreBarrier()).call(StartSyncCommand());
      await StopSyncCommandHandler(subject).call(StopSyncCommand());

      expect(events, ['server start', 'server stop']);
    });
  });

  test('GetSyncUpgradeProgressQuery returns the progress of the upgrade service', () async {
    final handler = GetSyncUpgradeProgressQueryHandler(upgradeService: DoneUpgradeService());

    final progress = await handler.call(GetSyncUpgradeProgressQuery());

    expect(progress.isDone, isTrue);
  });
}

class _NoNetwork extends Fake implements INetworkInterfaceService {}
