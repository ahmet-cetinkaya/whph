import 'package:flutter/material.dart';
import 'package:whph/presentation/features/app_usage_view/app_usage_view_page.dart';

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
      home: AppUsageViewPage(),
    );
  }
}
