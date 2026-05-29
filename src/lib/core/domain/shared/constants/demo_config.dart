/// Demo mode configuration constants.
///
/// Demo mode should only be enabled in development environments.
class DemoConfig {
  static const bool isDemoModeEnabled = bool.fromEnvironment('DEMO_MODE', defaultValue: false);

  static const String demoDataInitializedKey = 'demo_data_initialized';
}
