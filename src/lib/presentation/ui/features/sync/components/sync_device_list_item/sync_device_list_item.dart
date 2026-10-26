import 'dart:math';

import 'package:flutter/material.dart';
import 'package:acore/acore.dart' show DateTimeHelper;
import 'package:whph/core/application/features/sync/models/sync_member_summary.dart';
import 'package:whph/core/application/features/sync/models/sync_status.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/sync/components/sync_member_status.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';

/// Widget that displays a sync group member with its last sync time and status.
class SyncDeviceListItemWidget extends StatefulWidget {
  final SyncMemberSummary member;
  final void Function(String) onRemove;

  /// Starts pairing again; offered for a device that needs re-pairing.
  final void Function(String)? onRepair;
  final bool isBeingSynced;

  /// Outcome of this device's most recent sync attempt in the current app
  /// session; null when it has not been synced since the app started.
  final SyncState? lastSyncResult;

  const SyncDeviceListItemWidget({
    super.key,
    required this.member,
    required this.onRemove,
    this.onRepair,
    this.isBeingSynced = false,
    this.lastSyncResult,
  });

  @override
  State<SyncDeviceListItemWidget> createState() => _SyncDeviceListItemWidgetState();
}

class _SyncDeviceListItemWidgetState extends State<SyncDeviceListItemWidget> with TickerProviderStateMixin {
  final _translationService = container.resolve<ITranslationService>();
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    if (widget.isBeingSynced) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(SyncDeviceListItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBeingSynced && !oldWidget.isBeingSynced) {
      _rotationController.repeat();
    } else if (!widget.isBeingSynced && oldWidget.isBeingSynced) {
      _rotationController.stop();
      _rotationController.reset();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  String _getDeviceName() {
    final name = widget.member.name;
    if (name.isEmpty) return _translationService.translate(SyncTranslationKeys.unnamedDevice);
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSyncing = widget.isBeingSynced;
    final lastSync = widget.member.lastSuccessfulSync;

    return Card(
      elevation: 0,
      color: AppTheme.surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius)),
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.sizeMedium),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                StyledIcon(
                  Icons.devices,
                  isActive: isSyncing,
                ),
                const SizedBox(width: AppTheme.sizeMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getDeviceName(),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            lastSync != null
                                ? DateTimeHelper.formatDateTimeMedium(lastSync, locale: Localizations.localeOf(context))
                                : _translationService.translate(SyncTranslationKeys.neverSynced),
                            style: AppTheme.bodySmall.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          ..._buildLastSyncResultIndicator(),
                        ],
                      ),
                      SyncMemberStatus(
                        member: widget.member,
                        onRepair: widget.onRepair == null ? null : () => widget.onRepair!(widget.member.memberId),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.sizeSmall),
                if (isSyncing)
                  AnimatedBuilder(
                    animation: _rotationController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationController.value * 2 * pi,
                        child: Icon(
                          Icons.sync,
                          color: theme.colorScheme.primary,
                        ),
                      );
                    },
                  )
                else
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                    onPressed: () => widget.onRemove(widget.member.memberId),
                    tooltip: _translationService.translate(SyncTranslationKeys.removeDevice),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLastSyncResultIndicator() {
    final (icon, color, tooltipKey) = switch (widget.lastSyncResult) {
      SyncState.completed => (Icons.check_circle, AppTheme.successColor, SyncTranslationKeys.lastSyncSucceeded),
      SyncState.error => (Icons.warning_amber, AppTheme.warningColor, SyncTranslationKeys.lastSyncFailed),
      _ => (null, null, null),
    };
    if (icon == null) return const [];

    return [
      const SizedBox(width: 4),
      Tooltip(
        message: _translationService.translate(tooltipKey!),
        child: Icon(icon, size: 12, color: color),
      ),
    ];
  }
}
