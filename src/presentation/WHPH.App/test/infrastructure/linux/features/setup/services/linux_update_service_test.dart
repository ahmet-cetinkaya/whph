import 'package:flutter_test/flutter_test.dart';
import 'package:whph/infrastructure/linux/features/setup/services/abstraction/i_linux_update_service.dart';
import 'package:whph/infrastructure/linux/features/setup/services/linux_update_service.dart';

void main() {
  group('LinuxUpdateService', () {
    late ILinuxUpdateService updateService;

    setUp(() {
      updateService = LinuxUpdateService();
    });

    group('constructor', () {
      test('should create instance', () {
        expect(updateService, isA<ILinuxUpdateService>());
      });
    });

    group('getAppVersion', () {
      test('should return a version string', () async {
        final version = await updateService.getAppVersion();
        expect(version, isA<String>());
        expect(version, isNotEmpty);
      });

      test('should return valid semver format', () async {
        final version = await updateService.getAppVersion();
        // Should match pattern like "1.0.0" or "0.18.0"
        expect(version, matches(RegExp(r'^\d+\.\d+\.\d+$')));
      });
    });

    group('downloadAndInstallUpdate', () {
      test('should accept downloadUrl parameter', () {
        expect(updateService.downloadAndInstallUpdate, isA<Function>());
      });
    });

    group('interface compliance', () {
      test('should implement ILinuxUpdateService', () {
        expect(updateService, isA<ILinuxUpdateService>());
      });

      test('should have all required methods', () {
        expect(updateService.getAppVersion, isA<Function>());
        expect(updateService.downloadAndInstallUpdate, isA<Function>());
      });
    });
  });
}
