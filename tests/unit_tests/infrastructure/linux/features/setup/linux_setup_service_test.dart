import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:infrastructure_linux/features/setup/linux_setup_service.dart';
import 'package:infrastructure_linux/features/setup/services/abstraction/i_linux_firewall_service.dart';
import 'package:infrastructure_linux/features/setup/services/abstraction/i_linux_desktop_service.dart';
import 'package:infrastructure_linux/features/setup/services/abstraction/i_linux_kde_service.dart';
import 'package:infrastructure_linux/features/setup/services/abstraction/i_linux_update_service.dart';
import 'package:infrastructure_shared/features/setup/services/abstraction/base_setup_service.dart';

import 'linux_setup_service_test.mocks.dart';

@GenerateMocks([
  ILinuxFirewallService,
  ILinuxDesktopService,
  ILinuxKdeService,
  ILinuxUpdateService,
])
void main() {
  group('LinuxSetupService', () {
    late LinuxSetupService setupService;
    late MockILinuxFirewallService mockFirewallService;
    late MockILinuxDesktopService mockDesktopService;
    late MockILinuxKdeService mockKdeService;
    late MockILinuxUpdateService mockUpdateService;

    setUp(() {
      mockFirewallService = MockILinuxFirewallService();
      mockDesktopService = MockILinuxDesktopService();
      mockKdeService = MockILinuxKdeService();
      mockUpdateService = MockILinuxUpdateService();

      setupService = LinuxSetupService(
        firewallService: mockFirewallService,
        desktopService: mockDesktopService,
        kdeService: mockKdeService,
        updateService: mockUpdateService,
      );
    });

    group('constructor', () {
      test('should create instance with all required services', () {
        expect(setupService, isA<LinuxSetupService>());
      });

      test('should extend BaseSetupService', () {
        expect(setupService, isA<BaseSetupService>());
      });
    });

    group('checkFirewallRule', () {
      test('should delegate to firewall service', () async {
        when(mockFirewallService.checkFirewallRule(
          ruleName: anyNamed('ruleName'),
          protocol: anyNamed('protocol'),
        )).thenAnswer((_) async => true);

        final result = await setupService.checkFirewallRule(
          ruleName: 'WHPH Port 44040',
          protocol: 'TCP',
        );

        expect(result, isTrue);
        verify(mockFirewallService.checkFirewallRule(
          ruleName: 'WHPH Port 44040',
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
        )).thenAnswer((_) async {});

        await setupService.addFirewallRule(
          ruleName: 'WHPH Port 44040',
          appPath: '/usr/bin/whph',
          port: '44040',
          protocol: 'TCP',
          direction: 'in',
        );

        verify(mockFirewallService.addFirewallRule(
          ruleName: 'WHPH Port 44040',
          appPath: '/usr/bin/whph',
          port: '44040',
          protocol: 'TCP',
          direction: 'in',
        )).called(1);
      });
    });

    group('removeFirewallRule', () {
      test('should delegate to firewall service', () async {
        when(mockFirewallService.removeFirewallRule(
          ruleName: anyNamed('ruleName'),
        )).thenAnswer((_) async {});

        await setupService.removeFirewallRule(ruleName: 'WHPH Port 44040');

        verify(mockFirewallService.removeFirewallRule(
          ruleName: 'WHPH Port 44040',
        )).called(1);
      });
    });

    group('downloadAndInstallUpdate', () {
      test('should delegate to update service', () async {
        when(mockUpdateService.downloadAndInstallUpdate(any)).thenAnswer((_) async {});

        await setupService.downloadAndInstallUpdate('https://example.com/update.tar.gz');

        verify(mockUpdateService.downloadAndInstallUpdate('https://example.com/update.tar.gz')).called(1);
      });
    });

    group('interface compliance', () {
      test('should have setupEnvironment method', () {
        expect(setupService.setupEnvironment, isA<Function>());
      });

      test('should have all firewall methods', () {
        expect(setupService.checkFirewallRule, isA<Function>());
        expect(setupService.addFirewallRule, isA<Function>());
        expect(setupService.removeFirewallRule, isA<Function>());
      });

      test('should have update method', () {
        expect(setupService.downloadAndInstallUpdate, isA<Function>());
      });
    });
  });
}
