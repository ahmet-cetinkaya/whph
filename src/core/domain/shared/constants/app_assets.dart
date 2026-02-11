class AppAssets {
  static const String logo = 'packages/domain/assets/images/whph_logo.png';
  static const String logoAdaptiveBg = 'packages/domain/assets/images/whph_logo_adaptive_bg.png';
  static const String logoAdaptiveFg = 'packages/domain/assets/images/whph_logo_adaptive_fg.png';
  static const String logoAdaptiveFgIco = 'packages/domain/assets/images/whph_logo_adaptive_fg.ico';
  static const String logoAdaptiveMono = 'packages/domain/assets/images/whph_logo_adaptive_mono.png';
  static const String logoAdaptiveRound = 'packages/domain/assets/images/whph_logo_adaptive_round.png';

  // Tray Icons
  static const String trayIconDefault = 'packages/domain/assets/images/whph_logo_adaptive_fg';
  static const String trayIconPlay = 'packages/domain/assets/images/whph_logo_fg_play';
  static const String trayIconPause = 'packages/domain/assets/images/whph_logo_fg_pause';

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
