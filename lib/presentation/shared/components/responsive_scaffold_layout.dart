import 'package:flutter/material.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/presentation/shared/components/app_logo.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/shared/constants/navigation_items.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

class RouteOptions {
  final WidgetBuilder builder;
  final bool fullScreen;

  RouteOptions({required this.builder, this.fullScreen = false});
}

class NavItem {
  final String titleKey;
  final IconData? icon;
  final Widget? widget;
  final String? route;
  final Function(BuildContext context)? onTap;

  NavItem({
    required this.titleKey,
    this.icon,
    this.widget,
    this.route,
    this.onTap,
  });
}

class ResponsiveScaffoldLayout extends StatefulWidget {
  final String? title;
  final Widget? appBarLeading;
  final Widget? appBarTitle;
  final List<Widget>? appBarActions;
  final Widget Function(BuildContext) builder;
  final bool showLogo;
  final bool fullScreen;
  final bool hideSidebar;
  final bool showBackButton; // New property to control back button visibility

  const ResponsiveScaffoldLayout({
    super.key,
    this.title,
    required this.builder,
    this.appBarLeading,
    this.appBarTitle,
    this.appBarActions,
    this.showLogo = true,
    this.fullScreen = false,
    this.hideSidebar = false,
    this.showBackButton = false, // Default to false for backward compatibility
  });

  @override
  State<ResponsiveScaffoldLayout> createState() => _ResponsiveScaffoldLayoutState();
}

class _ResponsiveScaffoldLayoutState extends State<ResponsiveScaffoldLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _closeAllDialogs() {
    // Close any open dialogs/modals before navigation
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _navigateTo(String routeName) {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }

    Future.microtask(() {
      if (mounted) {
        _closeAllDialogs();
        Navigator.of(context).pushReplacementNamed(
          routeName,
          arguments: {
            'useFadeTransition': true,
          },
        );
      }
    });
  }

  void _onClickNavItem(NavItem navItem) {
    if (navItem.route != null) {
      _navigateTo(navItem.route!);
    } else {
      navItem.onTap?.call(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fullScreen) {
      return widget.builder(context);
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: widget.appBarLeading ??
            (widget.showBackButton
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, size: AppTheme.fontSizeXLarge),
                    padding: const EdgeInsets.all(12),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : (AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium)
                    ? Builder(
                        builder: (BuildContext context) => IconButton(
                          icon: const Icon(Icons.menu, size: AppTheme.fontSizeXLarge),
                          padding: const EdgeInsets.all(12),
                          onPressed: () {
                            _scaffoldKey.currentState?.openDrawer();
                          },
                        ),
                      )
                    : null)),
        title: widget.appBarTitle ??
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showLogo) ...[
                  if (!AppThemeHelper.isSmallScreen(context)) const SizedBox(width: 16),
                  const AppLogo(width: 32, height: 32),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    widget.title ?? AppInfo.shortName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
        titleSpacing: 0,
        actions: widget.appBarActions,
      ),
      drawer: AppThemeHelper.isScreenGreaterThan(context, AppTheme.screenMedium) ||
              widget.hideSidebar ||
              widget.showBackButton
          ? null
          : _buildDrawer(NavigationItems.topNavItems, NavigationItems.bottomNavItems),
      body: Row(
        children: [
          if (AppThemeHelper.isScreenGreaterThan(context, AppTheme.screenMedium) &&
              !widget.hideSidebar &&
              !widget.showBackButton)
            _buildDrawer(NavigationItems.topNavItems, NavigationItems.bottomNavItems),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.sizeSmall),
              child: widget.builder(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(List<NavItem> topNavItems, List<NavItem>? bottomNavItems) {
    final isMobile = MediaQuery.of(context).size.width <= 600;
    final drawerWidth = isMobile ? MediaQuery.of(context).size.width * 0.65 : 180.0;
    return SizedBox(
      width: drawerWidth,
      child: Drawer(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: isMobile ? const Radius.circular(12.0) : Radius.zero,
            bottomRight: const Radius.circular(12.0),
          ),
        ),
        child: Column(
          children: [
            if (isMobile)
              SizedBox(
                height: 80,
                child: DrawerHeader(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      children: [
                        const AppLogo(width: 32, height: 32),
                        const SizedBox(width: 8),
                        Text(AppInfo.shortName),
                      ],
                    )),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ...topNavItems.map((navItem) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _buildNavItem(navItem),
                      )),
                ],
              ),
            ),
            if (bottomNavItems != null) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ...bottomNavItems.map((navItem) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _buildNavItem(navItem),
                  )),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  ListTile _buildNavItem(NavItem navItem) {
    final translationService = container.resolve<ITranslationService>();

    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: navItem.icon != null ? Icon(navItem.icon, size: AppTheme.fontSizeXLarge) : null,
      title: navItem.widget ??
          Text(
            translationService.translate(navItem.titleKey),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: AppTheme.fontSizeMedium,
                ),
          ),
      onTap: () => _onClickNavItem(navItem),
    );
  }
}
