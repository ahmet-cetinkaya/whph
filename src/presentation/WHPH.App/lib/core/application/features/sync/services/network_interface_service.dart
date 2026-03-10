import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:meta/meta.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:acore/acore.dart' show PlatformUtils;
import 'package:whph/core/application/features/sync/services/abstraction/i_network_interface_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

/// Cross-platform network interface discovery service
/// Provides comprehensive network interface detection for multi-interface sync
class NetworkInterfaceService implements INetworkInterfaceService {
  static const List<String> _wifiInterfaceNames = ['wlan', 'wi-fi', 'wifi', 'wireless', 'wlp', 'wlx'];

  static const List<String> _ethernetInterfaceNames = [
    'eth',
    'ethernet',
    'ens',
    'enp',
    'eno',
    'lan',
    'local area connection'
  ];

  static const List<String> _virtualInterfaceNameKeywords = [
    'vethernet',
    'hyper-v',
    'virtualbox',
    'vmware',
    'docker',
    'wsl',
    'tap',
    'tun',
    'host-only',
    'loopback',
  ];

  static const String _activeInterfacesErrorId = 'sync_network_interfaces_discovery_failed';
  static const String _desktopInterfacesErrorId = 'sync_desktop_interfaces_discovery_failed';
  static const String _windowsMetadataErrorId = 'sync_windows_interface_metadata_query_failed';
  static const String _windowsMetadataParseErrorId = 'sync_windows_interface_metadata_parse_failed';

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
      // Safely check if platform is mobile - handle null case in test environment
      try {
        if (PlatformUtils.isMobile) {
          // For mobile, use network_info_plus to get WiFi info
          await _addMobileNetworkInterfaces(networkInterfaces);
        }
      } catch (e) {
        Logger.debug('PlatformUtils not available (likely test environment): $e');
      }

      final windowsMetadata = await _getWindowsInterfaceMetadata();

      // For all platforms, also use NetworkInterface for comprehensive detection
      await _addDesktopNetworkInterfaces(networkInterfaces, windowsMetadata: windowsMetadata);

      // Remove duplicates and sort by priority
      final uniqueInterfaces = _removeDuplicateInterfaces(networkInterfaces);
      final sortedInterfaces = sortInterfacesForPreference(uniqueInterfaces);

