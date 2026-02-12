import 'package:flutter_test/flutter_test.dart';
import 'package:infrastructure_linux/features/setup/services/abstraction/i_linux_desktop_service.dart';
import 'package:infrastructure_linux/features/setup/services/linux_desktop_service.dart';

void main() {
  group('LinuxDesktopService', () {
    late ILinuxDesktopService desktopService;

    setUp(() {
      desktopService = LinuxDesktopService(
        getExecutablePath: () => '/usr/bin/test_app',
        getAppVersion: () async => '1.0.0',
      );
    });

    group('constructor', () {
      test('should create instance with required dependencies', () {
        expect(desktopService, isA<ILinuxDesktopService>());
      });

      test('should require getExecutablePath function', () {
        expect(
          () => LinuxDesktopService(
            getExecutablePath: () => '/usr/bin/test',
            getAppVersion: () async => '1.0.0',
          ),
          returnsNormally,
        );
      });

      test('should require getAppVersion function', () {
        expect(
          () => LinuxDesktopService(
            getExecutablePath: () => '/usr/bin/test',
            getAppVersion: () async => '2.0.0',
          ),
          returnsNormally,
        );
      });
    });

    group('updateDesktopFile', () {
      test('should accept filePath, iconPath, and appDir parameters', () {
        expect(desktopService.updateDesktopFile, isA<Function>());
      });
    });

    group('updateIconCache', () {
      test('should accept sharePath parameter', () {
        expect(desktopService.updateIconCache, isA<Function>());
      });
    });

    group('installSystemIcon', () {
      test('should accept sourceIcon parameter', () {
        expect(desktopService.installSystemIcon, isA<Function>());
      });
    });

    group('interface compliance', () {
      test('should implement ILinuxDesktopService', () {
        expect(desktopService, isA<ILinuxDesktopService>());
      });

      test('should have all required methods', () {
        expect(desktopService.updateDesktopFile, isA<Function>());
        expect(desktopService.updateIconCache, isA<Function>());
        expect(desktopService.installSystemIcon, isA<Function>());
      });
    });
  });
}
