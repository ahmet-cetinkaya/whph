import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/components/settings_menu_tile.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/ui/shared/constants/app_routes.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/navigation_items.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';

class DefaultPageSettings extends StatefulWidget {
  final VoidCallback? onLoaded;

  const DefaultPageSettings({super.key, this.onLoaded});

  @override
  State<DefaultPageSettings> createState() => _DefaultPageSettingsState();
}

class _DefaultPageSettingsState extends State<DefaultPageSettings> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

  String _selectedRoute = AppRoutes.defaultRouteName;
  bool _isSaving = false;

  /// The sections the user can land on. Derived from the navigation bar so a
  /// page added there becomes selectable without touching this file.
  static List<NavItem> get _selectablePages => NavigationItems.topNavItems.where((item) => item.route != null).toList();

  @override
  void initState() {
    super.initState();
    _loadSelectedPage();
  }

  Future<void> _loadSelectedPage() async {
    final setting = await _mediator.send<GetSettingQuery, GetSettingQueryResponse?>(
      GetSettingQuery(key: SettingKeys.defaultPage),
    );
    if (!mounted) return;

    final storedRoute = setting?.value;
    setState(() {
      // A page removed since the setting was saved would leave the tile blank,
      // so an unknown route falls back to the same page the app opens on.
      _selectedRoute =
          _selectablePages.any((page) => page.route == storedRoute) ? storedRoute! : AppRoutes.defaultRouteName;
    });
    widget.onLoaded?.call();
  }

  Future<void> _saveSelectedPage(String route) async {
    if (_isSaving) return;
    _isSaving = true;

    await AsyncErrorHandler.execute(
      context: context,
      errorMessage: _translationService.translate(SettingsTranslationKeys.defaultPageSaveError),
      operation: () => _mediator.send<SaveSettingCommand, SaveSettingCommandResponse>(
        SaveSettingCommand(
          key: SettingKeys.defaultPage,
          value: route,
          valueType: SettingValueType.string,
        ),
      ),
      onSuccess: (_) {
        if (!mounted) return;
        setState(() => _selectedRoute = route);
      },
    );

    _isSaving = false;
  }

  Future<void> _showPageSelectionDialog() async {
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      size: DialogSize.min,
      child: _DefaultPageSelectDialog(
        pages: _selectablePages,
        selectedRoute: _selectedRoute,
        translationService: _translationService,
        onSelected: (route) {
          Navigator.of(context).pop();
          _saveSelectedPage(route);
        },
      ),
    );
  }

  NavItem get _selectedPage => _selectablePages.firstWhere(
        (page) => page.route == _selectedRoute,
        orElse: () => _selectablePages.first,
      );

  @override
  Widget build(BuildContext context) {
    return SettingsMenuTile(
      icon: Icons.home_outlined,
      title: _translationService.translate(SettingsTranslationKeys.defaultPageTitle),
      subtitle: _translationService.translate(_selectedPage.titleKey),
      onTap: _showPageSelectionDialog,
      isActive: true,
    );
  }
}

class _DefaultPageSelectDialog extends StatelessWidget {
  final List<NavItem> pages;
  final String selectedRoute;
  final ITranslationService translationService;
  final ValueChanged<String> onSelected;

  const _DefaultPageSelectDialog({
    required this.pages,
    required this.selectedRoute,
    required this.translationService,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(translationService.translate(SettingsTranslationKeys.defaultPageDialogTitle)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.sizeSmall),
        children: pages.map((page) {
          final isSelected = page.route == selectedRoute;
          return ListTile(
            leading: Icon(page.icon),
            title: Text(translationService.translate(page.titleKey)),
            trailing: isSelected ? const Icon(Icons.check) : null,
            selected: isSelected,
            onTap: () => onSelected(page.route!),
          );
        }).toList(),
      ),
    );
  }
}
