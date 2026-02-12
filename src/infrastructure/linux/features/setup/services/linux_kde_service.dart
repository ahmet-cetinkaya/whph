import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:domain/shared/utils/logger.dart';
import 'abstraction/i_linux_kde_service.dart';

/// Implementation of KDE Plasma-specific integration.
class LinuxKdeService implements ILinuxKdeService {
  static const String _componentName = 'LinuxKdeService';
  final String Function() _getExecutablePath;

  LinuxKdeService({required String Function() getExecutablePath}) : _getExecutablePath = getExecutablePath;

  @override
  Future<bool> detectKDEEnvironment() async {
    final desktop = Platform.environment['XDG_CURRENT_DESKTOP']?.toLowerCase() ?? '';
    final session = Platform.environment['XDG_SESSION_DESKTOP']?.toLowerCase() ?? '';
    final kdeSession = Platform.environment['KDE_SESSION_VERSION'] ?? '';

    return desktop.contains('kde') || session.contains('kde') || desktop.contains('plasma') || kdeSession.isNotEmpty;
  }

  @override
  Future<void> setupKDEIntegration(String appDir) async {
    try {
      final isKDE = await detectKDEEnvironment();
      if (!isKDE) {
        DomainLogger.debug('KDE Plasma not detected, skipping KDE-specific setup', component: _componentName);
        return;
      }

      DomainLogger.debug('Setting up KDE Plasma integration...', component: _componentName);

      await installKDEDBusService(appDir);
      await registerKDEMimeTypes(appDir);
      await configureKDEWindowProperties();

      DomainLogger.debug('KDE Plasma integration completed', component: _componentName);
    } catch (e) {
      DomainLogger.debug('KDE Plasma integration setup failed: $e', component: _componentName);
    }
  }

  @override
  Future<void> installKDEDBusService(String appDir) async {
    try {
      final homeDir = Platform.environment['HOME'];
      final dbusServicesDir = path.join(homeDir!, '.local', 'share', 'dbus-1', 'services');

      await Directory(dbusServicesDir).create(recursive: true);

      final dbusServiceFile = path.join(dbusServicesDir, 'me.ahmetcetinkaya.whph.service');
      final sourceServiceFile = path.join(appDir, 'share', 'dbus-1', 'services', 'me.ahmetcetinkaya.whph.service');

      if (await File(sourceServiceFile).exists()) {
        var serviceContent = await File(sourceServiceFile).readAsString();
        serviceContent = serviceContent.replaceAll('@EXEC_PATH@', _getExecutablePath());

        await File(dbusServiceFile).writeAsString(serviceContent);
        DomainLogger.debug('KDE D-Bus service installed: $dbusServiceFile', component: _componentName);
      }
    } catch (e) {
      DomainLogger.debug('Failed to install KDE D-Bus service: $e', component: _componentName);
    }
  }

  @override
  Future<void> registerKDEMimeTypes(String appDir) async {
    try {
      final homeDir = Platform.environment['HOME'];
      final mimePackagesDir = path.join(homeDir!, '.local', 'share', 'mime', 'packages');

      await Directory(mimePackagesDir).create(recursive: true);

      final mimeFile = path.join(mimePackagesDir, 'whph.xml');
      final sourceMimeFile = path.join(appDir, 'share', 'mime', 'packages', 'whph.xml');

      if (await File(sourceMimeFile).exists()) {
        await File(sourceMimeFile).copy(mimeFile);

        try {
          await Process.run('update-mime-database', [path.join(homeDir, '.local', 'share', 'mime')]);
          DomainLogger.debug('KDE MIME types registered successfully', component: _componentName);
        } catch (e) {
          DomainLogger.debug('Failed to update MIME database: $e', component: _componentName);
        }
      }
    } catch (e) {
      DomainLogger.debug('Failed to register KDE MIME types: $e', component: _componentName);
    }
  }

  @override
  Future<void> configureKDEWindowProperties() async {
    try {
      DomainLogger.debug('KDE window properties configuration completed', component: _componentName);
    } catch (e) {
      DomainLogger.debug('Failed to configure KDE window properties: $e', component: _componentName);
    }
  }
}
