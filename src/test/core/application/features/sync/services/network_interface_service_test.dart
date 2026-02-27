import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_network_interface_service.dart';
import 'package:whph/core/application/features/sync/services/network_interface_service.dart';

void main() {
  group('NetworkInterfaceService', () {
    late NetworkInterfaceService service;

    setUp(() {
      service = NetworkInterfaceService();
    });

    group('isValidLocalIPAddress', () {
      test('should return true for valid 192.168.x.x addresses', () {
        expect(service.isValidLocalIPAddress('192.168.1.1'), true);
        expect(service.isValidLocalIPAddress('192.168.0.100'), true);
        expect(service.isValidLocalIPAddress('192.168.255.255'), true);
      });

      test('should return true for valid 10.x.x.x addresses', () {
        expect(service.isValidLocalIPAddress('10.0.0.1'), true);
        expect(service.isValidLocalIPAddress('10.255.255.254'), true);
      });

      test('should return true for valid 172.16-31.x.x addresses', () {
        expect(service.isValidLocalIPAddress('172.16.0.1'), true);
        expect(service.isValidLocalIPAddress('172.31.255.254'), true);
      });

      test('should return true for link-local 169.254.x.x addresses', () {
        expect(service.isValidLocalIPAddress('169.254.1.1'), true);
        expect(service.isValidLocalIPAddress('169.254.255.254'), true);
      });

      test('should return false for public IP addresses', () {
        expect(service.isValidLocalIPAddress('8.8.8.8'), false);
        expect(service.isValidLocalIPAddress('1.1.1.1'), false);
        expect(service.isValidLocalIPAddress('172.15.0.1'), false);
        expect(service.isValidLocalIPAddress('172.32.0.1'), false);
      });

      test('should return false for invalid IP formats', () {
        expect(service.isValidLocalIPAddress('192.168.1'), false);
        expect(service.isValidLocalIPAddress('192.168.1.1.1'), false);
        expect(service.isValidLocalIPAddress('256.1.1.1'), false);
        expect(service.isValidLocalIPAddress('192.168.-1.1'), false);
        expect(service.isValidLocalIPAddress('invalid'), false);
        expect(service.isValidLocalIPAddress(''), false);
      });
    });

    group('getLocalIPAddresses', () {
      test('should return a list of IP addresses', () async {
        final addresses = await service.getLocalIPAddresses();

        // Should return at least empty list (may have actual addresses in test environment)
        expect(addresses, isA<List<String>>());

        // If any addresses are returned, they should be valid local network IPs
        for (final address in addresses) {
          expect(service.isValidLocalIPAddress(address), true,
              reason: 'Address $address should be a valid local network IP');
        }
      });
    });

    group('getActiveNetworkInterfaces', () {
      test('should return network interface information', () async {
        final interfaces = await service.getActiveNetworkInterfaces();

        expect(interfaces, isA<List<dynamic>>());

        // If any interfaces are returned, they should have valid structure
        for (final interface in interfaces) {
          expect(interface.name, isNotEmpty);
          expect(interface.ipAddress, isNotEmpty);
          expect(service.isValidLocalIPAddress(interface.ipAddress), true);
          expect(interface.priority, isA<int>());
        }
      });
    });

    group('getPreferredIPAddresses', () {
      test('should return addresses in priority order', () async {
        final addresses = await service.getPreferredIPAddresses();

        expect(addresses, isA<List<String>>());

        // Addresses should be valid local network IPs
        for (final address in addresses) {
          expect(service.isValidLocalIPAddress(address), true);
        }
      });
    });

    group('sortInterfacesForPreference', () {
      test('should prefer gateway-backed physical interfaces over virtual adapters', () {
        final interfaces = [
          const NetworkInterfaceInfo(
            name: 'vEthernet (Default Switch)',
            ipAddress: '172.31.160.1',
            addressType: InternetAddressType.IPv4,
            isWiFi: false,
            isEthernet: true,
            priority: -40,
            hasDefaultGateway: false,
            interfaceMetric: 5000,
            isVirtual: true,
          ),
          const NetworkInterfaceInfo(
            name: 'Wi-Fi',
            ipAddress: '192.168.178.30',
            addressType: InternetAddressType.IPv4,
            isWiFi: true,
            isEthernet: false,
            priority: 160,
            hasDefaultGateway: true,
            interfaceMetric: 10,
            isVirtual: false,
          ),
        ];

        final sorted = service.sortInterfacesForPreference(interfaces);

        expect(sorted.first.name, 'Wi-Fi');
        expect(sorted.first.ipAddress, '192.168.178.30');
      });

      test('should preserve high priority for 172.x addresses when gateway-backed', () {
        final interfaces = [
          const NetworkInterfaceInfo(
            name: 'Corporate VPN',
            ipAddress: '172.20.10.5',
            addressType: InternetAddressType.IPv4,
            isWiFi: false,
            isEthernet: false,
            priority: 140,
            hasDefaultGateway: true,
            interfaceMetric: 5,
            isVirtual: false,
          ),
          const NetworkInterfaceInfo(
            name: 'Ethernet',
            ipAddress: '192.168.1.20',
            addressType: InternetAddressType.IPv4,
            isWiFi: false,
            isEthernet: true,
            priority: 40,
            hasDefaultGateway: false,
            interfaceMetric: 25,
            isVirtual: false,
          ),
        ];

        final sorted = service.sortInterfacesForPreference(interfaces);

        expect(sorted.first.ipAddress, '172.20.10.5');
      });
    });

    group('parseWindowsInterfaceMetadataForTest', () {
      test('should parse windows metadata payload', () {
        const payload =
            '{"Config":[{"InterfaceAlias":"Wi-Fi","IPv4Address":{"IPAddress":"192.168.1.20"},"IPv4DefaultGateway":{"NextHop":"192.168.1.1"}}],"Metrics":[{"InterfaceAlias":"Wi-Fi","InterfaceMetric":10}]}';

        final parsed = service.parseWindowsInterfaceMetadataForTest(payload);

        expect(parsed.isNotEmpty, true);
        final byIp = parsed['wi-fi|192.168.1.20'];
        expect(byIp, isNotNull);
        expect(byIp?['hasDefaultGateway'], true);
        expect(byIp?['interfaceMetric'], 10);
      });

      test('should return empty map for malformed json', () {
        final parsed = service.parseWindowsInterfaceMetadataForTest('[]');
        expect(parsed, isEmpty);
      });
    });
  });
}
