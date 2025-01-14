import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_delete_button.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_details_content.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_name_input_field.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/shared/constants/navigation_items.dart';

class AppUsageDetailsPage extends StatefulWidget {
  static const String route = '/app-usages/details';

  final String appUsageId;

  const AppUsageDetailsPage({super.key, required this.appUsageId});

  @override
  State<AppUsageDetailsPage> createState() => _AppUsageDetailsPageState();
}

class _AppUsageDetailsPageState extends State<AppUsageDetailsPage> {
  final Mediator mediator = container.resolve<Mediator>();

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      appBarTitle: AppUsageNameInputField(id: widget.appUsageId),
      appBarActions: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: AppUsageDeleteButton(
            appUsageId: widget.appUsageId,
            onDeleteSuccess: () => Navigator.of(context).pop(), // This will work with push navigation
            buttonColor: AppTheme.primaryColor,
            buttonBackgroundColor: AppTheme.surface2,
          ),
        ),
      ],
      topNavItems: NavigationItems.topNavItems,
      bottomNavItems: NavigationItems.bottomNavItems,
      routes: {},
      defaultRoute: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppUsageDetailsContent(id: widget.appUsageId),
        ],
      ),
    );
  }
}
