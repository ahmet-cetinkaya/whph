import 'package:flutter/material.dart';
import 'package:whph/presentation/features/app_usages/pages/app_usage_view_page.dart';
import 'package:whph/presentation/features/habits/pages/habits_page.dart';
import 'package:whph/presentation/features/tags/pages/tags_page.dart';
import 'package:whph/presentation/features/tasks/pages/tasks_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WHPH',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.yellow),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const MainLayout(),
      onGenerateRoute: (routeSettings) {
        return _buildPageRoute(routeSettings);
      },
    );
  }

  static PageRoute _buildPageRoute(RouteSettings settings) {
    Widget page;
    switch (settings.name) {
      case AppUsageViewPage.route:
        page = AppUsageViewPage();
        break;
      case HabitsPage.route:
        page = HabitsPage();
        break;
      case TasksPage.route:
        page = const TasksPage();
        break;
      case TagsPage.route:
        page = TagsPage();
        break;
      default:
        page = const TasksPage();
    }

    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child; // No animation
      },
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  _MainLayoutState createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWideScreen = width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WHPH'),
        leading: !isWideScreen
            ? Builder(
                builder: (BuildContext context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    Scaffold.of(context).openDrawer(); // Artık doğru bağlam kullanılıyor
                  },
                ),
              )
            : null,
      ),
      drawer: isWideScreen ? null : _buildDrawer(), // Geniş ekranlarda Drawer'ı gizle
      body: Row(
        children: [
          if (isWideScreen) _buildDrawer(), // Geniş ekranlarda Drawer'ı açık tut
          Expanded(
            child: Navigator(
              key: _navigatorKey,
              onGenerateRoute: (routeSettings) {
                return App._buildPageRoute(routeSettings);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          ListTile(
            title: const Text('Tasks'),
            onTap: () {
              _navigateTo(TasksPage.route);
            },
          ),
          ListTile(
            title: const Text('Tags'),
            onTap: () {
              _navigateTo(TagsPage.route);
            },
          ),
          ListTile(
            title: const Text('Habits'),
            onTap: () {
              _navigateTo(HabitsPage.route);
            },
          ),
          ListTile(
            title: const Text('App Usage'),
            onTap: () {
              _navigateTo(AppUsageViewPage.route);
            },
          ),
        ],
      ),
    );
  }

  void _navigateTo(String routeName) {
    Navigator.of(_navigatorKey.currentContext!).pushNamedAndRemoveUntil(
      routeName,
      ModalRoute.withName('/'),
    );
    // Drawer'ı kapat
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}
