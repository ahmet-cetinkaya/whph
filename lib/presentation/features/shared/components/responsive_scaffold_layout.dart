import 'package:flutter/material.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/shared/utils/app_theme_helper.dart';

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
  final Map<String, WidgetBuilder> routes;
  final WidgetBuilder defaultRoute;

  const ResponsiveScaffoldLayout({
    super.key,
    required this.topNavItems,
    this.bottomNavItems,
    required this.routes,
    required this.appBarTitle,
    this.appBarActions,
    required this.defaultRoute,
  });

  @override
  State<ResponsiveScaffoldLayout> createState() => _ResponsiveScaffoldLayoutState();
}

class _ResponsiveScaffoldLayoutState extends State<ResponsiveScaffoldLayout> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  void _navigateTo(String routeName) {
    Navigator.of(_navigatorKey.currentContext!).pushNamedAndRemoveUntil(
      routeName,
      ModalRoute.withName('/'),
    );
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _onClickNavItem(NavItem navItem) {
    if (navItem.route != null) {
      _navigateTo(navItem.route!);
    }
    navItem.onTap?.call(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: widget.appBarTitle,
        leading: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium)
            ? Builder(
                builder: (BuildContext context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
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
            child: Navigator(
              key: _navigatorKey,
              onGenerateRoute: (routeSettings) {
                return _buildPageRoute(routeSettings);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(List<NavItem> topNavItems, List<NavItem>? bottomNavItems) {
    final isMobile = MediaQuery.of(context).size.width <= 600;
    final drawerWidth = isMobile ? MediaQuery.of(context).size.width * 0.75 : 200.0;
    return SizedBox(
      width: drawerWidth,
      child: Drawer(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: isMobile ? Radius.circular(16.0) : Radius.zero,
            bottomRight: Radius.circular(16.0),
          ),
        ),
        child: Column(
          children: [
            if (isMobile)
              SizedBox(
                height: 85,
                child: DrawerHeader(
                  child: widget.appBarTitle,
                ),
              ),
            Expanded(
              child: ListView(
                children: [
                  ...topNavItems.map((navItem) => _buildNavItem(navItem)),
                ],
              ),
            ),
            Divider(),
            if (bottomNavItems != null) ...bottomNavItems.map((navItem) => _buildNavItem(navItem)),
          ],
        ),
      ),
    );
  }

  ListTile _buildNavItem(NavItem navItem) {
    return ListTile(
      leading: navItem.icon != null ? Icon(navItem.icon) : null,
      title: navItem.widget ?? Text(navItem.title, style: Theme.of(context).textTheme.labelLarge),
      onTap: () => _onClickNavItem(navItem),
    );
  }

  PageRoute _buildPageRoute(RouteSettings settings) {
    final pageBuilder = widget.routes[settings.name];
    if (pageBuilder != null) {
      return PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => pageBuilder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return child;
        },
      );
    } else {
      return PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => widget.defaultRoute(context),
      );
    }
  }
}
