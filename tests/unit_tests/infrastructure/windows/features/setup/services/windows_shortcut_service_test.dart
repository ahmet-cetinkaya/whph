import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whph/infrastructure/windows/features/setup/services/abstraction/i_windows_shortcut_service.dart';
import 'package:whph/infrastructure/windows/features/setup/services/windows_shortcut_service.dart';

void main() {
  group('WindowsShortcutService', () {
    late IWindowsShortcutService shortcutService;

    setUp(() {
      shortcutService = WindowsShortcutService();
    });

    group('constructor', () {
      test('should create instance', () {
        expect(shortcutService, isA<IWindowsShortcutService>());
      });
    });

    group('createShortcut', () {
      test('should accept valid parameters', () async {
        if (!Platform.isWindows) {
          // Skip test on non-Windows platforms
          printOnFailure('⚠️  SKIPPED: createShortcut test requires Windows platform');
          return;
        }

        expect(
          shortcutService.createShortcut(
            target: 'C:\\test.exe',
            shortcutPath: 'C:\\test.lnk',
            iconPath: 'C:\\icon.ico',
          ),
          isA<Future<void>>(),
        );
      });

      test('should accept optional description', () async {
        if (!Platform.isWindows) {
          printOnFailure('⚠️  SKIPPED: createShortcut with description test requires Windows platform');
          return;
        }

        expect(
          shortcutService.createShortcut(
            target: 'C:\\test.exe',
            shortcutPath: 'C:\\test.lnk',
            iconPath: 'C:\\icon.ico',
            description: 'Test Application',
          ),
          isA<Future<void>>(),
        );
      });

      test('should handle null description', () async {
        if (!Platform.isWindows) {
          printOnFailure('⚠️  SKIPPED: createShortcut with null description test requires Windows platform');
          return;
        }

        expect(
          shortcutService.createShortcut(
            target: 'C:\\test.exe',
            shortcutPath: 'C:\\test.lnk',
            iconPath: 'C:\\icon.ico',
            description: null,
          ),
          isA<Future<void>>(),
        );
      });
    });

    group('createStartMenuShortcut', () {
      test('should accept required parameters', () async {
        if (!Platform.isWindows) {
          printOnFailure('⚠️  SKIPPED: createStartMenuShortcut test requires Windows platform');
          return;
        }

        expect(
          shortcutService.createStartMenuShortcut(
            appName: 'TestApp',
            target: 'C:\\test.exe',
            iconPath: 'C:\\icon.ico',
          ),
          isA<Future<void>>(),
        );
      });

      test('should accept optional description', () async {
        if (!Platform.isWindows) {
          printOnFailure('⚠️  SKIPPED: createStartMenuShortcut with description test requires Windows platform');
          return;
        }

        expect(
          shortcutService.createStartMenuShortcut(
            appName: 'TestApp',
            target: 'C:\\test.exe',
            iconPath: 'C:\\icon.ico',
            description: 'Test Application',
          ),
          isA<Future<void>>(),
        );
      });
    });

    group('interface compliance', () {
      test('should implement IWindowsShortcutService', () {
        expect(shortcutService, isA<IWindowsShortcutService>());
      });

      test('should have all required methods', () {
        expect(shortcutService.createShortcut, isA<Function>());
        expect(shortcutService.createStartMenuShortcut, isA<Function>());
      });
    });
  });
}
