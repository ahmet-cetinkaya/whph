import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whph/src/core/domain/shared/constants/app_info.dart';
import 'package:whph/src/presentation/ui/shared/components/app_logo.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_routes.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/src/presentation/ui/shared/constants/navigation_items.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Configuration options for route rendering
class RouteOptions {
  final WidgetBuilder builder;
  final bool fullScreen;

  RouteOptions({required this.builder, this.fullScreen = false});
}

/// Represents a navigation item with its properties
/// Used for both sidebar and bottom navigation
class NavItem {
  /// Translation key for the item's display title
  final String titleKey;

  /// Icon to display next to the item (optional)
  final IconData? icon;

  /// Custom widget to replace the default text (optional)
  final Widget? widget;

  /// Route name to navigate to when clicked
  final String? route;

  /// Custom action to perform instead of navigation (optional)
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
///
/// On large screens (tablets, desktops), it shows a side drawer.
/// On small screens (phones), it shows a bottom navigation bar.
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeCurrentPageIndex();
  }

  /// Initialize the current page index based on the current route
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

  /// Navigates to the given route with proper transition
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

  /// Handles navigation item clicks with proper state updates
  void _onClickNavItem(NavItem navItem) {
    String? currentRoute = ModalRoute.of(context)?.settings.name;

    const String initialRoute = "/";
    if (currentRoute == initialRoute) {
      currentRoute = AppRoutes.defaultRouteName;
    }

    if (navItem.route != null && navItem.route == currentRoute) {
      // Close drawer if open and return early if we're already on this page
      if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
        Navigator.of(context).pop();
      }
      return;
    }

    // Check if this is a navigation item from the "More" menu that should be tracked
    final screenWidth = MediaQuery.of(context).size.width;
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

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: widget.appBarLeading ??
            (widget.showBackButton
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, size: AppTheme.fontSizeXLarge),
                    padding: const EdgeInsets.all(AppTheme.sizeMedium),
                    onPressed: _goBack,
                  )
                : null),
        title: widget.appBarTitle ??
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showLogo) ...[
                  // Add left spacing for mobile view
                  if (AppThemeHelper.isSmallScreen(context)) const SizedBox(width: AppTheme.sizeSmall),
                  // Existing spacing for larger screens
                  if (!AppThemeHelper.isSmallScreen(context)) const SizedBox(width: AppTheme.sizeLarge),
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
      // Add bottom navigation bar for mobile devices
      bottomNavigationBar: _shouldShowBottomNavBar() ? _buildBottomNavigationBar() : null,
      // Add floating action button only on mobile devices
      floatingActionButton: _shouldShowFloatingActionButton() ? widget.floatingActionButton : null,
      body: Row(
        children: [
          if (AppThemeHelper.isScreenGreaterThan(context, AppTheme.screenMedium) &&
              !widget.hideSidebar &&
              !widget.showBackButton)
            _buildDrawer(NavigationItems.topNavItems, NavigationItems.bottomNavItems),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: AppTheme.sizeXSmall,
                right: AppTheme.sizeXSmall,
                top: AppTheme.size3XSmall,
                bottom: 0,
              ),
              child: widget.builder(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the side drawer for navigation on larger screens
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

  /// Builds a navigation item for the side drawer
  ListTile _buildNavItem(NavItem navItem) {
    final translationService = container.resolve<ITranslationService>();
    String? currentRoute = ModalRoute.of(context)?.settings.name;

    // Collect all available routes from both top and bottom navigation
    final List<String> navRoutes = [
      ...NavigationItems.topNavItems.map((e) => e.route).whereType<String>(),
      ...NavigationItems.bottomNavItems.map((e) => e.route).whereType<String>()
    ];

    if (currentRoute == null || !navRoutes.contains(currentRoute)) {
      currentRoute = navRoutes.isNotEmpty ? navRoutes.first : currentRoute;
    }
    final bool isActive = navItem.route == currentRoute;

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.sizeLarge)),
      selected: isActive,
      selectedTileColor: AppTheme.primaryColor.withValues(alpha: 0.1),
      dense: true,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeLarge),
      leading: navItem.icon != null
          ? Icon(navItem.icon, size: AppTheme.fontSizeXLarge, color: isActive ? AppTheme.primaryColor : null)
          : null,
      title: navItem.widget ??
          Text(
            translationService.translate(navItem.titleKey),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: AppTheme.fontSizeMedium,
                  color: isActive ? AppTheme.primaryColor : null,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
          ),
      onTap: () => _onClickNavItem(navItem),
    );
  }

  /// Determines whether to show the bottom navigation bar based on screen size and layout options
  bool _shouldShowBottomNavBar() {
    return AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium) &&
        !widget.showBackButton &&
        !widget.hideSidebar;
  }

  /// Determines whether to show the floating action button based on screen size and widget availability
  bool _shouldShowFloatingActionButton() {
    return widget.floatingActionButton != null && (Platform.isAndroid || Platform.isIOS);
  }

  /// Builds the bottom navigation bar for smaller screens
  Widget _buildBottomNavigationBar() {
    final translationService = container.resolve<ITranslationService>();
    final screenWidth = MediaQuery.of(context).size.width;

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
          // Handle "More" button tap
          _showMoreBottomSheet(context);
        } else {
          setState(() {});
          _onClickNavItem(mainNavItems[index]);
        }
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppTheme.primaryColor,
      unselectedItemColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      backgroundColor: Theme.of(context).cardColor,
      elevation: 8,
      items: [
        ...mainNavItems.map(
          (navItem) => BottomNavigationBarItem(
            icon: Icon(navItem.icon),
            label: translationService.translate(navItem.titleKey),
          ),
        ),
        // Add the "More" button if needed
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

    // Calculate how many items can fit in the bottom navigation
    final screenWidth = MediaQuery.of(context).size.width;
    final int maxVisibleItems = _calculateMaxVisibleItems(screenWidth);

    // Get items that don't fit in the bottom navigation
    NavigationItems.topNavItems.take(maxVisibleItems).toList();
    final List<NavItem> remainingTopItems = NavigationItems.topNavItems.length > maxVisibleItems
        ? NavigationItems.topNavItems.sublist(maxVisibleItems)
        : [];

    // Add all bottom nav items
    final List<NavItem> moreItems = [...remainingTopItems];
    final List<NavItem> bottomItems = [...NavigationItems.bottomNavItems];

    // Get current route to highlight the active item in the More menu
    final currentRoute = ModalRoute.of(context)?.settings.name;

    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      isDismissible: true,
      enableDrag: true,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
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
            // Remaining top navigation items
            ...moreItems.map((item) => _buildMoreMenuItem(context, item, currentRoute)),

            // Add divider before bottom navigation items if there are any
            if (bottomItems.isNotEmpty) ...[
              const SizedBox(height: AppTheme.sizeSmall),
              const Divider(),
              const SizedBox(height: AppTheme.size2XSmall),
            ],

            // Bottom navigation items
            ...bottomItems.map((item) => _buildMoreMenuItem(context, item, currentRoute)),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Builds a menu item for the More bottom sheet
  Widget _buildMoreMenuItem(BuildContext context, NavItem item, String? currentRoute) {
    final translationService = container.resolve<ITranslationService>();
    // Handle both direct route comparison and ensuring bottom nav items can be active
    final bool isActive = item.route != null && item.route == currentRoute;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.sizeLarge)),
        leading: item.icon != null
            ? Icon(item.icon, color: isActive ? AppTheme.primaryColor : Theme.of(context).iconTheme.color)
            : null,
        title: Text(
          translationService.translate(item.titleKey),
          style: TextStyle(
            color: isActive ? AppTheme.primaryColor : Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        tileColor: isActive ? AppTheme.primaryColor.withValues(alpha: 0.1) : null,
        onTap: () {
          Navigator.pop(context); // Close bottom sheet
          _onClickNavItem(item);
        },
      ),
    );
  }

  /// Calculates the maximum number of navigation items that can fit in the bottom bar
  /// based on the available screen width.
  int _calculateMaxVisibleItems(double screenWidth) {
    const double minItemWidth = 80.0;

    // Calculate how many items we can fit
    int maxItems = ((screenWidth - 16) / minItemWidth).floor();

    // If we have more items than can fit, we need a "More" button
    bool needsMoreButton = NavigationItems.topNavItems.length > maxItems;

    // Limit to reasonable range and account for "More" button if needed
    maxItems = maxItems.clamp(2, 5);

    // If we need a "More" button, reserve space for it
    return needsMoreButton ? maxItems - 1 : maxItems;
  }

  /// Gets the correct index for the bottom navigation bar based on the current page
  int _getCurrentBottomNavIndex(List<NavItem> visibleItems) {
    // Get the current route
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == null) return 0;

    // Find the index of the current route in the visible items
    for (int i = 0; i < visibleItems.length; i++) {
      if (visibleItems[i].route == currentRoute) {
        return i;
      }
    }

    // If route not found in visible items, check if it's a "More" menu item
    final screenWidth = MediaQuery.of(context).size.width;
    final maxVisibleItems = _calculateMaxVisibleItems(screenWidth);

    // Check if current route is in items that would be in the "More" menu
    final List<NavItem> remainingTopItems = NavigationItems.topNavItems.length > maxVisibleItems
        ? NavigationItems.topNavItems.sublist(maxVisibleItems)
        : [];
    final moreItems = [...remainingTopItems, ...NavigationItems.bottomNavItems];

    // Check if the current route matches any item in the More menu
    final bool isMoreMenuItem = moreItems.any((item) => item.route != null && item.route == currentRoute);

    if (isMoreMenuItem) {
      // If it's a "More" menu item, return the index of the "More" button
      return visibleItems.length;
    }

    // If not found anywhere, return 0 as default
    return 0;
  }
}
