import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/services/concurrent_connection_service.dart';

void main() {
  group('ConcurrentConnectionService', () {
    late ConcurrentConnectionService service;

    setUp(() {
      service = ConcurrentConnectionService();
    });

    group('testMultipleAddresses', () {
      test('should handle empty IP address list', () async {
        final result = await service.testMultipleAddresses([], 12345);
        expect(result, isEmpty);
      });

      test('should test connectivity to unreachable addresses', () async {
        // Testing unreachable addresses
        final addresses = ['192.168.999.1', '192.168.999.2'];
        final result = await service.testMultipleAddresses(
          addresses,
          12345, // Non-existent port
          timeout: const Duration(milliseconds: 100),
        );

        // Should return empty list since addresses are not reachable on the test port
        expect(result, isA<List<String>>());
        expect(result, isEmpty);
      });
    });

    group('ConcurrentConnectionService integration', () {
      test('should test multiple addresses via ConcurrentConnectionService', () async {
        final addresses = ['192.168.1.1', '10.0.0.1'];
        final result = await service.testMultipleAddresses(
          addresses,
          12345,
          timeout: const Duration(milliseconds: 100),
        );

        expect(result, isA<List<String>>());
      });
    });

    group('testWebSocketConnection', () {
      test('should return false for unreachable address', () async {
        final result = await service.testWebSocketConnection(
          '192.168.999.999',
          12345,
          timeout: const Duration(milliseconds: 100),
        );

        expect(result, false);
      });

      test('should handle invalid IP addresses gracefully', () async {
        final result = await service.testWebSocketConnection(
          'invalid-ip',
          12345,
          timeout: const Duration(milliseconds: 100),
        );

        expect(result, false);
      });
    });

    group('connectToAnyAddress', () {
      test('should return null for empty IP address list', () async {
        final result = await service.connectToAnyAddress([], 12345);
        expect(result, isNull);
      });

      test('should return null for unreachable addresses', () async {
        final addresses = ['192.168.999.1', '192.168.999.2'];
        final result = await service.connectToAnyAddress(
          addresses,
          12345,
          timeout: const Duration(milliseconds: 100),
        );

        expect(result, isNull);
      });
    });
  });
}
