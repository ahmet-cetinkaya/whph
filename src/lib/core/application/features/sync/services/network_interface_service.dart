import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:whph/corePackages/acore/lib/acore.dart' show PlatformUtils;
import 'package:whph/core/application/features/sync/services/abstraction/i_network_interface_service.dart';
import 'package:whph/core/shared/utils/logger.dart';

/// Cross-platform network interface discovery service
/// Provides comprehensive network interface detection for multi-interface sync
class NetworkInterfaceService implements INetworkInterfaceService {
  static const List<String> _wifiInterfaceNames = [
    'wlan', 'wi-fi', 'wifi', 'wireless', 'wlp', 'wlx'
  ];
  
  static const List<String> _ethernetInterfaceNames = [
    'eth', 'ethernet', 'ens', 'enp', 'eno', 'lan', 'local area connection'
  ];

  @override
  Future<List<String>> getLocalIPAddresses() async {
    try {
      final interfaces = await getActiveNetworkInterfaces();
      return interfaces.map((interface) => interface.ipAddress).toList();
    } catch (e) {
      Logger.error('Failed to get local IP addresses: $e');
      return [];
    }
  }

  @override
  Future<List<NetworkInterfaceInfo>> getActiveNetworkInterfaces() async {
    final List<NetworkInterfaceInfo> networkInterfaces = [];

    try {
      if (PlatformUtils.isMobile) {
        // For mobile, use network_info_plus to get WiFi info
        await _addMobileNetworkInterfaces(networkInterfaces);
      }
      
      // For all platforms, also use NetworkInterface for comprehensive detection
      await _addDesktopNetworkInterfaces(networkInterfaces);

      // Remove duplicates and sort by priority
      final uniqueInterfaces = _removeDuplicateInterfaces(networkInterfaces);
      uniqueInterfaces.sort((a, b) => b.priority.compareTo(a.priority));

      Logger.debug('Found ${uniqueInterfaces.length} network interfaces: ${uniqueInterfaces.map((i) => '${i.name}(${i.ipAddress})').join(', ')}');
      return uniqueInterfaces;
    } catch (e) {
      Logger.error('Failed to get active network interfaces: $e');
      return [];
    }
  }

  @override
  bool isValidLocalIPAddress(String ipAddress) {
    final parts = ipAddress.split('.');
    if (parts.length != 4) return false;

    try {
      // Check each part is a valid integer 0-255
      for (final part in parts) {
        final num = int.parse(part);
        if (num < 0 || num > 255) return false;
      }

      // 192.168.x.x (Class C private)
      if (parts[0] == '192' && parts[1] == '168') return true;

      // 10.x.x.x (Class A private)
      if (parts[0] == '10') return true;

      // 172.16-31.x.x (Class B private)
      if (parts[0] == '172') {
        final second = int.parse(parts[1]);
        if (second >= 16 && second <= 31) return true;
      }

      // 169.254.x.x (Link-local/APIPA) - Include for local discovery
      if (parts[0] == '169' && parts[1] == '254') return true;

      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<String>> getPreferredIPAddresses() async {
    final interfaces = await getActiveNetworkInterfaces();
    return interfaces.map((interface) => interface.ipAddress).toList();
  }

  /// Add mobile network interfaces using network_info_plus
  Future<void> _addMobileNetworkInterfaces(List<NetworkInterfaceInfo> interfaces) async {
    try {
      final info = NetworkInfo();
      
      // Get WiFi IP
      final wifiIP = await info.getWifiIP();
      if (wifiIP != null && isValidLocalIPAddress(wifiIP)) {
        interfaces.add(NetworkInterfaceInfo(
          name: 'WiFi',
          ipAddress: wifiIP,
          addressType: InternetAddressType.IPv4,
          isWiFi: true,
          isEthernet: false,
          priority: 100, // High priority for WiFi
        ));
        Logger.debug('Mobile WiFi interface found: $wifiIP');
      }

      // Try to get other network info if available
      final wifiName = await info.getWifiName();
      if (wifiName != null) {
        Logger.debug('Connected to WiFi network: $wifiName');
      }
    } catch (e) {
      Logger.debug('Mobile network info not available: $e');
    }
  }

  /// Add network interfaces using dart:io NetworkInterface
  Future<void> _addDesktopNetworkInterfaces(List<NetworkInterfaceInfo> interfaces) async {
    try {
      final networkInterfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );

      for (final networkInterface in networkInterfaces) {
        for (final addr in networkInterface.addresses) {
          if (isValidLocalIPAddress(addr.address)) {
            final interfaceInfo = _analyzeNetworkInterface(networkInterface.name, addr.address);
            interfaces.add(interfaceInfo);
          }
        }
      }
    } catch (e) {
      Logger.debug('Desktop network interface detection failed: $e');
    }
  }

  /// Analyze network interface to determine type and priority
  NetworkInterfaceInfo _analyzeNetworkInterface(String name, String ipAddress) {
    final lowerName = name.toLowerCase();
    
    bool isWiFi = _wifiInterfaceNames.any((wifiName) => lowerName.contains(wifiName));
    bool isEthernet = _ethernetInterfaceNames.any((ethName) => lowerName.contains(ethName));
    
    // Determine priority based on interface type
    int priority = 50; // Default priority
    if (isWiFi) {
      priority = 90; // High priority for WiFi
    } else if (isEthernet) {
      priority = 95; // Highest priority for Ethernet (usually faster/more reliable)
    }

    // Boost priority for common local network ranges
    if (ipAddress.startsWith('192.168.')) {
      priority += 10;
    } else if (ipAddress.startsWith('10.')) {
      priority += 5;
    }

    return NetworkInterfaceInfo(
      name: name,
      ipAddress: ipAddress,
      addressType: InternetAddressType.IPv4,
      isWiFi: isWiFi,
      isEthernet: isEthernet,
      priority: priority,
    );
  }

  /// Remove duplicate interfaces based on IP address
  List<NetworkInterfaceInfo> _removeDuplicateInterfaces(List<NetworkInterfaceInfo> interfaces) {
    final Map<String, NetworkInterfaceInfo> uniqueMap = {};
    
    for (final interface in interfaces) {
      final existing = uniqueMap[interface.ipAddress];
      if (existing == null || interface.priority > existing.priority) {
        uniqueMap[interface.ipAddress] = interface;
      }
    }
    
    return uniqueMap.values.toList();
  }
}