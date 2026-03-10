/// Interface for KDE Plasma-specific integration.
abstract class ILinuxKdeService {
  /// Detect if currently running in a KDE Plasma environment.
  Future<bool> detectKDEEnvironment();

  /// Setup all KDE-specific integrations.
  Future<void> setupKDEIntegration(String appDir);

  /// Install D-Bus service for KDE.
  Future<void> installKDEDBusService(String appDir);

  /// Register MIME types for KDE.
  Future<void> registerKDEMimeTypes(String appDir);

  /// Configure KDE-specific window properties.
  Future<void> configureKDEWindowProperties();
}
