import 'package:whph/domain/features/shared/constants/app_assets.dart';

class TrayMenuItem {
  final String key;
  final String label;
  final bool isSeparator;
  final Function()? onClicked;

  const TrayMenuItem({
    required this.key,
    required this.label,
    this.isSeparator = false,
    this.onClicked,
  });

  static TrayMenuItem separator() => const TrayMenuItem(
        key: 'separator',
        label: '',
        isSeparator: true,
      );
}

abstract class ISystemTrayService {
  Future<void> init();
  Future<void> destroy();
  Future<void> showWindow();
  Future<void> hideWindow();
  Future<void> exitApp();
  Future<void> setTrayIcon(TrayIconType type);
  Future<void> addMenuItem(TrayMenuItem item);
  Future<void> addMenuItems(List<TrayMenuItem> items);
  Future<void> removeMenuItem(String key);
  Future<void> clearMenu();
  Future<void> rebuildMenu();
}
