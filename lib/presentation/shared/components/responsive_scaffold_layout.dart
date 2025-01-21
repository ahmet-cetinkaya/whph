import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/utils/app_theme_helper.dart';

class RouteOptions {
  final WidgetBuilder builder;
  final bool fullScreen;

  RouteOptions({required this.builder, this.fullScreen = false});
}

class NavItem {
  final String title;
  final IconData? icon;
  final Widget? widget;
  final String? route;
  final Function(BuildContext context)? onTap;

  NavItem({required this.title, this.icon, this.widget, this.route, this.onTap});
}

class ResponsiveScaffoldLayout extends StatefulWidget {
  final Widget appBarTitle;
  final List<Widget>? appBarActions;
  final List<NavItem> topNavItems;
  final List<NavItem>? bottomNavItems;
  final Map<String, RouteOptions> routes;
  final WidgetBuilder defaultRoute;
  final bool fullScreen;

  const ResponsiveScaffoldLayout({
    super.key,
    required this.topNavItems,
    this.bottomNavItems,
    required this.routes,
    required this.appBarTitle,
    this.appBarActions,
    required this.defaultRoute,
    this.fullScreen = false,
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
          arguments: {'noAnimation': true},
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
      return widget.defaultRoute(context);
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: widget.appBarTitle,
        titleSpacing: 0,
        leading: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium)
            ? Builder(
                builder: (BuildContext context) => IconButton(
                  icon: const Icon(Icons.menu, size: 22),
                  padding: const EdgeInsets.all(12),
                  onPressed: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
              )
            : null,
        actions: widget.appBarActions,
      ),
      drawer: AppThemeHelper.isScreenGreaterThan(context, AppTheme.screenMedium)
          ? null
          : _buildDrawer(widget.topNavItems, widget.bottomNavItems),
      body: Row(
        children: [
          if (AppThemeHelper.isScreenGreaterThan(context, AppTheme.screenMedium))
            _buildDrawer(widget.topNavItems, widget.bottomNavItems),
          Expanded(
            child: widget.defaultRoute(context),
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
                height: 80, // slightly taller header
                child: DrawerHeader(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: widget.appBarTitle,
                ),
              ),
            const SizedBox(height: 8), // add spacing after header
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8), // add vertical padding
                children: [
                  ...topNavItems.map((navItem) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4), // add horizontal padding
                        child: _buildNavItem(navItem),
                      )),
                ],
              ),
            ),
            if (bottomNavItems != null) ...[
              const SizedBox(height: 8), // add spacing before divider
              const Divider(height: 1),
              const SizedBox(height: 8), // add spacing after divider
              ...bottomNavItems.map((navItem) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4), // add horizontal padding
                    child: _buildNavItem(navItem),
                  )),
              const SizedBox(height: 16), // add bottom padding
            ],
          ],
        ),
      ),
    );
  }

  ListTile _buildNavItem(NavItem navItem) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -1), // slightly less compact
      contentPadding: const EdgeInsets.symmetric(horizontal: 16), // adjust content padding
      leading: navItem.icon != null
          ? Icon(navItem.icon, size: 22) // slightly larger icon
          : null,
      title: navItem.widget ??
          Text(navItem.title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 14, // slightly larger font
                  )),
      onTap: () => _onClickNavItem(navItem),
    );
  }
}
