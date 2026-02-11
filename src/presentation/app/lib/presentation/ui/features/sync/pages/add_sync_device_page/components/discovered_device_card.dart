import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/features/sync/pages/add_sync_device_page/models/discovered_device.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Card widget for displaying a discovered device in the list
class DiscoveredDeviceCard extends StatelessWidget {
  final DiscoveredDevice device;
  final VoidCallback onConnect;
  final IconData Function(String platform) getPlatformIcon;

  const DiscoveredDeviceCard({
    super.key,
    required this.device,
    required this.onConnect,
    required this.getPlatformIcon,
  });

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
      elevation: 0,
      color: AppTheme.surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeMedium),
        child: Row(
          children: [
            // Leading icon - centered
            StyledIcon(
              Icons.devices,
              isActive: true,
            ),
            const SizedBox(width: AppTheme.sizeMedium),

            // Content - takes available space
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    device.name,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${device.ipAddress}:${device.port}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        getPlatformIcon(device.platform),
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          translationService.translate(
                            SyncTranslationKeys.lastSeen,
                            namedArgs: {
                              'time': DateFormat.Hms().format(device.lastSeen),
                            },
                          ),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.sizeMedium),

            // Trailing button - centered
            _buildTrailingWidget(context, translationService),
          ],
        ),
      ),
    );
  }

  Widget _buildTrailingWidget(BuildContext context, ITranslationService translationService) {
    if (device.isAlreadyAdded) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.sizeMedium,
          vertical: AppTheme.sizeSmall,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              translationService.translate(SyncTranslationKeys.alreadyAdded),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return ElevatedButton(
      onPressed: onConnect,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.sizeMedium,
          vertical: AppTheme.sizeSmall,
        ),
      ),
      child: Text(translationService.translate(SyncTranslationKeys.connect)),
    );
  }
}
