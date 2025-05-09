import 'package:flutter/material.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/presentation/shared/components/app_logo.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/shared/constants/navigation_items.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
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
  final bool respectBottomInset; // Control whether to respect bottom system insets

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
    this.respectBottomInset = true, // Default to true to respect bottom insets
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

  // Initialize the current page index based on the current route
  void _initializeCurrentPageIndex() {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute != null) {
      final index = NavigationItems.topNavItems.indexWhere((item) => item.route == currentRoute);
      if (index != -1) {
        setState(() {});
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    if (widget.fullScreen) {
      return widget.builder(context);
    }

    // Get the bottom inset (navigation bar height)
    final bottomInset = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: widget.appBarLeading ??
            (widget.showBackButton
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, size: AppTheme.fontSizeXLarge),
                    padding: const EdgeInsets.all(AppTheme.sizeMedium),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null), // Remove the hamburger menu in app bar since we have it in bottom nav
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
                  const SizedBox(width: AppTheme.sizeXSmall),
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
      body: Row(
        children: [
          if (AppThemeHelper.isScreenGreaterThan(context, AppTheme.screenMedium) &&
              !widget.hideSidebar &&
              !widget.showBackButton)
            _buildDrawer(NavigationItems.topNavItems, NavigationItems.bottomNavItems),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: AppTheme.sizeSmall,
                top: AppTheme.sizeSmall,
                right: AppTheme.sizeSmall,
                // Add bottom padding to account for system navigation bar
                // If we're showing the bottom nav bar, we need less extra padding
                bottom: widget.respectBottomInset
                    ? AppTheme.sizeSmall + (bottomInset > 0 && !_shouldShowBottomNavBar() ? bottomInset : 0)
                    : AppTheme.sizeSmall,
              ),
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
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeXSmall),
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
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeXSmall),
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

  bool _shouldShowBottomNavBar() {
    // Show bottom nav bar on mobile devices (width <= 600px)
    // Don't show if we're on a details page with back button or if sidebar is hidden
    return AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium) &&
        !widget.showBackButton &&
        !widget.hideSidebar;
  }

  Widget _buildBottomNavigationBar() {
    final translationService = container.resolve<ITranslationService>();
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate the maximum number of visible items using the helper method
    final int maxVisibleItems = _calculateMaxVisibleItems(screenWidth);

    // Get the main navigation items to display
    final List<NavItem> mainNavItems = NavigationItems.topNavItems.take(maxVisibleItems).toList();

    // We always need a "More" button if there are items that don't fit
    final bool needsMoreButton =
        NavigationItems.topNavItems.length > maxVisibleItems || NavigationItems.bottomNavItems.isNotEmpty;

    // Create the "More" menu item
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Theme.of(context).cardColor,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bottom sheet handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const AppLogo(width: 24, height: 24),
                  const SizedBox(width: 12),
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
              const SizedBox(height: AppTheme.sizeXSmall),
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
  ///
  /// @param context The build context
  /// @param item The navigation item to build
  /// @param currentRoute The current route to check if this item is active
  /// @returns A ListTile representing the menu item
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
  ///
  /// @param screenWidth The width of the screen in logical pixels
  /// @returns The number of items that can fit in the navigation bar
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
  ///
  /// @param visibleItems The list of navigation items visible in the bottom bar
  /// @returns The index to highlight in the bottom navigation bar
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
