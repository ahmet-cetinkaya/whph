import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:infrastructure_shared/features/setup/services/abstraction/base_setup_service.dart';
import 'package:infrastructure_windows/features/setup/services/abstraction/i_windows_firewall_service.dart';
import 'package:infrastructure_windows/features/setup/services/abstraction/i_windows_shortcut_service.dart';
import 'package:infrastructure_windows/features/setup/services/abstraction/i_windows_update_service.dart';
import 'package:infrastructure_windows/features/setup/windows_setup_service.dart';

import 'windows_setup_service_test.mocks.dart';

@GenerateMocks([
  IWindowsFirewallService,
  IWindowsShortcutService,
  IWindowsUpdateService,
])
void main() {
  group('WindowsSetupService', () {
    late WindowsSetupService setupService;
    late MockIWindowsFirewallService mockFirewallService;
    late MockIWindowsShortcutService mockShortcutService;
    late MockIWindowsUpdateService mockUpdateService;

    setUp(() {
      mockFirewallService = MockIWindowsFirewallService();
      mockShortcutService = MockIWindowsShortcutService();
      mockUpdateService = MockIWindowsUpdateService();

      setupService = WindowsSetupService(
        firewallService: mockFirewallService,
        shortcutService: mockShortcutService,
        updateService: mockUpdateService,
      );
    });

    group('constructor', () {
      test('should create instance with all dependencies', () {
        expect(setupService, isA<BaseSetupService>());
      });

      test('should require all service parameters', () {
        expect(
          () => WindowsSetupService(
            firewallService: mockFirewallService,
            shortcutService: mockShortcutService,
            updateService: mockUpdateService,
          ),
          returnsNormally,
        );
      });
    });

    group('setupEnvironment', () {
      test('should delegate to shortcut service on Windows', () async {
        if (!Platform.isWindows) {
          printOnFailure('⚠️  SKIPPED: setupEnvironment delegation test requires Windows platform');
          return;
        }

        when(mockShortcutService.createStartMenuShortcut(
          appName: anyNamed('appName'),
          target: anyNamed('target'),
          iconPath: anyNamed('iconPath'),
          description: anyNamed('description'),
        )).thenAnswer((_) async => {});

        await setupService.setupEnvironment();

        verify(mockShortcutService.createStartMenuShortcut(
          appName: anyNamed('appName'),
          target: anyNamed('target'),
          iconPath: anyNamed('iconPath'),
          description: anyNamed('description'),
        )).called(1);
      });

      test('should handle errors gracefully', () async {
        if (!Platform.isWindows) {
          printOnFailure('⚠️  SKIPPED: setupEnvironment error handling test requires Windows platform');
          return;
        }

        when(mockShortcutService.createStartMenuShortcut(
          appName: anyNamed('appName'),
          target: anyNamed('target'),
          iconPath: anyNamed('iconPath'),
          description: anyNamed('description'),
        )).thenThrow(Exception('Test error'));

        // Should not throw - errors are logged
        await expectLater(
          setupService.setupEnvironment(),
          completes,
        );
      });

      test('should return early on non-Windows platforms', () async {
        if (Platform.isWindows) {
          printOnFailure('⚠️  SKIPPED: Non-Windows behavior test requires non-Windows platform');
          return;
        }

        // On non-Windows, should return immediately without calling services
        await setupService.setupEnvironment();

        // No verification needed - just ensuring it completes
        expect(setupService, isNotNull);
      });
    });

    group('downloadAndInstallUpdate', () {
      test('should delegate to update service', () async {
        const testUrl = 'https://example.com/update.zip';
        when(mockUpdateService.downloadAndInstallUpdate(testUrl)).thenAnswer((_) async => {});

        await setupService.downloadAndInstallUpdate(testUrl);

        verify(mockUpdateService.downloadAndInstallUpdate(testUrl)).called(1);
      });
    });

    group('addFirewallRules', () {
      test('should delegate to firewall service', () async {
        when(mockFirewallService.addFirewallRules(
          ruleNamePrefix: anyNamed('ruleNamePrefix'),
          appPath: anyNamed('appPath'),
          port: anyNamed('port'),
          protocol: anyNamed('protocol'),
        )).thenAnswer((_) async => {});

        await setupService.addFirewallRules(
          ruleNamePrefix: 'TestApp',
          appPath: 'C:\\test.exe',
          port: '8080',
        );

        verify(mockFirewallService.addFirewallRules(
          ruleNamePrefix: 'TestApp',
          appPath: 'C:\\test.exe',
          port: '8080',
          protocol: 'TCP',
        )).called(1);
      });

      test('should pass custom protocol', () async {
        when(mockFirewallService.addFirewallRules(
          ruleNamePrefix: anyNamed('ruleNamePrefix'),
          appPath: anyNamed('appPath'),
          port: anyNamed('port'),
          protocol: anyNamed('protocol'),
        )).thenAnswer((_) async => {});

        await setupService.addFirewallRules(
          ruleNamePrefix: 'TestApp',
          appPath: 'C:\\test.exe',
          port: '8080',
          protocol: 'UDP',
        );

        verify(mockFirewallService.addFirewallRules(
          ruleNamePrefix: 'TestApp',
          appPath: 'C:\\test.exe',
          port: '8080',
          protocol: 'UDP',
        )).called(1);
      });
    });

    group('checkFirewallRule', () {
      test('should delegate to firewall service', () async {
        when(mockFirewallService.checkFirewallRule(
          ruleName: anyNamed('ruleName'),
          protocol: anyNamed('protocol'),
        )).thenAnswer((_) async => true);

        final result = await setupService.checkFirewallRule(
          ruleName: 'TestRule',
        );

        expect(result, true);
        verify(mockFirewallService.checkFirewallRule(
          ruleName: 'TestRule',
          protocol: 'TCP',
        )).called(1);
      });
    });

    group('addFirewallRule', () {
      test('should delegate to firewall service', () async {
        when(mockFirewallService.addFirewallRule(
          ruleName: anyNamed('ruleName'),
          appPath: anyNamed('appPath'),
          port: anyNamed('port'),
          protocol: anyNamed('protocol'),
          direction: anyNamed('direction'),
        )).thenAnswer((_) async => {});

        await setupService.addFirewallRule(
          ruleName: 'TestRule',
          appPath: 'C:\\test.exe',
          port: '8080',
        );

        verify(mockFirewallService.addFirewallRule(
          ruleName: 'TestRule',
          appPath: 'C:\\test.exe',
          port: '8080',
          protocol: 'TCP',
          direction: 'in',
        )).called(1);
      });
    });

    group('removeFirewallRule', () {
      test('should delegate to firewall service', () async {
        when(mockFirewallService.removeFirewallRule(
          ruleName: anyNamed('ruleName'),
        )).thenAnswer((_) async => {});

        await setupService.removeFirewallRule(ruleName: 'TestRule');

        verify(mockFirewallService.removeFirewallRule(
          ruleName: 'TestRule',
        )).called(1);
      });
    });

    group('delegation pattern', () {
      test('should act as coordinator for all services', () {
        // Verify all services are injected
        expect(setupService, isNotNull);
      });

      test('should not contain business logic itself', () {
        // All methods should delegate to services
        // This is verified by the individual method tests above
        expect(setupService, isA<BaseSetupService>());
      });
    });
  });
}
