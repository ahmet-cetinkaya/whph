import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart' hide Container;
import 'package:whph/core/application/features/sync/commands/remove_sync_member_command.dart';
import 'package:whph/core/application/features/sync/models/sync_member_summary.dart';
import 'package:whph/core/application/features/sync/queries/get_is_paired_query.dart';
import 'package:whph/core/application/features/sync/queries/get_list_sync_members_query.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph/core/application/features/sync/models/sync_status.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_connector.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/domain/features/sync/models/desktop_sync_mode.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/desktop/features/sync/desktop_lan_sync_adapter.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/components/kebab_menu.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/features/sync/components/sync_connect_info_button.dart';
import 'package:whph/presentation/ui/features/sync/components/firewall_permission_card/firewall_permission_card.dart';
import 'package:whph/presentation/ui/features/sync/components/remove_member_dialog.dart';
import 'package:whph/presentation/ui/features/sync/components/needs_repairing_card.dart';
import 'package:whph/presentation/ui/features/sync/components/removed_from_group_card.dart';
import 'package:whph/presentation/ui/features/sync/components/sync_device_list_item/sync_device_list_item.dart';
import 'package:whph/presentation/ui/features/sync/components/sync_pairing_status_listener.dart';
import 'package:whph/presentation/ui/features/sync/components/sync_repair_banner.dart';
import 'package:whph/presentation/ui/features/sync/components/sync_upgrade_progress_banner.dart';
import 'package:whph/presentation/ui/features/sync/pages/add_sync_device_page/add_sync_device_page.dart';
import 'package:whph/presentation/ui/features/sync/services/sync_pairing_flow.dart';
import 'package:whph/presentation/ui/features/sync/pages/sync_devices_page/mixins/server_mode_mixin.dart';
import 'package:whph/presentation/ui/features/sync/pages/sync_devices_page/mixins/desktop_sync_mode_mixin.dart';
import 'package:whph/presentation/ui/features/sync/pages/sync_devices_page/mixins/sync_status_mixin.dart';
import 'package:whph/presentation/ui/features/sync/pages/sync_devices_page/components/server_mode_toggle.dart';
import 'package:whph/presentation/ui/features/sync/pages/sync_devices_page/components/sync_devices_empty_state.dart';

/// Page for managing sync devices and server/client mode configuration.
class SyncDevicesPage extends StatefulWidget {
  static const route = '/sync-devices';

  const SyncDevicesPage({super.key});

  @override
  State<SyncDevicesPage> createState() => _SyncDevicesPageState();
}

