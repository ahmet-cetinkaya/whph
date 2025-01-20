class AppAssets {
  static const String logo = 'lib/domain/features/shared/assets/whph_logo.png';
  static const String logoAdaptiveBg = 'lib/domain/features/shared/assets/whph_logo_adaptive_bg.png';
  static const String logoAdaptiveFg = 'lib/domain/features/shared/assets/whph_logo_adaptive_fg.png';
  static const String logoAdaptiveFgIco = 'lib/domain/features/shared/assets/whph_logo_adaptive_fg.ico';
  static const String logoAdaptiveMono = 'lib/domain/features/shared/assets/whph_logo_adaptive_mono.png';
  static const String logoAdaptiveRound = 'lib/domain/features/shared/assets/whph_logo_adaptive_round.png';

  // Tray Icons
  static const String trayIconDefault = 'lib/domain/features/shared/assets/whph_logo_adaptive_fg';
  static const String trayIconActive = 'lib/domain/features/shared/assets/whph_logo_adaptive_active';
  static const String trayIconPaused = 'lib/domain/features/shared/assets/whph_logo_adaptive_paused';

  static String getTrayIcon(TrayIconType type, {bool isWindows = false}) {
    final basePath = switch (type) {
      TrayIconType.default_ => trayIconDefault,
      TrayIconType.active => trayIconActive,
      TrayIconType.paused => trayIconPaused,
    };
    return '$basePath${isWindows ? '.ico' : '.png'}';
  }
}

enum TrayIconType {
  default_,
  active,
  paused,
}
