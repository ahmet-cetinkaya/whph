import 'dart:io';

import 'package:whph/core/application/features/sync/commands/cancel_pairing_command.dart';
import 'package:whph/core/application/features/sync/commands/confirm_group_switch_command.dart';
import 'package:whph/core/application/features/sync/commands/confirm_pairing_code_command.dart';
import 'package:whph/core/application/features/sync/commands/create_pairing_invitation_command.dart';
import 'package:whph/core/application/features/sync/commands/pair_from_invitation_command.dart';
import 'package:whph/core/application/features/sync/commands/remove_sync_member_command.dart';
import 'package:whph/core/application/features/sync/commands/rename_sync_member_command.dart';
import 'package:whph/core/application/features/sync/commands/start_pairing_with_address_command.dart';
import 'package:whph/core/application/features/sync/commands/sync_now_command.dart';
import 'package:whph/core/application/features/sync/models/sync_member_summary.dart';
import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/queries/get_list_sync_members_query.dart';
import 'package:whph/core/application/features/sync/queries/get_sync_member_query.dart';
import 'package:whph/core/application/features/sync/queries/get_sync_pairing_status_query.dart';
import 'package:whph/core/application/features/sync/queries/get_is_paired_query.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_connector.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_state_store.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_status_store.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_runtime.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_session_host.dart';
import 'package:whph/core/application/features/sync/services/sync_engine_service.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph_sync_core/whph_sync_core.dart';
import 'package:whph/core/application/features/sync/services/sync_pairing_service.dart';
import 'package:whph/core/application/features/sync/services/sync_scheduler.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/commands/start_sync_command.dart';
import 'package:whph/core/application/features/sync/commands/stop_sync_command.dart';
import 'package:whph/core/application/features/sync/queries/get_sync_upgrade_progress_query.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_upgrade_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_network_interface_service.dart';
import 'package:whph/core/application/features/sync/services/network_interface_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_concurrent_connection_service.dart';
import 'package:whph/core/application/features/sync/services/concurrent_connection_service.dart';
import 'package:whph/core/application/features/sync/services/device_handshake_service.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/core/application/shared/services/abstraction/i_restore_barrier.dart';

