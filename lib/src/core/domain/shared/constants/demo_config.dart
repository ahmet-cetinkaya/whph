/// Demo mode configuration constants
///
/// This file contains configuration for demo mode functionality.
/// Demo mode should only be enabled in development environments.
class DemoConfig {
  /// Whether demo mode is enabled
  /// This is controlled by the environment variable 'DEMO_MODE' or build configuration
  static const bool isDemoModeEnabled = bool.fromEnvironment('DEMO_MODE', defaultValue: false);

  /// Setting key to track if demo data has been initialized
  static const String demoDataInitializedKey = 'demo_data_initialized';
}
