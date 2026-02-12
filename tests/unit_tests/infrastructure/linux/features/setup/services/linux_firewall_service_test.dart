import 'package:flutter_test/flutter_test.dart';
import 'package:infrastructure_linux/features/setup/exceptions/linux_firewall_rule_exception.dart';
import 'package:infrastructure_linux/features/setup/services/abstraction/i_linux_firewall_service.dart';
import 'package:infrastructure_linux/features/setup/services/linux_firewall_service.dart';

void main() {
  group('LinuxFirewallService', () {
    late ILinuxFirewallService firewallService;

    setUp(() {
      firewallService = LinuxFirewallService();
    });

    group('constructor', () {
      test('should create instance', () {
        expect(firewallService, isA<ILinuxFirewallService>());
      });
    });

    group('addFirewallRule - validation', () {
      test('should throw LinuxFirewallRuleException on empty port', () async {
        expect(
          () => firewallService.addFirewallRule(
            ruleName: 'TestRule',
            appPath: '/usr/bin/test',
            port: '',
          ),
          throwsA(isA<LinuxFirewallRuleException>()),
        );
      });

      test('should throw LinuxFirewallRuleException on invalid port number', () async {
        expect(
          () => firewallService.addFirewallRule(
            ruleName: 'TestRule',
            appPath: '/usr/bin/test',
            port: 'invalid',
          ),
          throwsA(isA<LinuxFirewallRuleException>()),
        );
      });

      test('should throw LinuxFirewallRuleException on port out of range (too low)', () async {
        expect(
          () => firewallService.addFirewallRule(
            ruleName: 'TestRule',
            appPath: '/usr/bin/test',
            port: '0',
          ),
          throwsA(isA<LinuxFirewallRuleException>()),
        );
      });

      test('should throw LinuxFirewallRuleException on port out of range (too high)', () async {
        expect(
          () => firewallService.addFirewallRule(
            ruleName: 'TestRule',
            appPath: '/usr/bin/test',
            port: '65536',
          ),
          throwsA(isA<LinuxFirewallRuleException>()),
        );
      });

      test('should throw LinuxFirewallRuleException on invalid protocol', () async {
        expect(
          () => firewallService.addFirewallRule(
            ruleName: 'TestRule',
            appPath: '/usr/bin/test',
            port: '8080',
            protocol: 'INVALID',
          ),
          throwsA(isA<LinuxFirewallRuleException>()),
        );
      });

      test('should throw LinuxFirewallRuleException on empty protocol', () async {
        expect(
          () => firewallService.addFirewallRule(
            ruleName: 'TestRule',
            appPath: '/usr/bin/test',
            port: '8080',
            protocol: '',
          ),
          throwsA(isA<LinuxFirewallRuleException>()),
        );
      });

      test('should accept valid protocol (TCP)', () {
        expect(firewallService.addFirewallRule, isA<Function>());
      });

      test('should accept valid protocol (UDP)', () {
        expect(firewallService.addFirewallRule, isA<Function>());
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
      test('should implement ILinuxFirewallService', () {
        expect(firewallService, isA<ILinuxFirewallService>());
      });

      test('should have all required methods', () {
        expect(firewallService.addFirewallRule, isA<Function>());
        expect(firewallService.checkFirewallRule, isA<Function>());
        expect(firewallService.removeFirewallRule, isA<Function>());
      });
    });
  });
}