class _SyncDevicesPageState extends State<SyncDevicesPage>
    with
        AutomaticKeepAliveClientMixin,
        TickerProviderStateMixin,
        ServerModeMixin,
        DesktopSyncModeMixin,
        SyncStatusMixin {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _settingRepository = container.resolve<ISettingRepository>();
  late final _repairBannerPreference =
      SyncRepairBannerPreference(settingRepository: _settingRepository, mediator: _mediator);
  ISyncServerControl? _syncServer;
  DesktopLanSyncAdapter? _desktopLanSyncAdapter;

  List<SyncMemberSummary>? _members;
  SyncGroupState _groupState = SyncGroupState.ungrouped;
  bool _isRepairBannerDismissed = true;
  SyncStatus _currentSyncStatus = const SyncStatus(state: SyncState.idle);
  late AnimationController _syncButtonAnimationController;

  // Mixin service accessors
  @override
  Mediator get mediator => _mediator;
  @override
  ITranslationService get translationService => _translationService;
  @override
  ISettingRepository get settingRepository => _settingRepository;
  @override
  ISyncServerControl? get syncServer => _syncServer;
  @override
  DesktopLanSyncAdapter? get desktopLanSyncAdapter => _desktopLanSyncAdapter;
  @override
  AnimationController get syncButtonAnimationController => _syncButtonAnimationController;
  @override
  SyncStatus get currentSyncStatus => _currentSyncStatus;
  @override
  set currentSyncStatus(SyncStatus value) => _currentSyncStatus = value;
  @override
  Future<void> Function() get onRefresh => refresh;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initializeAnimationControllers();
    _loadPreferences();
    refresh();
  }

  void _initializeServices() {
    if (Platform.isAndroid) {
      _syncServer = container.resolve<ISyncServerControl>();
      return;
    }

    if (PlatformUtils.isDesktop) {
      _desktopLanSyncAdapter = container.resolve<DesktopLanSyncAdapter>();
      isServerMode = desktopSyncMode == DesktopSyncMode.server;
    }
  }

  void _initializeAnimationControllers() {
    _syncButtonAnimationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  Future<void> _loadPreferences() async {
    await loadServerModePreference();
    await loadDesktopSyncModePreference();
  }

  @override
  void dispose() {
    _syncButtonAnimationController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    await _loadMembers();
    await _loadGroupState();
    await _loadRepairBannerState();
  }

  Future<void> _loadMembers() async {
    await AsyncErrorHandler.execute<GetListSyncMembersQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(SyncTranslationKeys.loadDevicesError),
      operation: () => _mediator.send<GetListSyncMembersQuery, GetListSyncMembersQueryResponse>(
        GetListSyncMembersQuery(),
      ),
      onSuccess: (response) {
        if (mounted) setState(() => _members = response.members);
      },
    );
  }

  Future<void> _loadGroupState() async {
    try {
      final response = await _mediator.send<GetIsPairedQuery, GetIsPairedQueryResponse>(GetIsPairedQuery());
      if (mounted) setState(() => _groupState = response.groupState);
    } catch (e) {
      Logger.error('Reading the sync group state failed: ${e.runtimeType}');
    }
  }

  Future<void> _loadRepairBannerState() async {
    try {
      final isDismissed = await _repairBannerPreference.isDismissed();
      if (mounted) setState(() => _isRepairBannerDismissed = isDismissed);
    } catch (e) {
      Logger.error('Reading the re-pair banner state failed: ${e.runtimeType}');
    }
  }

  Future<void> _dismissRepairBanner() async {
    setState(() => _isRepairBannerDismissed = true);
    try {
      await _repairBannerPreference.dismiss();
    } catch (e) {
      Logger.error('Saving the re-pair banner state failed: ${e.runtimeType}');
    }
  }

  bool get _shouldShowRepairBanner =>
      !_isRepairBannerDismissed && (_members?.any((member) => member.isLegacy) ?? false);

  Future<void> _sync() async {
    // Only allow sync in client mode
    if (isServerMode) {
      Logger.warning('Sync cannot be initiated in server mode');
      return;
    }

    await runManualSync();
  }

  Future<void> _removeDevice(String memberId) async {
    final member = _members?.firstWhere((candidate) => candidate.memberId == memberId);
    if (member == null) return;
    final confirmed = await RemoveMemberDialog.confirm(context, deviceName: member.name);
    if (!confirmed || !mounted) return;

    await AsyncErrorHandler.execute<void>(
      context: context,
      errorMessage: _translationService.translate(SyncTranslationKeys.removeDeviceError),
      operation: () => _mediator.send<RemoveSyncMemberCommand, void>(RemoveSyncMemberCommand(memberId: memberId)),
      onSuccess: (_) async {
        if (mounted) await refresh();
      },
    );
  }

  void _repairDevice(String memberId) => _showAddDevicePage();

  Future<void> _showAddDevicePage() async {
    final result = await ResponsiveDialogHelper.showResponsiveDialog<bool>(
      context: context,
      size: DialogSize.max,
      child: AddSyncDevicePage(
        onDeviceAdded: () {
          Logger.info('Device added from AddSyncDevicePage - refreshing device list');
          if (mounted) {
            refresh();
          }
        },
      ),
    );

    if (result == true && mounted) {
      Logger.info('AddSyncDevicePage completed successfully - performing final refresh');
      await refresh();
    }
  }

  void _onFirewallPermissionChanged() {
    Logger.debug('Firewall permission status changed');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(_translationService.translate(SyncTranslationKeys.pageTitle)),
        actions: _buildAppBarActions(),
      ),
      body: Padding(
        padding: context.pageBodyPadding,
        child: SyncPairingStatusListener(
          onFinished: (status) {
            SyncPairingFlow.showOutcome(context, status);
            refresh();
          },
          child: CustomScrollView(
          slivers: [
            // Firewall permission card (desktop only)
            SliverToBoxAdapter(
              child: FirewallPermissionCard(
                onPermissionChanged: _onFirewallPermissionChanged,
              ),
            ),

            // Server Mode Toggle (Android only)
            if (Platform.isAndroid) ...[
              SliverToBoxAdapter(
                child: ServerModeToggle(
                  isServerMode: isServerMode,
                  onToggle: toggleServerMode,
                  title: _translationService.translate(SyncTranslationKeys.serverModeTitle),
                  subtitle: isServerMode
                      ? _translationService.translate(SyncTranslationKeys.serverModeActive)
                      : _translationService.translate(SyncTranslationKeys.serverModeInactive),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppTheme.sizeLarge),
              ),
            ],

            const SliverToBoxAdapter(child: SyncUpgradeProgressBanner()),

            if (_groupState == SyncGroupState.removedFromGroup)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.sizeMedium),
                  child: RemovedFromGroupCard(onPair: _showAddDevicePage),
                ),
              ),

            if (_groupState == SyncGroupState.needsRepairing)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.sizeMedium),
                  child: NeedsRepairingCard(onPair: _showAddDevicePage),
                ),
              ),

            if (_shouldShowRepairBanner)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.sizeMedium),
                  child: SyncRepairBanner(onPair: _showAddDevicePage, onDismiss: _dismissRepairBanner),
                ),
              ),

            // Device List
            if (_members == null || _members!.isEmpty)
              SliverFillRemaining(
                child: SyncDevicesEmptyState(
                  message: _translationService.translate(SyncTranslationKeys.noDevicesFound),
                  addDeviceLabel: _translationService.translate(SyncTranslationKeys.addDeviceTooltip),
                  showAddButton: !isServerMode,
                  onAddDevice: _showAddDevicePage,
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final member = _members![index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
                      child: SyncDeviceListItemWidget(
                        key: ValueKey(member.memberId),
                        member: member,
                        onRemove: _removeDevice,
                        onRepair: _repairDevice,
                        lastSyncResult: lastSyncResultOf(member.memberId),
                      ),
                    );
                  },
                  childCount: _members!.length,
                ),
              ),
          ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      // Sync button - behavior depends on mode
      if (!isServerMode && (_members?.isNotEmpty ?? false))
        IconButton(
          onPressed: _currentSyncStatus.isSyncing ? null : _sync,
          icon: _currentSyncStatus.isSyncing
              ? AnimatedBuilder(
                  animation: _syncButtonAnimationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _syncButtonAnimationController.value * 2 * 3.14159,
                      child: const Icon(Icons.sync),
                    );
                  },
                )
              : const Icon(Icons.sync),
          color: _currentSyncStatus.isSyncing
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)
              : Theme.of(context).colorScheme.primary,
          tooltip: _currentSyncStatus.isSyncing
              ? _translationService.translate(SyncTranslationKeys.syncInProgress)
              : _translationService.translate(SyncTranslationKeys.syncTooltip),
        ),

      // Add Device button - only show when not in server mode
      if (!isServerMode)
        IconButton(
          onPressed: _showAddDevicePage,
          icon: const Icon(Icons.add),
          color: Theme.of(context).colorScheme.primary,
          tooltip: _translationService.translate(SyncTranslationKeys.addDeviceTooltip),
        ),

      // Connection Info Button - show only when in server mode
      if (isServerMode) SyncConnectInfoButton(),

      // Kebab menu
      KebabMenu(
        helpTitleKey: SyncTranslationKeys.helpTitle,
        helpMarkdownContentKey: SyncTranslationKeys.helpContent,
        additionalMenuItems: [
          // Mobile sync mode toggle (only on Android)
          if (Platform.isAndroid)
            PopupMenuItem<String>(
              value: 'toggle_server',
              child: Row(
                children: [
                  Icon(isServerMode ? Icons.stop : Icons.wifi_tethering, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(isServerMode
                      ? _translationService.translate(SyncTranslationKeys.serverModeStopMenu)
                      : _translationService.translate(SyncTranslationKeys.serverModeStartMenu)),
                ],
              ),
            ),
          // Desktop sync mode toggle (only on Desktop)
          if (PlatformUtils.isDesktop)
            PopupMenuItem<String>(
              value: 'toggle_client',
              child: Row(
                children: [
                  Icon(desktopSyncMode == DesktopSyncMode.client ? Icons.stop : Icons.wifi_tethering,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(desktopSyncMode == DesktopSyncMode.client
                      ? _translationService.translate(SyncTranslationKeys.desktopSyncModeStopMenu)
                      : _translationService.translate(SyncTranslationKeys.desktopSyncModeStartMenu)),
                ],
              ),
            ),
        ],
        onMenuItemSelected: (value) {
          switch (value) {
            case 'toggle_server':
              toggleServerMode();
              break;
            case 'toggle_client':
              toggleDesktopSyncMode();
              break;
          }
        },
      ),
    ];
  }
}
