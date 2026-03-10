import 'package:flutter/material.dart';
import 'package:whph/core/application/features/sync/services/device_handshake_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/sync/components/manual_connection_button.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/features/sync/pages/add_sync_device_page/models/discovered_device.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';
import 'package:acore/acore.dart' show PlatformUtils;

/// Footer widget showing alternative connection methods (QR, manual)
class AlternativeMethodsFooter extends StatelessWidget {
  final VoidCallback onQRScan;
  final Future<void> Function(DiscoveredDevice device) onManualConnect;

  const AlternativeMethodsFooter({
    super.key,
    required this.onQRScan,
    required this.onManualConnect,
  });

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return Container(
      padding: const EdgeInsets.all(AppTheme.sizeMedium),
      margin: const EdgeInsets.only(top: AppTheme.sizeSmall),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTheme.sizeSmall),
              Expanded(
                child: Text(
                  translationService.translate(SyncTranslationKeys.alternativeMethodsHint),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sizeSmall),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // QR Code Scanner Button (mobile only)
              if (!PlatformUtils.isDesktop)
                OutlinedButton.icon(
                  onPressed: onQRScan,
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: Text(translationService.translate(SyncTranslationKeys.scanQRCode)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.sizeSmall,
                      vertical: AppTheme.sizeSmall,
                    ),
                    textStyle: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (!PlatformUtils.isDesktop) const SizedBox(width: AppTheme.sizeSmall),
              OutlinedButton.icon(
                onPressed: () => ManualConnectionButton.showManualConnectionDialog(
                  context,
                  onConnect: (DeviceInfo deviceInfo) async {
                    try {
                      // Create a DiscoveredDevice from the device info retrieved from handshake
                      final device = DiscoveredDevice(
                        name: deviceInfo.deviceName,
                        ipAddress: deviceInfo.ipAddress,
                        port: deviceInfo.port,
                        lastSeen: DateTime.now(),
                        deviceId: deviceInfo.deviceId,
                        platform: deviceInfo.platform,
                        isAlreadyAdded: false,
                      );

                      // Use existing connection logic
                      await onManualConnect(device);
                    } catch (e) {
                      // Connection failed, error is already handled
                      // Just ensure any loading states are cleared
                      OverlayNotificationHelper.hideNotification();
                    }
                  },
                ),
                icon: const Icon(Icons.settings_input_antenna, size: 18),
                label: Text(translationService.translate(SyncTranslationKeys.manualConnection)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.sizeSmall,
                    vertical: AppTheme.sizeSmall,
                  ),
                  textStyle: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
