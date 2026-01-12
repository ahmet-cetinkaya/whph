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
    late PathProviderPlatform originalPathProviderPlatform;

    setUp(() async {
      originalPathProviderPlatform = PathProviderPlatform.instance;
      tempDir = await Directory.systemTemp.createTemp('whph_test');
      PathProviderPlatform.instance = MockPathProviderPlatform(tempDir);
      service = DesktopSingleInstanceService();
    });

    tearDown(() async {
      await service.stopListeningForCommands();
      await service.releaseInstance();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      PathProviderPlatform.instance = originalPathProviderPlatform;
    });

    test('isAnotherInstanceRunning should return false initially', () async {
      final isRunning = await service.isAnotherInstanceRunning();
      expect(isRunning, false);
    });

    test('startListeningForCommands should create port file', () async {
      await service.startListeningForCommands((cmd) {});

      final portFile = File('${tempDir.path}/whph.port');
      expect(await portFile.exists(), true);

      final content = await portFile.readAsString();
      final port = int.tryParse(content);
      expect(port, isNotNull);
      expect(port, greaterThan(0));
    });

    test('sendCommandToExistingInstance should connect to listener', () async {
      String? receivedCommand;

      // Start listener
      await service.startListeningForCommands((cmd) {
        receivedCommand = cmd;
      });

      // Send command
      final success = await service.sendCommandToExistingInstance('TEST_COMMAND');
      expect(success, true);

      // Wait a bit for async socket
      await Future.delayed(Duration(milliseconds: 100));
      expect(receivedCommand, 'TEST_COMMAND');
    });

    test('sendCommandAndStreamOutput should receive streamed data', () async {
      // Start listener that echoes back logic
      await service.startListeningForCommands((cmd) {
        if (cmd == 'STREAM') {
          // Fire-and-forget broadcasts in test
          service.broadcastMessage('Line 1');
          service.broadcastMessage('Line 2');
          service.broadcastMessage('DONE');
        }
      });

      final receivedLines = <String>[];
      await service.sendCommandAndStreamOutput('STREAM', onOutput: (line) {
        receivedLines.add(line);
      });

      expect(receivedLines, contains('Line 1'));
      expect(receivedLines, contains('Line 2'));
    });

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
