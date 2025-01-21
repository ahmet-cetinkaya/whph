import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_delete_button.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_details_content.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_name_input_field.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';

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
            onDeleteSuccess: () => Navigator.of(context).pop(),
            buttonColor: AppTheme.primaryColor,
          ),
        ),
      ],
      builder: (context) => ListView(
        children: [
          AppUsageDetailsContent(id: widget.appUsageId),
        ],
      ),
    );
  }
}
