import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/app_usages/queries/get_app_usage_statistics_query.dart';
import 'package:whph/src/core/application/features/app_usages/queries/get_list_by_top_app_usages_query.dart';
import 'package:whph/src/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/src/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/src/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/src/core/domain/features/settings/setting.dart';
import 'package:whph/src/presentation/ui/features/about/components/support_dialog.dart';
import 'package:whph/src/presentation/ui/features/about/services/abstraction/i_support_dialog_service.dart';
import 'package:whph/src/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/src/presentation/ui/shared/utils/responsive_dialog_helper.dart';

class SupportDialogService implements ISupportDialogService {
  final Mediator _mediator;
  static const int _usageThresholdHours = 5;

  SupportDialogService(this._mediator);

  @override
  Future<void> checkAndShowSupportDialog(BuildContext context) async {
    // Check if dialog has been shown before
    final hasShownBefore = await _hasShownSupportDialog();
    if (hasShownBefore) return;

    // Search for our app process
    final appUsageResponse = await _mediator.send<GetListByTopAppUsagesQuery, GetListByTopAppUsagesQueryResponse>(
      GetListByTopAppUsagesQuery(
        pageIndex: 0,
        pageSize: 1,
        searchByProcessName: "whph",
      ),
    );

    if (appUsageResponse.items.isEmpty) return;

    // Get app usage statistics
    final appUsage = appUsageResponse.items.first;
    final statistics = await _mediator.send<GetAppUsageStatisticsQuery, GetAppUsageStatisticsResponse>(
      GetAppUsageStatisticsQuery(
        appUsageId: appUsage.id,
        startDate: DateTime(0).toUtc(),
        endDate: DateTime.now().toUtc(),
      ),
    );

    // Convert total duration from seconds to hours
    final totalHours = statistics.totalDuration / 3600;
    if (totalHours < _usageThresholdHours) return;

    // Show the dialog
    if (context.mounted) {
      await ResponsiveDialogHelper.showResponsiveDialog(
        context: context,
        child: SupportDialog(),
        size: DialogSize.min,
      );

      // Mark as shown
      await _markSupportDialogAsShown();
    }
  }

  Future<bool> _hasShownSupportDialog() async {
    try {
      final response = await _mediator.send<GetSettingQuery, GetSettingQueryResponse>(
        GetSettingQuery(key: SettingKeys.supportDialogShown),
      );
      return response.getValue<bool>();
    } catch (_) {
      return false;
    }
  }

  Future<void> _markSupportDialogAsShown() async {
    await _mediator.send(SaveSettingCommand(
      key: SettingKeys.supportDialogShown,
      value: 'true',
      valueType: SettingValueType.bool,
    ));
  }
}
