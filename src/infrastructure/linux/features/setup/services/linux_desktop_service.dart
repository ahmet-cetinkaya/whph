import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:domain/shared/utils/logger.dart';
import 'abstraction/i_linux_desktop_service.dart';

/// Implementation of Linux desktop file and icon operations.
class LinuxDesktopService implements ILinuxDesktopService {
  static const String _componentName = 'LinuxDesktopService';
  final String Function() _getExecutablePath;
  final Future<String> Function() _getAppVersion;

  LinuxDesktopService({
    required String Function() getExecutablePath,
    required Future<String> Function() getAppVersion,
  })  : _getExecutablePath = getExecutablePath,
        _getAppVersion = getAppVersion;

  @override
  Future<void> updateDesktopFile(String filePath, String iconPath, String appDir) async {
    if (!await File(filePath).exists()) {
      DomainLogger.error('Desktop file not found: $filePath', component: _componentName);
      return;
    }

    try {
      var content = await File(filePath).readAsString();
      final execPath = _getExecutablePath();
      final appVersion = await _getAppVersion();

      if (execPath.isEmpty) {
        DomainLogger.error('Executable path is empty', component: _componentName);
        return;
      }

      if (iconPath.isEmpty || !File(iconPath).existsSync()) {
        DomainLogger.warning('Icon path is invalid: $iconPath', component: _componentName);
      }

      final templateReplacements = {
        '@EXEC_PATH@': execPath,
        '@ICON_PATH@': iconPath,
        '@APP_VERSION@': appVersion,
      };

      final regexReplacements = {
        RegExp(r'^Exec\s*=\s*.+$', multiLine: true): 'Exec=$execPath',
        RegExp(r'^Icon\s*=\s*whph$', multiLine: true): 'Icon=$iconPath',
        RegExp(r'^Icon\s*=\s*/[^/\n]+/[^/\n]+/[^/\n]+$', multiLine: true): 'Icon=$iconPath',
        RegExp(r'^X-GNOME-Bugzilla-Version\s*=\s*.+$', multiLine: true): 'X-GNOME-Bugzilla-Version=$appVersion',
        RegExp(r'^X-AppImage-Version\s*=\s*.+$', multiLine: true): 'X-AppImage-Version=$appVersion',
      };

      final missingVars = _validateTemplateVariables(content, templateReplacements);
      if (missingVars.isNotEmpty) {
        DomainLogger.warning('Missing template variable replacements: ${missingVars.join(', ')}',
            component: _componentName);
      }

      bool hasChanges = false;

      for (final entry in templateReplacements.entries) {
        if (content.contains(entry.key)) {
          content = content.replaceAll(entry.key, entry.value);
          hasChanges = true;
          DomainLogger.debug('Replaced template variable: ${entry.key} -> ${entry.value}', component: _componentName);
        }
      }

      for (final entry in regexReplacements.entries) {
        if (entry.key.hasMatch(content)) {
          content = content.replaceAll(entry.key, entry.value);
          hasChanges = true;
          DomainLogger.debug('Replaced pattern: ${entry.key.pattern} -> ${entry.value}', component: _componentName);
        }
      }

      content = _validateAndCleanDesktopFile(content);

      if (hasChanges) {
        await File(filePath).writeAsString(content);
        DomainLogger.debug('Desktop file updated successfully: $filePath', component: _componentName);
      } else {
        DomainLogger.debug('No template variables found in desktop file: $filePath', component: _componentName);
      }
    } catch (e) {
      DomainLogger.error('Failed to update desktop file $filePath: $e', component: _componentName);
    }
  }

  @override
  Future<void> updateIconCache(String sharePath) async {
    try {
      await Process.run('gtk-update-icon-cache', ['-f', '-t', path.join(sharePath, 'icons', 'hicolor')]);
      await Process.run('update-desktop-database', [path.join(sharePath, 'applications')]);
    } catch (e) {
      DomainLogger.error('Error updating icon cache: $e', component: _componentName);
    }
  }

  @override
  Future<void> installSystemIcon(String sourceIcon) async {
    try {
      final userIconDir = path.join(
        Platform.environment['HOME']!,
        '.local',
        'share',
        'icons',
        'hicolor',
        '512x512',
        'apps',
      );

      if (await Directory(userIconDir).exists()) {
        await File(sourceIcon).copy(path.join(userIconDir, 'whph.png'));
        await Process.run('gtk-update-icon-cache', ['-f', '-t', path.join(userIconDir, '..')]);
      }
    } catch (e) {
      DomainLogger.error('Could not install icon: $e', component: _componentName);
    }
  }

  List<String> _validateTemplateVariables(String content, Map<String, String> replacements) {
    final missingVariables = <String>[];
    final templateVariables = ['@EXEC_PATH@', '@ICON_PATH@', '@APP_VERSION@'];

    for (final variable in templateVariables) {
      if (content.contains(variable) && !replacements.containsKey(variable)) {
        missingVariables.add(variable);
      }
    }
    return missingVariables;
  }

  String _validateAndCleanDesktopFile(String content) {
    final requiredKeys = ['Type=Application', 'Categories='];

    for (final key in requiredKeys) {
      if (!content.contains(RegExp('^$key', multiLine: true))) {
        DomainLogger.warning('Missing required desktop file key: $key', component: _componentName);
      }
    }

    final validationErrors = <String>[];

    if (content.contains(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'))) {
      validationErrors.add('Invalid control characters found');
    }

    final lines = content.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isNotEmpty && !line.startsWith('#') && !line.startsWith('[')) {
        if (!line.contains('=') || line.startsWith('=')) {
          validationErrors.add('Invalid key-value format at line ${i + 1}: $line');
        }
      }
    }

    if (validationErrors.isNotEmpty) {
      DomainLogger.warning('Desktop file validation errors: ${validationErrors.join(', ')}', component: _componentName);
    }

    content = content.replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n');

    if (!content.endsWith('\n')) {
      content += '\n';
    }

    return content;
  }
}
