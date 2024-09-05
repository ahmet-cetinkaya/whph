import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_list.dart';

class AppUsageViewPage extends StatefulWidget {
  static const String route = '/app-usages';

  final Mediator mediator = container.resolve<Mediator>();

  AppUsageViewPage({super.key});

  @override
  State<AppUsageViewPage> createState() => _AppUsageViewPageState();
}

class _AppUsageViewPageState extends State<AppUsageViewPage> {
  Key _appUsageListKey = UniqueKey();

  void _refreshAppUsages() {
    setState(() {
      _appUsageListKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Usages'),
        actions: [
          if (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _refreshAppUsages();
              },
            ),
        ],
      ),
      body: AppUsageList(
        key: _appUsageListKey,
        mediator: widget.mediator,
      ),
    );
  }
}
