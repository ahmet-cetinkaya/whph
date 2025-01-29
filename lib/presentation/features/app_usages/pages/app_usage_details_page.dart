import 'package:flutter/material.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_delete_button.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_details_content.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_name_input_field.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
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
  Key _titleKey = UniqueKey();
  Key _contentKey = UniqueKey();

  void _refreshTitle() {
    if (mounted) {
      setState(() {
        _titleKey = UniqueKey();
      });
    }
  }

  void _refreshContent() {
    if (mounted) {
      setState(() {
        _contentKey = UniqueKey();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      appBarTitle: AppUsageNameInputField(
        key: _titleKey,
        id: widget.appUsageId,
        onAppUsageUpdated: _refreshContent,
      ),
      appBarActions: [
        AppUsageDeleteButton(
          appUsageId: widget.appUsageId,
          onDeleteSuccess: () => Navigator.of(context).pop(),
          buttonColor: AppTheme.primaryColor,
        ),
        HelpMenu(
          titleKey: AppUsageTranslationKeys.helpTitle,
          markdownContentKey: AppUsageTranslationKeys.helpContent,
        ),
        const SizedBox(width: 2),
      ],
      builder: (context) => ListView(
        children: [
          AppUsageDetailsContent(
            key: _contentKey,
            id: widget.appUsageId,
            onAppUsageUpdated: _refreshTitle,
          ),
        ],
      ),
    );
  }
}
