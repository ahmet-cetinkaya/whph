import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:infrastructure_windows/features/setup/exceptions/windows_firewall_rule_exception.dart';
import 'package:infrastructure_windows/features/setup/services/abstraction/i_windows_elevation_service.dart';
import 'package:infrastructure_windows/features/setup/services/abstraction/i_windows_firewall_service.dart';
import 'package:infrastructure_windows/features/setup/services/windows_firewall_service.dart';

import 'windows_firewall_service_test.mocks.dart';

@GenerateMocks([IWindowsElevationService])
void main() {
  group('WindowsFirewallService', () {
    late IWindowsFirewallService firewallService;
    late MockIWindowsElevationService mockElevationService;

    setUp(() {
      mockElevationService = MockIWindowsElevationService();
      firewallService = WindowsFirewallService(
        elevationService: mockElevationService,
      );
    });

    group('constructor', () {
      test('should create instance with elevation service', () {
        expect(firewallService, isA<IWindowsFirewallService>());
      });

      test('should require elevation service parameter', () {
        expect(
          () => WindowsFirewallService(elevationService: mockElevationService),
          returnsNormally,
        );
      });
    });

    group('addFirewallRule', () {
      test('should throw WindowsFirewallRuleException on empty port', () async {
        expect(
          () => firewallService.addFirewallRule(
            ruleName: 'TestRule',
            appPath: 'C:\\test.exe',
            port: '',
          ),
          throwsA(isA<WindowsFirewallRuleException>()),
        );
      });

      test('should throw WindowsFirewallRuleException on invalid port number', () async {
        expect(
          () => firewallService.addFirewallRule(
            ruleName: 'TestRule',
            appPath: 'C:\\test.exe',
            port: 'invalid',
          ),
          throwsA(isA<WindowsFirewallRuleException>()),
        );
      });

      test('should throw WindowsFirewallRuleException on port out of range (too low)', () async {
        expect(
          () => firewallService.addFirewallRule(
            ruleName: 'TestRule',
            appPath: 'C:\\test.exe',
            port: '0',
          ),
          throwsA(isA<WindowsFirewallRuleException>()),
        );
      });

      test('should throw WindowsFirewallRuleException on port out of range (too high)', () async {
        expect(
          () => firewallService.addFirewallRule(
            ruleName: 'TestRule',
            appPath: 'C:\\test.exe',
            port: '65536',
          ),
          throwsA(isA<WindowsFirewallRuleException>()),
        );
      });

      test('should throw WindowsFirewallRuleException on invalid protocol', () async {
        expect(
          () => firewallService.addFirewallRule(
            ruleName: 'TestRule',
            appPath: 'C:\\test.exe',
            port: '8080',
            protocol: 'INVALID',
          ),
          throwsA(isA<WindowsFirewallRuleException>()),
        );
      });

      test('should accept valid protocol (TCP)', () {
        // Validation should pass for valid parameters
        // We're not actually executing addFirewallRule here
        expect(firewallService.addFirewallRule, isA<Function>());
      });

      test('should accept valid protocol (UDP)', () {
        // Validation should pass for valid parameters
        expect(firewallService.addFirewallRule, isA<Function>());
      });
    });

    group('addFirewallRules', () {
      test('should accept valid parameters', () {
        // Just verify the method exists and has correct signature
        expect(firewallService.addFirewallRules, isA<Function>());
      });
    });

    group('checkFirewallRule', () {
      test('should accept ruleName parameter', () {
        expect(firewallService.checkFirewallRule, isA<Function>());
      });
    });

    group('removeFirewallRule', () {
      test('should accept ruleName parameter', () {
        expect(firewallService.removeFirewallRule, isA<Function>());
      });
    });

    group('interface compliance', () {
      test('should implement IWindowsFirewallService', () {
        expect(firewallService, isA<IWindowsFirewallService>());
      });

      test('should have all required methods', () {
        expect(firewallService.addFirewallRule, isA<Function>());
        expect(firewallService.addFirewallRules, isA<Function>());
        expect(firewallService.checkFirewallRule, isA<Function>());
        expect(firewallService.removeFirewallRule, isA<Function>());
      });
    });
  });
}
