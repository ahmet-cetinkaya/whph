class AppAssets {
  static const String logo = 'lib/domain/features/shared/assets/whph_logo.png';
  static const String logoAdaptiveBg = 'lib/domain/features/shared/assets/whph_logo_adaptive_bg.png';
  static const String logoAdaptiveFg = 'lib/domain/features/shared/assets/whph_logo_adaptive_fg.png';
  static const String logoAdaptiveFgIco = 'lib/domain/features/shared/assets/whph_logo_adaptive_fg.ico';
  static const String logoAdaptiveMono = 'lib/domain/features/shared/assets/whph_logo_adaptive_mono.png';
  static const String logoAdaptiveRound = 'lib/domain/features/shared/assets/whph_logo_adaptive_round.png';

  // Tray Icons
  static const String trayIconDefault = 'lib/domain/features/shared/assets/whph_logo_adaptive_fg';
  static const String trayIconPlay = 'lib/domain/features/shared/assets/whph_logo_fg_play';
  static const String trayIconPause = 'lib/domain/features/shared/assets/whph_logo_fg_pause';

  static String getTrayIcon(TrayIconType type, {bool isWindows = false}) {
    final extension = isWindows ? 'ico' : 'png';
    switch (type) {
      case TrayIconType.play:
        return '$trayIconPlay.$extension';
      case TrayIconType.pause:
        return '$trayIconPause.$extension';
      case TrayIconType.default_:
      default:
        return '$trayIconDefault.$extension';
    }
  }
}

enum TrayIconType {
  default_,
  play,
  pause,
  paused,
}
