import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_network_interface_service.dart';
import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/queries/get_list_sync_members_query.dart';
import 'package:whph/core/application/features/sync/services/device_handshake_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/features/sync/pages/add_sync_device_page/models/discovered_device.dart';
import 'package:whph/presentation/ui/features/sync/services/sync_pairing_flow.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Controller for managing device discovery and connection logic
class AddSyncDeviceController extends ChangeNotifier {
  final _networkInterfaceService = container.resolve<INetworkInterfaceService>();
  final _handshakeService = container.resolve<DeviceHandshakeService>();
  final _translationService = container.resolve<ITranslationService>();

  bool _isScanning = false;
  final List<DiscoveredDevice> _discoveredDevices = [];
  Timer? _scanTimer;
  String? _errorMessage;
  String? _scanProgress;

  bool get isScanning => _isScanning;
  List<DiscoveredDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);
  String? get errorMessage => _errorMessage;
  String? get scanProgress => _scanProgress;

  /// Starts device discovery on the local network
  Future<void> startDeviceDiscovery() async {
    _isScanning = true;
    _errorMessage = null;
    _scanProgress = null;
    _discoveredDevices.clear();
    notifyListeners();

    try {
      // Get local network interfaces
      final interfaces = await _networkInterfaceService.getActiveNetworkInterfaces();
      if (interfaces.isEmpty) {
        _errorMessage = _translationService.translate(SyncTranslationKeys.noActiveInterfacesError);
        _isScanning = false;
        notifyListeners();
        return;
      }

      // Scan network ranges with timeout
      await _scanNetworkRanges(interfaces).timeout(
        const Duration(seconds: 15), // Aggressive timeout for 10-second target
        onTimeout: () {
          _isScanning = false;
          _scanProgress = null;
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = _translationService
          .translate(SyncTranslationKeys.deviceDiscoveryFailedError, namedArgs: {'error': e.toString()});
      _isScanning = false;
      _scanProgress = null;
      notifyListeners();
    }
  }

  Future<void> _scanNetworkRanges(List<NetworkInterfaceInfo> interfaces) async {
    final Set<String> scannedAddresses = {};
    final startTime = DateTime.now();

    for (final interface in interfaces) {
      if (!interface.isWiFi && !interface.isEthernet) continue;

      final networkBase = _getNetworkBase(interface.ipAddress);
      if (networkBase == null) continue;

      // Speed-optimized scanning targeting only most likely device IPs for 10-second completion
      final commonRanges = [
        for (int i = 1; i <= 30; i++) i, // Very common router/device range
        for (int i = 100; i <= 130; i++) i, // Most common DHCP range
        for (int i = 31; i <= 60; i++) i, // Extended common range
        for (int i = 131; i <= 160; i++) i, // Extended DHCP range
        for (int i = 200; i <= 230; i++) i, // High-end common range
        // Skip less common ranges for speed - only scan ~150 IPs instead of 254
      ];

      // Process IPs in small batches with delays for better UI responsiveness
      final ipAddresses = <String>[];
      for (final i in commonRanges) {
        final targetIP = '$networkBase.$i';
        if (targetIP != interface.ipAddress && !scannedAddresses.contains(targetIP)) {
          scannedAddresses.add(targetIP);
          ipAddresses.add(targetIP);
        }
      }

      // Process in very large batches of 20 IPs at a time for maximum speed
      for (int batchStart = 0; batchStart < ipAddresses.length; batchStart += 20) {
        final batchEnd = (batchStart + 20).clamp(0, ipAddresses.length);
        final batchIps = ipAddresses.sublist(batchStart, batchEnd);

        // Update progress indicator
        final progress = ((batchStart / ipAddresses.length) * 100).round();
        _scanProgress = 'Scanning devices... $progress% (${batchStart + batchIps.length}/${ipAddresses.length})';
        notifyListeners();

        // Create futures for this small batch
        final batchFutures = batchIps.map((ip) => _checkDeviceAt(ip)).toList();

        // Wait for this small batch to complete
        await Future.wait(batchFutures);

        // Minimal delay for maximum speed - only yield to UI thread
        await Future.delayed(Duration.zero);

        // Early exit conditions for better UX
        final elapsedTime = DateTime.now().difference(startTime);

        // Stop if timeout is reached for speed target
        if (elapsedTime.inSeconds > 12) {
          // Match parent timeout with small buffer
          break;
        }
      }
    }

    // Scanning completed - update UI state
    _isScanning = false;
    _scanProgress = null;
    notifyListeners();
  }

  String? _getNetworkBase(String ipAddress) {
    final parts = ipAddress.split('.');
    if (parts.length != 4) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  Future<void> _checkDeviceAt(String ipAddress) async {
    try {
      // Perform handshake to get device information with very aggressive timeout for speed
      final deviceInfo = await _handshakeService
          .getDeviceInfo(ipAddress, 44040)
          .timeout(const Duration(milliseconds: 800)); // Very aggressive timeout per device

      if (deviceInfo != null) {
        // Check if device is already paired
        final isAlreadyAdded = await _checkIfDeviceAlreadyAdded(deviceInfo.memberId);

        final device = DiscoveredDevice(
          name: deviceInfo.deviceName,
          ipAddress: deviceInfo.ipAddress,
          port: deviceInfo.port,
          lastSeen: deviceInfo.discoveredAt,
          deviceId: deviceInfo.deviceId,
          platform: deviceInfo.platform,
          isAlreadyAdded: isAlreadyAdded,
        );

        // Check if device is already in the list
        final existingIndex = _discoveredDevices.indexWhere(
          (d) => d.deviceId == device.deviceId || (d.ipAddress == device.ipAddress && d.port == device.port),
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
        notifyListeners();

        // Yield to UI thread after notifyListeners to prevent blocking
        await Future.delayed(Duration.zero);

        // Provide haptic feedback on device discovery
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      // Log connection failures during discovery for debugging purposes
      Logger.debug('Device check failed for $ipAddress: $e');
    }
  }

  /// A device counts as added when its sync member id is in the group.
  Future<bool> _checkIfDeviceAlreadyAdded(String? memberId) async {
    if (memberId == null) return false;
    try {
      final response = await container.resolve<Mediator>().send<GetListSyncMembersQuery, GetListSyncMembersQueryResponse>(
            GetListSyncMembersQuery(),
          );
      return response.members.any((member) => !member.isLegacy && member.memberId == memberId);
    } catch (e) {
      return false; // If we can't check, assume it's not added
    }
  }

  /// Pairs with a discovered or manually entered device: both users compare a
  /// code (and confirm a group switch when needed) before anything is shared.
  Future<SyncPairingStatus> connectToDevice(DiscoveredDevice device, BuildContext context) async {
    HapticFeedback.selectionClick();
    return SyncPairingFlow(container.resolve<Mediator>()).pairWithAddress(context, device.ipAddress, port: device.port);
  }

  /// Gets the appropriate icon for a platform
  IconData getPlatformIcon(String platform) {
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
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }
}
