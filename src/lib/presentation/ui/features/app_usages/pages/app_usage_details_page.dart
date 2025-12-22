import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/app_usages/components/app_usage_delete_button.dart';
import 'package:whph/presentation/ui/features/app_usages/components/app_usage_details_content.dart';
import 'package:whph/presentation/ui/features/app_usages/components/app_usage_statistics_view.dart';
import 'package:whph/presentation/ui/features/app_usages/services/app_usages_service.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';

class AppUsageDetailsPage extends StatefulWidget {
  static const String route = '/app-usages/details';

  final String appUsageId;

  const AppUsageDetailsPage({super.key, required this.appUsageId});

  @override
  State<AppUsageDetailsPage> createState() => _AppUsageDetailsPageState();
}

class _AppUsageDetailsPageState extends State<AppUsageDetailsPage> {
  final _appUsagesService = container.resolve<AppUsagesService>();
  final _themeService = container.resolve<IThemeService>();

  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _setupEventListeners();
  }

  @override
  void dispose() {
    _removeEventListeners();
    super.dispose();
  }

  void _setupEventListeners() {
    _appUsagesService.onAppUsageUpdated.addListener(_handleAppUsageUpdated);
    _appUsagesService.onAppUsageDeleted.addListener(_handleAppUsageDeleted);
  }

  void _removeEventListeners() {
    _appUsagesService.onAppUsageUpdated.removeListener(_handleAppUsageUpdated);
    _appUsagesService.onAppUsageDeleted.removeListener(_handleAppUsageDeleted);
  }

  void _handleAppUsageUpdated() {
    if (!mounted || _appUsagesService.onAppUsageUpdated.value != widget.appUsageId) return;
    _hasChanges = true;
  }

  void _handleAppUsageDeleted() {
    if (!mounted || _appUsagesService.onAppUsageDeleted.value != widget.appUsageId) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  void _navigateBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(_hasChanges);
    }
  }

  void _onDeleteSuccess() {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  void _onAppUsageUpdated() {
    _hasChanges = true;
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
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _navigateBack,
          ),
          actions: [
            AppUsageDeleteButton(
              appUsageId: widget.appUsageId,
              onDeleteSuccess: _onDeleteSuccess,
              buttonColor: _themeService.primaryColor,
            ),
          ],
        ),
        body: Padding(
          padding: context.pageBodyPadding,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Usage Details Section
                AppUsageDetailsContent(
                  id: widget.appUsageId,
                  onAppUsageUpdated: _onAppUsageUpdated,
                ),

                const SizedBox(height: AppTheme.sizeMedium),

                // App Usage Statistics Section
                AppUsageStatisticsView(
                  appUsageId: widget.appUsageId,
                  onError: (error) {
                    // Handle statistics error if needed
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
