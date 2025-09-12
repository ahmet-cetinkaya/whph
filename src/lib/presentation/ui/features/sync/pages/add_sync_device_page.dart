import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_network_interface_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_concurrent_connection_service.dart';
import 'package:whph/core/application/features/sync/services/device_handshake_service.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/features/sync/components/manual_ip_input_dialog.dart';
import 'package:whph/presentation/ui/features/sync/pages/qr_code_scanner_page.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';
import 'package:whph/presentation/ui/shared/utils/network_utils.dart';
import 'package:whph/presentation/ui/shared/utils/device_info_helper.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/main.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/commands/save_sync_command.dart';
import 'package:whph/core/application/features/sync/queries/get_sync_query.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_service.dart';
import 'package:acore/acore.dart' show BusinessException;

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
  final _networkInterfaceService = container.resolve<INetworkInterfaceService>();
  final _connectionService = container.resolve<IConcurrentConnectionService>();
  final _handshakeService = container.resolve<DeviceHandshakeService>();
  final _translationService = container.resolve<ITranslationService>();
  
  bool _isScanning = false;
  final List<DiscoveredDevice> _discoveredDevices = [];
  Timer? _scanTimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startDeviceDiscovery();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }

  Future<void> _startDeviceDiscovery() async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
      _discoveredDevices.clear();
    });

    try {
      // Get local network interfaces
      final interfaces = await _networkInterfaceService.getActiveNetworkInterfaces();
      if (interfaces.isEmpty) {
        setState(() {
          _errorMessage = _translationService.translate(SyncTranslationKeys.noActiveInterfacesError);
          _isScanning = false;
        });
        return;
      }

      // Scan network ranges with timeout
      await _scanNetworkRanges(interfaces).timeout(
        const Duration(seconds: 15), // 15-second timeout for better UX
        onTimeout: () {
          if (mounted) {
            setState(() {
              _isScanning = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _translationService.translate(SyncTranslationKeys.deviceDiscoveryFailedError, namedArgs: {'error': e.toString()});
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _scanNetworkRanges(List<NetworkInterfaceInfo> interfaces) async {
    final Set<String> scannedAddresses = {};
    int totalBatches = 0;
    final startTime = DateTime.now();
    
    for (final interface in interfaces) {
      if (!interface.isWiFi && !interface.isEthernet) continue;
      
      final networkBase = _getNetworkBase(interface.ipAddress);
      if (networkBase == null) continue;

      // Scan common IP ranges in parallel (focus on common ranges first)
      final futures = <Future<void>>[];
      
      // Start with more common IP ranges (1-50, 100-150, 200-254)
      final commonRanges = [
        for (int i = 1; i <= 50; i++) i,      // Common router/device range
        for (int i = 100; i <= 150; i++) i,  // Common DHCP range
        for (int i = 200; i <= 254; i++) i,  // Higher end range
        for (int i = 51; i <= 99; i++) i,    // Fill remaining gap
        for (int i = 151; i <= 199; i++) i,  // Fill remaining gap
      ];
      
      for (final i in commonRanges) {
        final targetIP = '$networkBase.$i';
        if (targetIP != interface.ipAddress && !scannedAddresses.contains(targetIP)) {
          scannedAddresses.add(targetIP);
          futures.add(_checkDeviceAt(targetIP));
        }
      }

      // Process in smaller batches for better responsiveness
      for (int batchStart = 0; batchStart < futures.length; batchStart += 10) {
        final batchEnd = (batchStart + 10).clamp(0, futures.length);
        await Future.wait(futures.sublist(batchStart, batchEnd));
        
        totalBatches++;
        
        // Smaller delay for better responsiveness
        await Future.delayed(const Duration(milliseconds: 50));
        
        if (!mounted) return;
        
        // Early exit conditions for better UX
        final elapsedTime = DateTime.now().difference(startTime);
        
        // Stop scanning if we found devices and have scanned enough
        if (_discoveredDevices.isNotEmpty && totalBatches > 5) {
          break;
        }
        
        // Stop scanning if no devices found after reasonable time
        if (_discoveredDevices.isEmpty && elapsedTime.inSeconds > 10) {
          break;
        }
      }
    }

    // Scanning completed - update UI state
    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  String? _getNetworkBase(String ipAddress) {
    final parts = ipAddress.split('.');
    if (parts.length != 4) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  Future<void> _checkDeviceAt(String ipAddress) async {
    try {
      // Perform handshake to get device information
      final deviceInfo = await _handshakeService.getDeviceInfo(ipAddress, 44040);

      if (deviceInfo != null && mounted) {
        // Check if device is already paired
        final isAlreadyAdded = await _checkIfDeviceAlreadyAdded(deviceInfo.deviceId);
        
        final device = DiscoveredDevice(
          name: deviceInfo.deviceName,
          ipAddress: deviceInfo.ipAddress,
          port: deviceInfo.port,
          lastSeen: deviceInfo.discoveredAt,
          deviceId: deviceInfo.deviceId,
          platform: deviceInfo.platform,
          isAlreadyAdded: isAlreadyAdded,
        );

        setState(() {
          // Check if device is already in the list
          final existingIndex = _discoveredDevices.indexWhere(
            (d) => d.deviceId == device.deviceId || 
                   (d.ipAddress == device.ipAddress && d.port == device.port),
          );
          
          if (existingIndex >= 0) {
            // Update existing device with fresh info
            _discoveredDevices[existingIndex] = device;
          } else {
            // Add new device
            _discoveredDevices.add(device);
          }
          
          // Sort by device name for consistent ordering
          _discoveredDevices.sort((a, b) => a.name.compareTo(b.name));
        });

        // Provide haptic feedback on device discovery
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      // Silently ignore connection failures during discovery
    }
  }

  Future<bool> _checkIfDeviceAlreadyAdded(String deviceId) async {
    try {
      final mediator = container.resolve<Mediator>();
      final deviceIdService = container.resolve<IDeviceIdService>();
      final localDeviceId = await deviceIdService.getDeviceId();
      
      // Check if device already exists
      final existingDevice = await mediator.send<GetSyncDeviceQuery, GetSyncDeviceQueryResponse?>(
        GetSyncDeviceQuery(fromDeviceId: deviceId, toDeviceId: localDeviceId)
      );

      return existingDevice?.id.isNotEmpty == true && existingDevice?.deletedDate == null;
    } catch (e) {
      return false; // If we can't check, assume it's not added
    }
  }

  Future<void> _connectToDevice(DiscoveredDevice device) async {
    HapticFeedback.selectionClick();
    
    if (!mounted) return;

    await AsyncErrorHandler.executeChain<void>(
      context: context,
      errorMessage: _translationService.translate(SyncTranslationKeys.saveDeviceError),
      operation: () async {
        // Show testing connection message
        OverlayNotificationHelper.showLoading(
          context: context,
          message: _translationService.translate(SyncTranslationKeys.testingConnection),
          duration: const Duration(seconds: 15),
        );

        // Test connection again to ensure device is still available
        final isReachable = await _connectionService.testWebSocketConnection(
          device.ipAddress,
          device.port,
          timeout: const Duration(seconds: 5),
        );

        if (!isReachable) {
          throw BusinessException(
            _translationService.translate(SyncTranslationKeys.connectionFailedError),
            SyncTranslationKeys.connectionFailedError,
          );
        }

        return;
      },
      intermediateContextChecks: [
        (context) => OverlayNotificationHelper.hideNotification(),
      ],
      onSuccess: (_) async {
        if (!mounted) return;
        
        // Create and save the sync device
        await _createSyncDevice(device);
      },
    );
  }

  Future<void> _createSyncDevice(DiscoveredDevice device) async {
    final mediator = container.resolve<Mediator>();
    final deviceIdService = container.resolve<IDeviceIdService>();
    
    await AsyncErrorHandler.executeChain<void>(
      context: context,
      errorMessage: _translationService.translate(SyncTranslationKeys.saveDeviceError),
      operation: () async {
        // Get local device information
        final localIp = await NetworkUtils.getLocalIpAddress();
        if (localIp == null) {
          throw BusinessException(
            _translationService.translate(SyncTranslationKeys.localIpError),
            SyncTranslationKeys.ipAddressError,
          );
        }

        final localDeviceId = await deviceIdService.getDeviceId();
        final localDeviceName = await DeviceInfoHelper.getDeviceName();
        
        // Check if device already exists
        final existingDevice = await mediator.send<GetSyncDeviceQuery, GetSyncDeviceQueryResponse?>(
          GetSyncDeviceQuery(fromDeviceId: device.deviceId, toDeviceId: localDeviceId)
        );

        if (existingDevice?.id.isNotEmpty == true && existingDevice?.deletedDate == null) {
          throw BusinessException(
            _translationService.translate(SyncTranslationKeys.deviceAlreadyPairedError),
            SyncTranslationKeys.deviceAlreadyPaired,
          );
        }

        // Create the sync device
        // Remote device acts as server, local device as client
        final saveCommand = SaveSyncDeviceCommand(
          fromIP: device.ipAddress, // Remote device IP (server)
          toIP: localIp,           // Local device IP (client)
          fromDeviceId: device.deviceId,
          toDeviceId: localDeviceId,
          name: "${device.name} ↔ $localDeviceName",
        );

        await mediator.send<SaveSyncDeviceCommand, SaveSyncDeviceCommandResponse>(saveCommand);
        
        return;
      },
      onSuccess: (_) async {
        if (!mounted) return;

        // Show sync progress
        OverlayNotificationHelper.showLoading(
          context: context,
          message: _translationService.translate(SyncTranslationKeys.syncInProgress),
          duration: const Duration(seconds: 30),
        );

        // Start sync
        await _startSync();
      },
    );
  }

  Future<void> _startSync() async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(SyncTranslationKeys.syncError),
      operation: () async {
        final syncService = container.resolve<ISyncService>();
        final completer = Completer<void>();

        final subscription = syncService.onSyncComplete.listen((completed) {
          if (completed && !completer.isCompleted) {
            completer.complete();
          }
        });

        // Mark as manual sync so UI updates properly
        await syncService.runSync(isManual: true);

        await completer.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            subscription.cancel();
            throw BusinessException(
              _translationService.translate(SyncTranslationKeys.syncTimeoutError),
              SyncTranslationKeys.syncTimeoutError,
            );
          },
        );

        subscription.cancel();
      },
    );

    // Handle success after executeVoid completes
    if (!mounted) return;
    
    OverlayNotificationHelper.hideNotification();
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;
    OverlayNotificationHelper.showSuccess(
      context: context,
      message: _translationService.translate(SyncTranslationKeys.syncCompleted),
      duration: const Duration(seconds: 3),
    );

    // Notify parent and close the page
    widget.onDeviceAdded?.call();
    
    // Pop once to close the dialog
    Navigator.pop(context, true);
  }

  Future<void> _openQRScanner() async {
    HapticFeedback.selectionClick();
    
    final result = await Navigator.pushNamed(
      context,
      QRCodeScannerPage.route,
    );

    if (result != null && mounted) {
      widget.onDeviceAdded?.call();
      Navigator.pop(context, true);
    }
  }

  Future<void> _openManualConnection() async {
    HapticFeedback.selectionClick();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ManualIPInputDialog(
        onSyncDeviceAdded: () {
          widget.onDeviceAdded?.call();
        },
        connectionService: _connectionService,
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  /// Gets the appropriate icon for a platform
  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Icons.android;
      case 'ios':
        return Icons.phone_iphone;
      case 'linux':
        return Icons.computer;
      case 'windows':
        return Icons.desktop_windows;
      case 'macos':
        return Icons.laptop_mac;
      default:
        return Icons.device_unknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        title: Text(_translationService.translate(SyncTranslationKeys.addSyncDevice)),
        actions: [
          // QR Code Scanner Button
          IconButton(
            onPressed: _openQRScanner,
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: _translationService.translate(SyncTranslationKeys.scanQRCode),
          ),
          // Manual Connection Button
          IconButton(
            onPressed: _openManualConnection,
            icon: const Icon(Icons.add_link),
            tooltip: _translationService.translate(SyncTranslationKeys.manualConnection),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.sizeLarge),
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
          ),

          // Scanning Status
          if (_isScanning)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.sizeLarge,
                vertical: AppTheme.sizeMedium,
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppTheme.sizeMedium),
                  Text(
                    _translationService.translate(SyncTranslationKeys.scanningForDevices),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

          // Error Message
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppTheme.sizeLarge),
              padding: const EdgeInsets.all(AppTheme.sizeMedium),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
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
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Device List or Empty State
          Expanded(
            child: _discoveredDevices.isEmpty && !_isScanning
                ? _buildEmptyStateWithFooter()
                : _buildDeviceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.devices_other,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              onPressed: _startDeviceDiscovery,
              icon: const Icon(Icons.refresh),
              label: Text(_translationService.translate(SyncTranslationKeys.refreshScan)),
            ),
          ],
        ),
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
        _buildAlternativeMethodsFooter(),
      ],
    );
  }

  Widget _buildDeviceList() {
    return Column(
      children: [
        // Device List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeLarge),
            itemCount: _discoveredDevices.length + (!_isScanning ? 1 : 0), // Add 1 for refresh button when not scanning
            itemBuilder: (context, index) {
              // If this is the last item and scanning is finished, show refresh button
              if (index == _discoveredDevices.length && !_isScanning) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.sizeMedium),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: _startDeviceDiscovery,
                      icon: const Icon(Icons.refresh),
                      label: Text(_translationService.translate(SyncTranslationKeys.refreshScan)),
                    ),
                  ),
                );
              }
        final device = _discoveredDevices[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.sizeMedium),
            child: Row(
              children: [
                // Leading icon - centered
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.devices),
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
                          fontWeight: FontWeight.w500,
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
                            _getPlatformIcon(device.platform),
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _translationService.translate(
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
                device.isAlreadyAdded
                    ? Container(
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
                              _translationService.translate(SyncTranslationKeys.alreadyAdded),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ElevatedButton(
                        onPressed: () => _connectToDevice(device),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.sizeMedium,
                            vertical: AppTheme.sizeSmall,
                          ),
                        ),
                        child: Text(_translationService.translate(SyncTranslationKeys.connect)),
                      ),
              ],
            ),
          ),
        );
            },
          ),
        ),
        
        // Alternative Methods Footer - only show when scanning is finished
        if (!_isScanning) _buildAlternativeMethodsFooter(),
      ],
    );
  }

  Widget _buildAlternativeMethodsFooter() {
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
                  _translationService.translate(SyncTranslationKeys.alternativeMethodsHint),
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
              OutlinedButton.icon(
                onPressed: _openQRScanner,
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: Text(_translationService.translate(SyncTranslationKeys.scanQRCode)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.sizeSmall,
                    vertical: AppTheme.sizeSmall,
                  ),
                  textStyle: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: AppTheme.sizeSmall),
              OutlinedButton.icon(
                onPressed: _openManualConnection,
                icon: const Icon(Icons.add_link, size: 18),
                label: Text(_translationService.translate(SyncTranslationKeys.manualConnection)),
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

/// Represents a discovered device on the network
class DiscoveredDevice {
  final String name;
  final String ipAddress;
  final int port;
  final DateTime lastSeen;
  final String deviceId;
  final String platform;
  final bool isAlreadyAdded;

  const DiscoveredDevice({
    required this.name,
    required this.ipAddress,
    required this.port,
    required this.lastSeen,
    required this.deviceId,
    required this.platform,
    this.isAlreadyAdded = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredDevice &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId;

  @override
  int get hashCode => deviceId.hashCode;
}