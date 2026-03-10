import 'package:whph/core/domain/shared/constants/app_assets.dart';

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

  TrayMenuItem.separator(String key)
      : this(
          key: key,
          label: '',
          isSeparator: true,
        );
}

abstract class ISystemTrayService {
  // Core methods
  Future<void> init();
  Future<void> destroy();

  // Tray/notification functionality
  Future<void> setIcon(TrayIconType type);
  Future<void> setTitle(String title);
  Future<void> setBody(String body);
  Future<void> reset();

  // Menu management
  List<TrayMenuItem> getMenuItems();
  Future<void> setMenuItems(List<TrayMenuItem> items);
  Future<void> insertMenuItem(TrayMenuItem item, {int? index});
  Future<void> updateMenuItem(String key, TrayMenuItem newItem);
  Future<TrayMenuItem?> getMenuItem(String key);
  Future<void> removeMenuItem(String key);
}