void registerSyncFeature(
  IContainer container,
  Mediator mediator,
  ISyncDeviceRepository syncDeviceRepository,
) {
  _registerSyncEngineServices(container);

  SyncMemberSummaryReader summaryReader() => SyncMemberSummaryReader(
        membershipService: container.resolve<SyncMembershipService>(),
        statusStore: container.resolve<ISyncPeerStatusStore>(),
        legacyDeviceRepository: syncDeviceRepository,
        itemsCannotBeApplied: (memberId) => container.resolve<SyncEngineService>().itemsCannotBeApplied(memberId),
      );

  // Register network interface service
  container.registerSingleton<INetworkInterfaceService>((_) => NetworkInterfaceService());

  // Register concurrent connection service
  container.registerSingleton<IConcurrentConnectionService>((_) => ConcurrentConnectionService());

  // Register device handshake service
  container.registerSingleton<DeviceHandshakeService>((_) => DeviceHandshakeService());

  mediator
    ..registerHandler<GetSyncUpgradeProgressQuery, SyncUpgradeProgress, GetSyncUpgradeProgressQueryHandler>(
      () => GetSyncUpgradeProgressQueryHandler(upgradeService: container.resolve<ISyncUpgradeService>()),
    )
    ..registerHandler<StartSyncCommand, void, StartSyncCommandHandler>(
      () => StartSyncCommandHandler(
        container.resolve<ISyncRuntime>(),
        restoreBarrier: container.resolve<IRestoreBarrier>(),
      ),
    )
    ..registerHandler<StopSyncCommand, StopSyncCommandResponse, StopSyncCommandHandler>(
      () => StopSyncCommandHandler(container.resolve<ISyncRuntime>()),
    )
    ..registerHandler<GetIsPairedQuery, GetIsPairedQueryResponse, GetIsPairedQueryHandler>(
      () => GetIsPairedQueryHandler(container.resolve<SyncMembershipService>()),
    )
    ..registerHandler<CreatePairingInvitationCommand, CreatePairingInvitationCommandResponse,
        CreatePairingInvitationCommandHandler>(
      () => CreatePairingInvitationCommandHandler(container.resolve<SyncPairingService>()),
    )
    ..registerHandler<PairFromInvitationCommand, SyncPairingStatus, PairFromInvitationCommandHandler>(
      () => PairFromInvitationCommandHandler(container.resolve<SyncPairingService>()),
    )
    ..registerHandler<StartPairingWithAddressCommand, SyncPairingStatus, StartPairingWithAddressCommandHandler>(
      () => StartPairingWithAddressCommandHandler(container.resolve<SyncPairingService>()),
    )
    ..registerHandler<ConfirmPairingCodeCommand, SyncPairingStatus, ConfirmPairingCodeCommandHandler>(
      () => ConfirmPairingCodeCommandHandler(container.resolve<SyncPairingService>()),
    )
    ..registerHandler<CancelPairingCommand, void, CancelPairingCommandHandler>(
      () => CancelPairingCommandHandler(container.resolve<SyncPairingService>()),
    )
    ..registerHandler<ConfirmGroupSwitchCommand, SyncPairingStatus, ConfirmGroupSwitchCommandHandler>(
      () => ConfirmGroupSwitchCommandHandler(container.resolve<SyncPairingService>()),
    )
    ..registerHandler<RemoveSyncMemberCommand, void, RemoveSyncMemberCommandHandler>(
      () => RemoveSyncMemberCommandHandler(container.resolve<SyncMembershipService>(), syncDeviceRepository),
    )
    ..registerHandler<RenameSyncMemberCommand, void, RenameSyncMemberCommandHandler>(
      () => RenameSyncMemberCommandHandler(container.resolve<SyncMembershipService>()),
    )
    ..registerHandler<SyncNowCommand, SyncNowCommandResponse, SyncNowCommandHandler>(
      () => SyncNowCommandHandler(container.resolve<SyncScheduler>()),
    )
    ..registerHandler<GetListSyncMembersQuery, GetListSyncMembersQueryResponse, GetListSyncMembersQueryHandler>(
      () => GetListSyncMembersQueryHandler(summaryReader()),
    )
    ..registerHandler<GetSyncMemberQuery, SyncMemberSummary?, GetSyncMemberQueryHandler>(
      () => GetSyncMemberQueryHandler(summaryReader()),
    )
    ..registerHandler<GetSyncPairingStatusQuery, SyncPairingStatus, GetSyncPairingStatusQueryHandler>(
      () => GetSyncPairingStatusQueryHandler(container.resolve<SyncPairingService>()),
    );
}

/// The services of the replicated-state engine: pairing, the engine over the
/// session host, and the periodic scheduler (PB-3, FR-008). Everything that
/// needs the sync identity resolves lazily.
void _registerSyncEngineServices(IContainer container) {
  container.registerSingleton<SyncPairingService>(
    (c) => SyncPairingService(
      membershipService: c.resolve<SyncMembershipService>(),
      connector: c.resolve<ISyncPeerConnector>(),
      statusStore: c.resolve<ISyncPeerStatusStore>(),
      networkInterfaces: c.resolve<INetworkInterfaceService>(),
      upgradeService: c.resolve<ISyncUpgradeService>(),
      platform: Platform.operatingSystem,
    ),
  );
  container.registerSingleton<SyncEngineService>(
    (c) => SyncEngineService(
      membershipService: c.resolve<SyncMembershipService>(),
      statusStore: c.resolve<ISyncPeerStatusStore>(),
      peerStateStore: c.resolve<ISyncPeerStateStore>(),
      connector: c.resolve<ISyncPeerConnector>(),
      host: c.resolve<ISyncSessionHost>(),
      upgradeService: c.resolve<ISyncUpgradeService>(),
      device: c.resolve<AsyncSessionDevice>(),
      port: syncLanPort,
    ),
  );
  container.registerSingleton<SyncScheduler>((c) => SyncScheduler(c.resolve<SyncEngineService>()));
}
