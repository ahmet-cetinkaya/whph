import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_connector.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_runtime.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph/core/application/features/sync/services/sync_scheduler.dart';
import 'package:whph/core/application/features/sync/services/sync_startup_check_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

const String _component = 'SyncRuntimeService';

/// Starts sync: the D14 identity check once per launch, the periodic scheduler
/// (PB-3, FR-008) and, where the platform always serves (desktop), the LAN
/// server. Android serves only when the user turns server mode on.
class SyncRuntimeService implements ISyncRuntime {
  final SyncStartupCheckService _startupCheck;
  final SyncMembershipService _membershipService;
  final ISyncServerControl _server;
  final SyncScheduler _scheduler;
  final Future<String> Function() _deviceName;
  final bool Function() _databaseCreatedThisLaunch;
  final bool _runServerOnStart;
  bool _identityChecked = false;

  SyncRuntimeService({
    required SyncStartupCheckService startupCheck,
    required SyncMembershipService membershipService,
    required ISyncServerControl server,
    required SyncScheduler scheduler,
    required Future<String> Function() deviceName,
    required bool Function() databaseCreatedThisLaunch,
    required bool runServerOnStart,
  })  : _startupCheck = startupCheck,
        _membershipService = membershipService,
        _server = server,
        _scheduler = scheduler,
        _deviceName = deviceName,
        _databaseCreatedThisLaunch = databaseCreatedThisLaunch,
        _runServerOnStart = runServerOnStart;

  @override
  Future<void> start() async {
    await _ensureIdentity();
    if (_runServerOnStart && !await _server.start()) {
      Logger.warning('LAN sync server did not start', component: _component);
    }
    _scheduler.start();
  }

  @override
  Future<void> stop() async {
    _scheduler.stop();
    await _server.stop();
  }

  Future<void> _ensureIdentity() async {
    if (_identityChecked) return;
    final action = await _startupCheck.run(
      deviceName: await _deviceName(),
      databaseCreatedThisLaunch: _databaseCreatedThisLaunch(),
    );
    await _membershipService.registerOwnOriginIfMissing();
    _identityChecked = true;
    Logger.info('sync identity check: ${action.name}', component: _component);
  }
}
