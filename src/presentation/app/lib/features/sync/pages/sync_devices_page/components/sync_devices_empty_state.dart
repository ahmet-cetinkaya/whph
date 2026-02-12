import 'package:flutter/material.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/components/icon_overlay.dart';

/// Empty state widget for when no sync devices are found.
class SyncDevicesEmptyState extends StatelessWidget {
  final String message;
  final String addDeviceLabel;
  final bool showAddButton;
  final VoidCallback? onAddDevice;

  const SyncDevicesEmptyState({
    super.key,
    required this.message,
    required this.addDeviceLabel,
    this.showAddButton = true,
    this.onAddDevice,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconOverlay(
            icon: Icons.devices_other,
            message: message,
          ),
          if (showAddButton && onAddDevice != null) ...[
            const SizedBox(height: AppTheme.sizeLarge),
            ElevatedButton.icon(
              onPressed: onAddDevice,
              icon: const Icon(Icons.add),
              label: Text(addDeviceLabel),
            ),
          ],
        ],
      ),
    );
  }
}
