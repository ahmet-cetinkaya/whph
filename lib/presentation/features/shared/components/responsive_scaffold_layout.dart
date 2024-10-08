import 'package:flutter/material.dart';

class NavItem {
  final String title;
  final String route;

  NavItem(this.title, this.route);
}

class ResponsiveScaffoldLayout extends StatefulWidget {
  final Widget title;
  final List<NavItem> navItems;
  final Map<String, WidgetBuilder> routes;

  const ResponsiveScaffoldLayout({super.key, required this.navItems, required this.routes, required this.title});

  @override
  State<ResponsiveScaffoldLayout> createState() => _ResponsiveScaffoldLayoutState();
}

class _ResponsiveScaffoldLayoutState extends State<ResponsiveScaffoldLayout> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWideScreen = width > 600;

    return Scaffold(
      appBar: AppBar(
        title: widget.title,
        leading: !isWideScreen
            ? Builder(
                builder: (BuildContext context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
              )
            : null,
      ),
      drawer: isWideScreen ? null : _buildDrawer(widget.navItems),
      body: Row(
        children: [
          if (isWideScreen) _buildDrawer(widget.navItems),
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
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: navItems.map((navItem) {
          return ListTile(
            title: Text(navItem.title),
            onTap: () {
              _navigateTo(navItem.route);
            },
          );
        }).toList(),
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
