import 'package:flutter/material.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/shared/utils/app_theme_helper.dart';

class NavItem {
  final String title;
  final String route;

  NavItem(this.title, this.route);
}

class ResponsiveScaffoldLayout extends StatefulWidget {
  final Widget appBarTitle;
  final List<Widget>? appBarActions;
  final List<NavItem> navItems;
  final Map<String, WidgetBuilder> routes;

  const ResponsiveScaffoldLayout(
      {super.key, required this.navItems, required this.routes, required this.appBarTitle, this.appBarActions});

  @override
  State<ResponsiveScaffoldLayout> createState() => _ResponsiveScaffoldLayoutState();
}

class _ResponsiveScaffoldLayoutState extends State<ResponsiveScaffoldLayout> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

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
      drawer: AppThemeHelper.isScreenGreaterThan(context, AppTheme.screenMedium) ? null : _buildDrawer(widget.navItems),
      body: Row(
        children: [
          if (AppThemeHelper.isScreenGreaterThan(context, AppTheme.screenMedium)) _buildDrawer(widget.navItems),
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

  Widget _buildDrawer(List<NavItem> navItems) {
    final isMobile = MediaQuery.of(context).size.width <= 600;
    return Drawer(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: isMobile ? Radius.circular(16.0) : Radius.zero,
          bottomRight: Radius.circular(16.0),
        ),
      ),
      child: ListView(
        children: [
          if (isMobile)
            SizedBox(
              height: 65,
              child: DrawerHeader(
                child: widget.appBarTitle,
              ),
            ),
          ...navItems.map((navItem) {
            return ListTile(
              title: Text(navItem.title),
              onTap: () {
                _navigateTo(navItem.route);
              },
            );
          }),
        ],
      ),
    );
  }

  void _navigateTo(String routeName) {
    Navigator.of(_navigatorKey.currentContext!).pushNamedAndRemoveUntil(
      routeName,
      ModalRoute.withName('/'),
    );
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
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
        pageBuilder: (context, animation, secondaryAnimation) =>
            const Scaffold(body: Center(child: Text("Page Not Found"))),
      );
    }
  }
}
