import 'package:flutter/material.dart';
import 'package:acore/acore.dart' show PlatformUtils;
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/presentation/ui/shared/components/app_logo.dart';
import 'package:whph/presentation/ui/shared/constants/app_routes.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/ui/shared/constants/navigation_items.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/tour_navigation_service.dart';

/// Configuration options for route rendering
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

/// A responsive scaffold layout that adapts to different screen sizes
/// providing appropriate navigation patterns (drawer, bottom nav) for each.
class ResponsiveScaffoldLayout extends StatefulWidget {
  final String? title;
  final Widget? appBarLeading;
  final Widget? appBarTitle;
  final List<Widget>? appBarActions;
  final Widget Function(BuildContext) builder;
  final bool showLogo;
  final bool fullScreen;
  final bool hideSidebar;

  /// Controls visibility of the back button in the app bar
  final bool showBackButton;

  /// Controls whether to respect bottom system insets for proper padding
  final bool respectBottomInset;

  /// Floating action button widget (only visible on mobile devices)
  final Widget? floatingActionButton;

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
    this.showBackButton = false,
    this.respectBottomInset = true,
    this.floatingActionButton,
  });

  @override
  State<ResponsiveScaffoldLayout> createState() => _ResponsiveScaffoldLayoutState();
}

class _ResponsiveScaffoldLayoutState extends State<ResponsiveScaffoldLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _themeService = container.resolve<IThemeService>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeCurrentPageIndex();
  }

  void _initializeCurrentPageIndex() {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute != null) {
      final index = NavigationItems.topNavItems.indexWhere((item) => item.route == currentRoute);
      if (index != -1) {
        setState(() {});
      }
    }
  }

  /// Closes all open dialogs before navigation
  void _closeAllDialogs() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _navigateTo(String routeName) {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }

    Future.microtask(() {
      if (mounted) {
        _closeAllDialogs();
        Navigator.of(context).pushReplacementNamed(routeName);
      }
    });
  }

  void _onClickNavItem(NavItem navItem) {
    String? currentRoute = ModalRoute.of(context)?.settings.name;

    const String initialRoute = "/";
    if (currentRoute == initialRoute) {
      currentRoute = AppRoutes.defaultRouteName;
    }

    if (navItem.route != null && navItem.route == currentRoute) {
      if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
        Navigator.of(context).pop();
      }
      return;
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxVisibleItems = _calculateMaxVisibleItems(screenWidth);

    final bool isFromMoreMenu = NavigationItems.topNavItems.indexOf(navItem) >= maxVisibleItems ||
        NavigationItems.bottomNavItems.contains(navItem);

    if (isFromMoreMenu) {
      setState(() {});
    }

    if (navItem.route != null) {
      _navigateTo(navItem.route!);
    } else {
      navItem.onTap?.call(context);
    }
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fullScreen) {
      return widget.builder(context);
    }

    final double sidePadding = AppThemeHelper.isSmallScreen(context) ? AppTheme.sizeSmall : AppTheme.sizeLarge;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: !TourNavigationService.isMultiPageTourActive,
        leading: TourNavigationService.isMultiPageTourActive
            ? null
            : (widget.appBarLeading ??
                (widget.showBackButton
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back, size: AppTheme.fontSizeXLarge),
                        padding: const EdgeInsets.all(AppTheme.sizeMedium),
                        onPressed: _goBack,
                      )
                    : null)),
        title: widget.appBarTitle ??
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showLogo) ...[
                  SizedBox(width: sidePadding),
                  const AppLogo(width: 32, height: 32),
                  const SizedBox(width: AppTheme.size2XSmall),
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
      bottomNavigationBar: _shouldShowBottomNavBar() ? _buildBottomNavigationBar() : null,
      floatingActionButton: _shouldShowFloatingActionButton() ? widget.floatingActionButton : null,
      body: Row(
        children: [
          if (AppThemeHelper.isScreenGreaterThan(context, AppTheme.screenMedium) &&
              !widget.hideSidebar &&
              !widget.showBackButton)
            _buildDrawer(NavigationItems.topNavItems, NavigationItems.bottomNavItems),
          Expanded(
            child: Padding(
              padding: context.pageBodyPadding,
              child: widget.builder(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the side drawer for navigation on larger screens
  Widget _buildDrawer(List<NavItem> topNavItems, List<NavItem>? bottomNavItems) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth <= 600;
    final drawerWidth = isMobile ? screenWidth * 0.65 : 180.0;
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
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeLarge, vertical: AppTheme.sizeMedium),
                    child: Row(
                      children: [
                        const AppLogo(width: 32, height: 32),
                        const SizedBox(width: AppTheme.sizeSmall),
                        Text(AppInfo.shortName),
                      ],
                    )),
              ),
            const SizedBox(height: AppTheme.sizeSmall),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.sizeSmall),
                children: [
                  ...topNavItems.map((navItem) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.size2XSmall),
                        child: _buildNavItem(navItem),
                      )),
                ],
              ),
            ),
            if (bottomNavItems != null) ...[
              const SizedBox(height: AppTheme.sizeSmall),
              const Divider(height: 1),
              const SizedBox(height: AppTheme.sizeSmall),
              ...bottomNavItems.map((navItem) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.size2XSmall),
                    child: _buildNavItem(navItem),
                  )),
              const SizedBox(height: AppTheme.sizeLarge),
            ],
          ],
        ),
      ),
    );
  }

  ListTile _buildNavItem(NavItem navItem) {
    final translationService = container.resolve<ITranslationService>();
    String? currentRoute = ModalRoute.of(context)?.settings.name;

    final List<String> navRoutes = [
      ...NavigationItems.topNavItems.map((e) => e.route).whereType<String>(),
      ...NavigationItems.bottomNavItems.map((e) => e.route).whereType<String>()
    ];

    if (currentRoute == null || !navRoutes.contains(currentRoute)) {
      currentRoute = navRoutes.isNotEmpty ? navRoutes.first : currentRoute;
    }
    final bool isActive = navItem.route == currentRoute;

    final dm = _themeService.densityMultiplier;

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.sizeLarge)),
      selected: isActive,
      selectedTileColor: _themeService.primaryColor.withValues(alpha: 0.1),
      dense: true,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
      contentPadding: EdgeInsets.symmetric(horizontal: AppTheme.sizeLarge * dm),
      leading: navItem.icon != null
          ? Icon(navItem.icon, size: AppTheme.fontSizeXLarge * dm, color: isActive ? _themeService.primaryColor : null)
          : null,
      title: navItem.widget ??
          Text(
            translationService.translate(navItem.titleKey),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: AppTheme.fontSizeMedium * dm,
                  color: isActive ? _themeService.primaryColor : null,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
          ),
      onTap: () => _onClickNavItem(navItem),
    );
  }

  bool _shouldShowBottomNavBar() {
    return AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium) &&
        !widget.showBackButton &&
        !widget.hideSidebar;
  }

  bool _shouldShowFloatingActionButton() {
    return widget.floatingActionButton != null && (PlatformUtils.isMobile);
  }

  /// Builds the bottom navigation bar for smaller screens
  Widget _buildBottomNavigationBar() {
    final translationService = container.resolve<ITranslationService>();
    final screenWidth = MediaQuery.sizeOf(context).width;

    final int maxVisibleItems = _calculateMaxVisibleItems(screenWidth);
    final List<NavItem> mainNavItems = NavigationItems.topNavItems.take(maxVisibleItems).toList();
    final bool needsMoreButton =
        NavigationItems.topNavItems.length > maxVisibleItems || NavigationItems.bottomNavItems.isNotEmpty;

    final NavItem moreNavItem = NavItem(
      titleKey: SharedTranslationKeys.navMore,
      icon: Icons.more_horiz,
      onTap: _showMoreBottomSheet,
    );

    return BottomNavigationBar(
      currentIndex: _getCurrentBottomNavIndex(mainNavItems),
      onTap: (index) {
        if (needsMoreButton && index == mainNavItems.length) {
          _showMoreBottomSheet(context);
        } else {
          setState(() {});
          _onClickNavItem(mainNavItems[index]);
        }
      },
      items: [
        ...mainNavItems.map(
          (navItem) => BottomNavigationBarItem(
            icon: Icon(navItem.icon),
            label: translationService.translate(navItem.titleKey),
          ),
        ),
        if (needsMoreButton)
          BottomNavigationBarItem(
            icon: Icon(moreNavItem.icon),
            label: translationService.translate(moreNavItem.titleKey),
          ),
      ],
    );
  }

  /// Shows a bottom sheet with additional navigation options that don't fit in the bottom nav
  void _showMoreBottomSheet(BuildContext context) {
    container.resolve<ITranslationService>();

    final screenWidth = MediaQuery.sizeOf(context).width;
    final int maxVisibleItems = _calculateMaxVisibleItems(screenWidth);

    NavigationItems.topNavItems.take(maxVisibleItems).toList();
    final List<NavItem> remainingTopItems = NavigationItems.topNavItems.length > maxVisibleItems
        ? NavigationItems.topNavItems.sublist(maxVisibleItems)
        : [];

    final List<NavItem> moreItems = [...remainingTopItems];
    final List<NavItem> bottomItems = [...NavigationItems.bottomNavItems];

    final currentRoute = ModalRoute.of(context)?.settings.name;

    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: AppTheme.surface1,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const AppLogo(width: 24, height: 24),
                  const SizedBox(width: AppTheme.sizeMedium),
                  Text(
                    AppInfo.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            const Divider(),
            const SizedBox(height: AppTheme.sizeSmall),
            ...moreItems.map((item) => _buildMoreMenuItem(context, item, currentRoute)),
            if (bottomItems.isNotEmpty) ...[
              const SizedBox(height: AppTheme.sizeSmall),
              const Divider(),
              const SizedBox(height: AppTheme.size2XSmall),
            ],
            ...bottomItems.map((item) => _buildMoreMenuItem(context, item, currentRoute)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreMenuItem(BuildContext context, NavItem item, String? currentRoute) {
    final translationService = container.resolve<ITranslationService>();
    final bool isActive = item.route != null && item.route == currentRoute;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.sizeLarge)),
        leading: item.icon != null
            ? Icon(item.icon, color: isActive ? _themeService.primaryColor : Theme.of(context).iconTheme.color)
            : null,
        title: Text(
          translationService.translate(item.titleKey),
          style: TextStyle(
            color: isActive ? _themeService.primaryColor : Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        tileColor: isActive ? _themeService.primaryColor.withValues(alpha: 0.1) : null,
        onTap: () {
          Navigator.pop(context);
          _onClickNavItem(item);
        },
      ),
    );
  }

  /// Calculates the maximum number of navigation items that can fit in the bottom bar
  /// based on the available screen width.
  int _calculateMaxVisibleItems(double screenWidth) {
    const double minItemWidth = 80.0;

    int maxItems = ((screenWidth - 16) / minItemWidth).floor();

    bool needsMoreButton = NavigationItems.topNavItems.length > maxItems;

    maxItems = maxItems.clamp(2, 5);

    return needsMoreButton ? maxItems - 1 : maxItems;
  }

  int _getCurrentBottomNavIndex(List<NavItem> visibleItems) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == null) return 0;

    for (int i = 0; i < visibleItems.length; i++) {
      if (visibleItems[i].route == currentRoute) {
        return i;
      }
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxVisibleItems = _calculateMaxVisibleItems(screenWidth);

    final List<NavItem> remainingTopItems = NavigationItems.topNavItems.length > maxVisibleItems
        ? NavigationItems.topNavItems.sublist(maxVisibleItems)
        : [];
    final moreItems = [...remainingTopItems, ...NavigationItems.bottomNavItems];

    final bool isMoreMenuItem = moreItems.any((item) => item.route != null && item.route == currentRoute);

    if (isMoreMenuItem) {
      return visibleItems.length;
    }

    return 0;
  }
}
