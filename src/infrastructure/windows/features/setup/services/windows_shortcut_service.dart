import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/windows/features/setup/constants/windows_script_templates.dart';
import 'package:whph/infrastructure/windows/features/setup/services/abstraction/i_windows_shortcut_service.dart';

/// Implementation of Windows shortcut management service
class WindowsShortcutService implements IWindowsShortcutService {
  static const String _componentName = 'WindowsShortcutService';

  @override
  Future<void> createStartMenuShortcut({
    required String appName,
    required String target,
    required String iconPath,
    String? description,
  }) async {
    try {
      final startMenuPath = path.join(
        Platform.environment['APPDATA']!,
        'Microsoft',
        'Windows',
        'Start Menu',
        'Programs',
        appName,
      );

      await Directory(startMenuPath).create(recursive: true);

      final shortcutPath = path.join(startMenuPath, '$appName.lnk');

      await createShortcut(
        target: target,
        shortcutPath: shortcutPath,
        iconPath: iconPath,
        description: description,
      );

      DomainLogger.info('Created Start Menu shortcut at: $shortcutPath', component: _componentName);
    } catch (e) {
      DomainLogger.error('Failed to create Start Menu shortcut: $e', component: _componentName);
      rethrow;
    }
  }

  @override
  Future<void> createShortcut({
    required String target,
    required String shortcutPath,
    required String iconPath,
    String? description,
  }) async {
    try {
      final psScript = WindowsScriptTemplates.shortcutScript
          .replaceAll('{shortcutPath}', shortcutPath)
          .replaceAll('{target}', target)
          .replaceAll('{iconPath}', iconPath)
          .replaceAll(
            '{description}',
            description != null ? '\$Shortcut.Description = "$description"' : '',
          );

      final result = await Process.run('powershell', ['-Command', psScript]);

      if (result.exitCode != 0) {
        throw Exception('Failed to create shortcut: ${result.stderr}');
      }

      DomainLogger.debug('Created shortcut: $shortcutPath', component: _componentName);
    } catch (e) {
      DomainLogger.error('Failed to create shortcut: $e', component: _componentName);
      rethrow;
    }
  }
}
