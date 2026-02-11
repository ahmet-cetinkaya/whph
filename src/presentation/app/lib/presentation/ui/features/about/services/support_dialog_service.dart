import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/queries/get_app_usage_statistics_query.dart';
import 'package:whph/core/application/features/app_usages/queries/get_list_by_top_app_usages_query.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:domain/features/settings/setting.dart';
import 'package:whph/presentation/ui/features/about/components/support_dialog.dart';
import 'package:whph/presentation/ui/features/about/services/abstraction/i_support_dialog_service.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';

class SupportDialogService implements ISupportDialogService {
  final Mediator _mediator;
  static const int _firstUsageThresholdHours = 5;
  static const int _repeatUsageThresholdHours = 24;

  SupportDialogService(this._mediator);

  @override
  Future<void> checkAndShowSupportDialog(BuildContext context) async {
    // Get total app usage
    final appUsageResponse = await _mediator.send<GetListByTopAppUsagesQuery, GetListByTopAppUsagesQueryResponse>(
      GetListByTopAppUsagesQuery(
        pageIndex: 0,
        pageSize: 1,
        searchByProcessName: "whph",
      ),
    );
    if (appUsageResponse.items.isEmpty) return;
    final appUsage = appUsageResponse.items.first;
    final statistics = await _mediator.send<GetAppUsageStatisticsQuery, GetAppUsageStatisticsResponse>(
      GetAppUsageStatisticsQuery(
        appUsageId: appUsage.id,
        startDate: DateTime(0).toUtc(),
        endDate: DateTime.now().toUtc(),
      ),
    );
    final totalHours = statistics.totalDuration / 3600;

    // Check if dialog has been shown before
    final hasShownBefore = await _hasShownSupportDialog();
    if (!hasShownBefore) {
      if (totalHours < _firstUsageThresholdHours) return;
      // Show dialog for the first time
      if (context.mounted) {
        await ResponsiveDialogHelper.showResponsiveDialog(
          context: context,
          child: SupportDialog(),
          size: DialogSize.min,
        );
        await _setSupportDialogShown();
        await _setSupportDialogLastShownUsage(statistics.totalDuration);
      }
      return;
    }

    // Check if enough time has passed since last shown
    final lastShownUsage = await _getSupportDialogLastShownUsage();
    if (lastShownUsage == null) return;
    final hoursSinceLastShown = (statistics.totalDuration - lastShownUsage) / 3600;
    if (hoursSinceLastShown < _repeatUsageThresholdHours) return;

    // Show dialog again after each 24h usage
    if (context.mounted) {
      await ResponsiveDialogHelper.showResponsiveDialog(
        context: context,
        child: SupportDialog(),
        size: DialogSize.min,
      );
      await _setSupportDialogLastShownUsage(statistics.totalDuration);
    }
  }

  Future<bool> _hasShownSupportDialog() async {
    try {
      final response = await _mediator.send<GetSettingQuery, GetSettingQueryResponse?>(
        GetSettingQuery(key: SettingKeys.supportDialogShown),
      );
      if (response == null) return false;
      return response.getValue<bool>();
    } catch (_) {
      return false;
    }
  }

  Future<void> _setSupportDialogShown() async {
    await _mediator.send(SaveSettingCommand(
      key: SettingKeys.supportDialogShown,
      value: 'true',
      valueType: SettingValueType.bool,
    ));
  }

  Future<num?> _getSupportDialogLastShownUsage() async {
    try {
      final response = await _mediator.send<GetSettingQuery, GetSettingQueryResponse?>(
        GetSettingQuery(key: SettingKeys.supportDialogLastShownUsage),
      );
      if (response == null) return null;
      final value = response.getValue<String>();
      return num.tryParse(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> _setSupportDialogLastShownUsage(num usageSeconds) async {
    await _mediator.send(SaveSettingCommand(
      key: SettingKeys.supportDialogLastShownUsage,
      value: usageSeconds.toString(),
      valueType: SettingValueType.string,
    ));
  }
}
