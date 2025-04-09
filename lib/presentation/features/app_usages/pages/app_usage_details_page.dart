import 'package:flutter/material.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_delete_button.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_details_content.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_translation_keys.dart';

class AppUsageDetailsPage extends StatefulWidget {
  static const String route = '/app-usages/details';

  final String appUsageId;

  const AppUsageDetailsPage({super.key, required this.appUsageId});

  @override
  State<AppUsageDetailsPage> createState() => _AppUsageDetailsPageState();
}

class _AppUsageDetailsPageState extends State<AppUsageDetailsPage> {
  String? _title;
  bool _hasChanges = false;

  void _refreshTitle(String title) {
    if (mounted) {
      setState(() {
        _title = title.replaceAll('\n', ' ');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(_hasChanges);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: _title != null ? Text(_title!) : null,
          actions: [
            AppUsageDeleteButton(
              appUsageId: widget.appUsageId,
              onDeleteSuccess: () {
                _hasChanges = true;
                Navigator.of(context).pop(_hasChanges);
              },
              buttonColor: AppTheme.primaryColor,
            ),
            HelpMenu(
              titleKey: AppUsageTranslationKeys.helpTitle,
              markdownContentKey: AppUsageTranslationKeys.helpContent,
            ),
            const SizedBox(width: 2),
          ],
        ),
        body: Align(
          alignment: Alignment.topLeft,
          child: AppUsageDetailsContent(
            id: widget.appUsageId,
            onNameUpdated: (name) {
              _refreshTitle(name);
              _hasChanges = true;
            },
          ),
        ),
      ),
    );
  }
}
