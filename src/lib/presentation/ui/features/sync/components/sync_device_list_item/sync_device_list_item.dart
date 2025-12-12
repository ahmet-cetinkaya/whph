import 'package:flutter/material.dart';
import 'package:acore/acore.dart' show DateTimeHelper;
import 'package:whph/core/application/features/sync/queries/get_list_syncs_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';

/// Widget that displays a sync device list item with device info and sync status.
class SyncDeviceListItemWidget extends StatefulWidget {
  final SyncDeviceListItem item;
  final void Function(String) onRemove;
  final bool isBeingSynced;

  const SyncDeviceListItemWidget({
    super.key,
    required this.item,
    required this.onRemove,
    this.isBeingSynced = false,
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
    if (widget.item.name != null) {
      final name = widget.item.name!;
      // Try to extract the partner name if it's in "Local ↔ Remote" format
      if (name.contains(' ↔ ')) {
        // We usually want to show the OTHER device's name
        // But we don't know which one is "other" without context.
        // Assuming the format is "Remote ↔ Local" or similar.
        // For now, let's just return the full name but formatted nicely
        return name.replaceAll(' ↔ ', ' ⇌ ');
      }
      return name;
    }
    return _translationService.translate(SyncTranslationKeys.unnamedDevice);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSyncing = widget.isBeingSynced;

    return Card(
      elevation: 0,
      color: AppTheme.surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius)),
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
        onTap: () {
          // Future: Show details
        },
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.sizeMedium),
          child: Row(
            children: [
              // Device Icon
              StyledIcon(
                Icons.devices, // Default icon since platform is not available in SyncDeviceListItem
                isActive: isSyncing,
              ),

              const SizedBox(width: AppTheme.sizeMedium),

              // Device Info
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.wifi,
                          size: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${widget.item.fromIP} ↔ ${widget.item.toIP}',
                            style: AppTheme.bodySmall.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontFamily: 'monospace',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
                          widget.item.lastSyncDate != null
                              ? DateTimeHelper.formatDateTimeMedium(widget.item.lastSyncDate,
                                  locale: Localizations.localeOf(context))
                              : _translationService.translate(SyncTranslationKeys.neverSynced),
                          style: AppTheme.bodySmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppTheme.sizeSmall),

              // Actions
              if (isSyncing)
                AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotationController.value * 2 * 3.14159,
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
                  onPressed: () => widget.onRemove(widget.item.id),
                  tooltip: _translationService.translate(SyncTranslationKeys.removeDevice),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
