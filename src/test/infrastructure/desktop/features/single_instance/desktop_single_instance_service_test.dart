import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:whph/infrastructure/desktop/features/single_instance/desktop_single_instance_service.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// Mock PathProvider
class MockPathProviderPlatform extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  final Directory tempDir;

  MockPathProviderPlatform(this.tempDir);

  @override
  Future<String?> getTemporaryPath() async {
    return tempDir.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DesktopSingleInstanceService', () {
    late DesktopSingleInstanceService service;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('whph_test');
      PathProviderPlatform.instance = MockPathProviderPlatform(tempDir);
      service = DesktopSingleInstanceService();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('isAnotherInstanceRunning should return false initially', () async {
      // Since no file exists, it should return false
      // Note: This relies on file locking which might behave differently in test env,
      // but simpler check is just: can we run it?
      final isRunning = await service.isAnotherInstanceRunning();
      expect(isRunning, false);
    });

    test('sendCommandToExistingInstance should write to IPC file', () async {
      final success = await service.sendCommandToExistingInstance('TEST_COMMAND');

      // It might pass because it just writes to a file
      expect(success, true);

      final ipcFile = File('${tempDir.path}/whph.ipc');
      expect(await ipcFile.exists(), true);

      final content = await ipcFile.readAsString();
      final lines = content.split('\n');
      expect(lines.length, greaterThanOrEqualTo(3)); // ts, pid, command
      expect(lines[2], 'TEST_COMMAND');
    });

    // Testing lockInstance might be flaky due to file locks in same process,
    // but we can try.
    test('lockInstance should create lock file', () async {
      final success = await service.lockInstance();
      expect(success, true);

      final lockFile = File('${tempDir.path}/whph.lock');
      expect(await lockFile.exists(), true);

      await service.releaseInstance();
      expect(await lockFile.exists(), false);
    });
  });
}
