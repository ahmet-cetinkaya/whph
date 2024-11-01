import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_delete_button.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_details_content.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_name_input_field.dart';
import 'package:whph/presentation/features/shared/components/secondary_app_bar.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';

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
    return Scaffold(
      appBar: SecondaryAppBar(
        context: context,
        title: AppUsageNameInputField(
          id: widget.appUsageId,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: AppUsageDeleteButton(
                appUsageId: widget.appUsageId,
                onDeleteSuccess: () {
                  Navigator.of(context).pop();
                },
                buttonColor: AppTheme.primaryColor,
                buttonBackgroundColor: AppTheme.surface2),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Details
          AppUsageDetailsContent(
            id: widget.appUsageId,
          ),
        ],
      ),
    );
  }
}
