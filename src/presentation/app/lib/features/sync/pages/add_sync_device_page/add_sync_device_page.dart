import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:application/features/sync/services/device_handshake_service.dart';
import 'package:whph/main.dart';
import 'package:whph/features/sync/components/manual_connection_button.dart';
import 'package:whph/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/features/sync/pages/add_sync_device_page/components/alternative_methods_footer.dart';
import 'package:whph/features/sync/pages/add_sync_device_page/components/discovered_device_card.dart';
import 'package:whph/features/sync/pages/add_sync_device_page/components/scanning_status_card.dart';
import 'package:whph/features/sync/pages/add_sync_device_page/controllers/add_sync_device_controller.dart';
import 'package:whph/features/sync/pages/add_sync_device_page/models/discovered_device.dart';
import 'package:whph/features/sync/pages/qr_code_scanner_page.dart';
import 'package:whph/shared/components/styled_icon.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/shared/utils/overlay_notification_helper.dart';
import 'package:acore/acore.dart' show PlatformUtils;

/// Page for adding new sync devices with network discovery capabilities
class AddSyncDevicePage extends StatefulWidget {
  static const String route = '/sync/add-device';

  final VoidCallback? onDeviceAdded;

  const AddSyncDevicePage({
    super.key,
    this.onDeviceAdded,
  });

  @override
  State<AddSyncDevicePage> createState() => _AddSyncDevicePageState();
}

class _AddSyncDevicePageState extends State<AddSyncDevicePage> {
  final _controller = AddSyncDeviceController();
  final _translationService = container.resolve<ITranslationService>();

  @override
  void initState() {
    super.initState();
    _controller.startDeviceDiscovery();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openQRScanner() async {
    HapticFeedback.selectionClick();

    final result = await Navigator.pushNamed(
      context,
      QRCodeScannerPage.route,
    );

    if (result != null && mounted) {
      widget.onDeviceAdded?.call();

      // Small delay to ensure callback processing completes
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _handleDeviceConnect(DiscoveredDevice device) async {
    await _controller.connectToDevice(device, context);

    if (mounted) {
      // Notify parent that device was added successfully
      widget.onDeviceAdded?.call();

      // Small delay to ensure callback processing completes
      await Future.delayed(const Duration(milliseconds: 100));

      // Close the add device page and return to sync devices page immediately
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Padding(
        padding: context.pageBodyPadding,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _buildBody(),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      title: Text(_translationService.translate(SyncTranslationKeys.addSyncDevice)),
      actions: [
        // QR Code Scanner Button (mobile only)
        if (!PlatformUtils.isDesktop)
          IconButton(
            onPressed: _openQRScanner,
            icon: Icon(
              Icons.qr_code_scanner,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: _translationService.translate(SyncTranslationKeys.scanQRCode),
          ),
        // Manual Connection Button
        ManualConnectionButton(
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
              await _handleDeviceConnect(device);
            } catch (e) {
              // Connection failed, error is already handled by controller
              // Just ensure any loading states are cleared
              OverlayNotificationHelper.hideNotification();
            }
          },
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Header Section
        _buildHeader(),

        // Scanning Status
        if (_controller.isScanning) ScanningStatusCard(progress: _controller.scanProgress),

        // Error Message
        if (_controller.errorMessage != null) _buildErrorMessage(),

        // Device List or Empty State
        Expanded(
          child: _controller.discoveredDevices.isEmpty && !_controller.isScanning
              ? _buildEmptyStateWithFooter()
              : _buildDeviceList(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _translationService.translate(SyncTranslationKeys.addSyncDeviceTitle),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppTheme.sizeSmall),
          Text(
            _translationService.translate(SyncTranslationKeys.addSyncDeviceDescription),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.sizeMedium),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: AppTheme.sizeSmall),
          Expanded(
            child: Text(
              _controller.errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StyledIcon(
            Icons.devices_other,
            size: 48,
            isActive: false,
          ),
          const SizedBox(height: AppTheme.sizeMedium),
          Text(
            _translationService.translate(SyncTranslationKeys.noNearbyDevices),
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.sizeSmall),
          Text(
            _translationService.translate(SyncTranslationKeys.noNearbyDevicesHint),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.sizeLarge),

          // Refresh Button
          ElevatedButton.icon(
            onPressed: _controller.startDeviceDiscovery,
            icon: const Icon(Icons.refresh),
            label: Text(_translationService.translate(SyncTranslationKeys.refreshScan)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateWithFooter() {
    return Column(
      children: [
        // Empty State Content
        Expanded(
          child: _buildEmptyState(),
        ),

        // Alternative Methods Footer
        AlternativeMethodsFooter(
          onQRScan: _openQRScanner,
          onManualConnect: _handleDeviceConnect,
        ),
      ],
    );
  }

  Widget _buildDeviceList() {
    return Column(
      children: [
        // Device List
        Expanded(
          child: ListView.builder(
            itemCount:
                _controller.discoveredDevices.length + (!_controller.isScanning ? 1 : 0), // Add 1 for refresh button
            itemBuilder: (context, index) {
              // If this is the last item and scanning is finished, show refresh button
              if (index == _controller.discoveredDevices.length && !_controller.isScanning) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.sizeMedium),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: _controller.startDeviceDiscovery,
                      icon: const Icon(Icons.refresh),
                      label: Text(_translationService.translate(SyncTranslationKeys.refreshScan)),
                    ),
                  ),
                );
              }

              final device = _controller.discoveredDevices[index];
              return DiscoveredDeviceCard(
                device: device,
                onConnect: () => _handleDeviceConnect(device),
                getPlatformIcon: _controller.getPlatformIcon,
              );
            },
          ),
        ),

        // Alternative Methods Footer - only show when scanning is finished
        if (!_controller.isScanning)
          AlternativeMethodsFooter(
            onQRScan: _openQRScanner,
            onManualConnect: _handleDeviceConnect,
          ),
      ],
    );
  }
}