      Logger.debug(
          'Found ${sortedInterfaces.length} network interfaces: ${sortedInterfaces.map((i) => '${i.name}(${i.ipAddress})').join(', ')}');
      return sortedInterfaces;
    } catch (e, st) {
      Logger.error('[$_activeInterfacesErrorId] Failed to get active network interfaces: $e\n$st');
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
  Future<void> _addDesktopNetworkInterfaces(
    List<NetworkInterfaceInfo> interfaces, {
    Map<String, _WindowsInterfaceMetadata>? windowsMetadata,
  }) async {
    try {
      final networkInterfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );

      for (final networkInterface in networkInterfaces) {
        for (final addr in networkInterface.addresses) {
          if (isValidLocalIPAddress(addr.address)) {
            final metadata = _resolveWindowsMetadata(windowsMetadata, networkInterface.name, addr.address);
            final interfaceInfo = _analyzeNetworkInterface(networkInterface.name, addr.address, metadata: metadata);
            interfaces.add(interfaceInfo);
          }
        }
      }
    } catch (e, st) {
      Logger.error('[$_desktopInterfacesErrorId] Desktop network interface detection failed: $e\n$st');
    }
  }

  /// Analyze network interface to determine type and priority
  NetworkInterfaceInfo _analyzeNetworkInterface(
    String name,
    String ipAddress, {
    _WindowsInterfaceMetadata? metadata,
  }) {
    final lowerName = name.toLowerCase();

    final isWiFi = _wifiInterfaceNames.any((wifiName) => lowerName.contains(wifiName));
    final isEthernet = _ethernetInterfaceNames.any((ethName) => lowerName.contains(ethName));
    final hasDefaultGateway = metadata?.hasDefaultGateway ?? false;
    final interfaceMetric = metadata?.interfaceMetric;
    final isVirtual = metadata?.isVirtual ?? _isVirtualInterfaceByName(lowerName);

    final priority = _calculatePriority(
      isWiFi: isWiFi,
      isEthernet: isEthernet,
      hasDefaultGateway: hasDefaultGateway,
      interfaceMetric: interfaceMetric,
      isVirtual: isVirtual,
      ipAddress: ipAddress,
    );

    return NetworkInterfaceInfo(
      name: name,
      ipAddress: ipAddress,
      addressType: InternetAddressType.IPv4,
      isWiFi: isWiFi,
      isEthernet: isEthernet,
      priority: priority,
      hasDefaultGateway: hasDefaultGateway,
      interfaceMetric: interfaceMetric,
      isVirtual: isVirtual,
      gatewayIp: metadata?.gatewayIp,
    );
  }

  int _calculatePriority({
    required bool isWiFi,
    required bool isEthernet,
    required bool hasDefaultGateway,
    required int? interfaceMetric,
    required bool isVirtual,
    required String ipAddress,
  }) {
    var priority = 0;

    if (hasDefaultGateway) {
      priority += 100;
    }

    if (interfaceMetric != null) {
      final boundedMetric = interfaceMetric.clamp(1, 50);
      priority += 51 - boundedMetric;
    }

    if (isEthernet) {
      priority += 20;
    } else if (isWiFi) {
      priority += 15;
    }

    if (ipAddress.startsWith('192.168.')) {
      priority += 10;
    } else if (ipAddress.startsWith('10.')) {
      priority += 5;
    }

    if (isVirtual && !hasDefaultGateway) {
      priority -= 120;
    }

    return priority;
  }

  @visibleForTesting
  int calculatePriorityForTest({
    required bool isWiFi,
    required bool isEthernet,
    required bool hasDefaultGateway,
    required int? interfaceMetric,
    required bool isVirtual,
    required String ipAddress,
  }) {
    return _calculatePriority(
      isWiFi: isWiFi,
      isEthernet: isEthernet,
      hasDefaultGateway: hasDefaultGateway,
      interfaceMetric: interfaceMetric,
      isVirtual: isVirtual,
      ipAddress: ipAddress,
    );
  }

  bool _isVirtualInterfaceByName(String lowerName) {
    return _virtualInterfaceNameKeywords.any(lowerName.contains);
  }

  @visibleForTesting
  bool isVirtualInterfaceByNameForTest(String interfaceName) {
    return _isVirtualInterfaceByName(interfaceName.toLowerCase());
  }

  _WindowsInterfaceMetadata? _resolveWindowsMetadata(
    Map<String, _WindowsInterfaceMetadata>? metadataMap,
    String interfaceName,
    String ipAddress,
  ) {
    if (metadataMap == null || metadataMap.isEmpty) return null;

    final keyWithIp = _windowsMetadataKey(interfaceName, ipAddress);
    final exact = metadataMap[keyWithIp];
    if (exact != null) return exact;

    return metadataMap[_windowsMetadataKey(interfaceName, null)];
  }

  @visibleForTesting
  Map<String, dynamic>? resolveWindowsMetadataForTest(
    Map<String, Map<String, dynamic>> metadataMap,
    String interfaceName,
    String ipAddress,
  ) {
    final internalMap = <String, _WindowsInterfaceMetadata>{};
    for (final entry in metadataMap.entries) {
      internalMap[entry.key] = _WindowsInterfaceMetadata(
        hasDefaultGateway: entry.value['hasDefaultGateway'] as bool? ?? false,
        interfaceMetric: entry.value['interfaceMetric'] as int?,
        isVirtual: entry.value['isVirtual'] as bool? ?? false,
        gatewayIp: entry.value['gatewayIp'] as String?,
      );
    }

    final resolved = _resolveWindowsMetadata(internalMap, interfaceName, ipAddress);
    if (resolved == null) return null;

    return {
      'hasDefaultGateway': resolved.hasDefaultGateway,
      'interfaceMetric': resolved.interfaceMetric,
      'isVirtual': resolved.isVirtual,
      'gatewayIp': resolved.gatewayIp,
    };
  }

  String _windowsMetadataKey(String interfaceName, String? ipAddress) {
    final normalizedName = interfaceName.trim().toLowerCase();
    return '$normalizedName|${ipAddress ?? ''}';
  }

  Future<Map<String, _WindowsInterfaceMetadata>?> _getWindowsInterfaceMetadata() async {
    if (!Platform.isWindows) return null;

    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          r'''$cfg = Get-NetIPConfiguration | Select-Object InterfaceAlias,IPv4Address,IPv4DefaultGateway;
$metric = Get-NetIPInterface -AddressFamily IPv4 | Select-Object InterfaceAlias,InterfaceMetric;
[PSCustomObject]@{ Config=$cfg; Metrics=$metric } | ConvertTo-Json -Depth 5 -Compress''',
        ],
      ).timeout(const Duration(seconds: 10));

      if (result.exitCode != 0) {
        Logger.error(
            '[$_windowsMetadataErrorId] PowerShell metadata query failed with exit code ${result.exitCode}: ${result.stderr}');
        return null;
      }

      final output = (result.stdout as String).trim();
      if (output.isEmpty) {
        Logger.error('[$_windowsMetadataErrorId] PowerShell metadata query returned empty output');
        return null;
      }

      return _parseWindowsInterfaceMetadata(output);
    } on TimeoutException catch (e) {
      Logger.error('[$_windowsMetadataErrorId] Windows interface metadata query timed out: $e');
      return null;
    } catch (e, st) {
      Logger.error('[$_windowsMetadataErrorId] Windows interface metadata query failed: $e\n$st');
      return null;
    }
  }

  @visibleForTesting
  Map<String, Map<String, dynamic>> parseWindowsInterfaceMetadataForTest(String jsonOutput) {
    final parsed = _parseWindowsInterfaceMetadata(jsonOutput);
    return parsed.map(
      (key, value) => MapEntry(
        key,
        {
          'hasDefaultGateway': value.hasDefaultGateway,
          'interfaceMetric': value.interfaceMetric,
          'isVirtual': value.isVirtual,
          'gatewayIp': value.gatewayIp,
        },
      ),
    );
  }

  Map<String, _WindowsInterfaceMetadata> _parseWindowsInterfaceMetadata(String jsonOutput) {
    dynamic parsed;
    try {
      parsed = jsonDecode(jsonOutput);
    } catch (e, st) {
      Logger.error('[$_windowsMetadataParseErrorId] Failed to parse Windows interface metadata JSON: $e\n$st');
      return {};
    }

    if (parsed is! Map<String, dynamic>) {
      Logger.error('[$_windowsMetadataParseErrorId] Parsed metadata payload is not a JSON object');
      return {};
    }

    final configList = _toObjectList(parsed['Config']);
    final metricsList = _toObjectList(parsed['Metrics']);

    if (configList.isEmpty && metricsList.isEmpty) {
      Logger.error('[$_windowsMetadataParseErrorId] Windows metadata payload contains no config or metric entries');
    }

    final metricsByAlias = <String, int>{};

    for (final row in metricsList) {
      final alias = (row['InterfaceAlias']?.toString() ?? '').trim().toLowerCase();
      if (alias.isEmpty) continue;

      final metric = int.tryParse(row['InterfaceMetric']?.toString() ?? '');
      if (metric == null) continue;

      final existing = metricsByAlias[alias];
      if (existing == null || metric < existing) {
        metricsByAlias[alias] = metric;
      }
    }

    final metadataByKey = <String, _WindowsInterfaceMetadata>{};

    for (final row in configList) {
      final aliasRaw = row['InterfaceAlias']?.toString() ?? '';
      final alias = aliasRaw.trim().toLowerCase();
      if (alias.isEmpty) continue;

      final ipv4Address = _extractAddressString(row['IPv4Address']);
      final gatewayIp = _extractAddressString(row['IPv4DefaultGateway']);
      final hasDefaultGateway = gatewayIp != null && gatewayIp.isNotEmpty;
      final interfaceMetric = metricsByAlias[alias];
      final isVirtual = _isVirtualInterfaceByName(alias);

      final metadata = _WindowsInterfaceMetadata(
        hasDefaultGateway: hasDefaultGateway,
        interfaceMetric: interfaceMetric,
        isVirtual: isVirtual,
        gatewayIp: gatewayIp,
      );

      metadataByKey[_windowsMetadataKey(aliasRaw, null)] = metadata;
      if (ipv4Address != null && ipv4Address.isNotEmpty) {
        metadataByKey[_windowsMetadataKey(aliasRaw, ipv4Address)] = metadata;
      }
    }

    return metadataByKey;
  }

  List<Map<String, dynamic>> _toObjectList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    }

    if (value is Map) {
      return [Map<String, dynamic>.from(value)];
    }

    return [];
  }

  String? _extractAddressString(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      final normalized = value.trim();
      return normalized.isEmpty ? null : normalized;
    }

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      return _extractAddressString(map['IPAddress'] ?? map['IpAddress'] ?? map['Address'] ?? map['NextHop']);
    }

    if (value is List && value.isNotEmpty) {
      return _extractAddressString(value.first);
    }

    return null;
  }

  @visibleForTesting
  List<NetworkInterfaceInfo> sortInterfacesForPreference(List<NetworkInterfaceInfo> interfaces) {
    final sorted = [...interfaces];
    sorted.sort((a, b) => b.priority.compareTo(a.priority));
    return sorted;
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

class _WindowsInterfaceMetadata {
  final bool hasDefaultGateway;
  final int? interfaceMetric;
  final bool isVirtual;
  final String? gatewayIp;

  const _WindowsInterfaceMetadata({
    required this.hasDefaultGateway,
    required this.interfaceMetric,
    required this.isVirtual,
    required this.gatewayIp,
  });
}
