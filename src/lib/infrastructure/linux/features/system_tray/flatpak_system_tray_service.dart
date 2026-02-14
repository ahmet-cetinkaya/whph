import 'package:tray_manager/tray_manager.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/domain/shared/constants/app_assets.dart';
import 'package:whph/infrastructure/desktop/features/system_tray/desktop_system_tray_service.dart';

class FlatpakSystemTrayService extends DesktopSystemTrayService {
  @override
  Future<void> setIcon(TrayIconType type) async {
    try {
      // On Linux Flatpak, use the App ID variants as the icon name
      // The icons are installed to /app/share/icons/hicolor/512x512/apps/
      // and exported to the host.
      switch (type) {
        case TrayIconType.play:
          await trayManager.setIcon('me.ahmetcetinkaya.whph.play');
          break;
        case TrayIconType.pause:
          await trayManager.setIcon('me.ahmetcetinkaya.whph.pause');
          break;
        case TrayIconType.default_:
        default:
          await trayManager.setIcon('me.ahmetcetinkaya.whph.default');
          break;
      }
    } catch (e) {
      Logger.error('Error setting Flatpak tray icon: $e');
    }
  }
}
