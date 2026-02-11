import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:domain/features/settings/setting.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/features/about/components/changelog_dialog.dart';
import 'package:whph/presentation/ui/features/about/services/abstraction/i_changelog_dialog_service.dart';
import 'package:whph/presentation/ui/features/about/services/abstraction/i_changelog_service.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:acore/acore.dart';

/// Service to manage changelog dialog display logic
class ChangelogDialogService implements IChangelogDialogService {
  final Mediator _mediator;
  final IChangelogService _changelogService;
  final ITranslationService _translationService;

  ChangelogDialogService(this._mediator, this._changelogService, this._translationService);

  @override
  Future<void> checkAndShowChangelogDialog(BuildContext context) async {
    try {
      // Get locale before any async operations to avoid use_build_context_synchronously warning
      final localeCode = context.locale.languageCode;

      final lastShownVersion = await _getLastShownVersion();
      final currentVersion = AppInfo.version;

      // Don't show if this version was already shown
      if (getCoreVersion(lastShownVersion) == getCoreVersion(currentVersion)) {
        DomainLogger.debug('Changelog already shown for version $currentVersion');
        return;
      }

      // For first-time users (no version stored), skip showing changelog
      // They will see onboarding instead
      if (lastShownVersion == null) {
        DomainLogger.debug('First time user, skipping changelog and storing current version');
        await _saveLastShownVersion(currentVersion);
        return;
      }

      // Fetch changelog for current locale
      final changelogEntry = await _changelogService.fetchChangelog(localeCode);
      if (changelogEntry == null) {
        DomainLogger.debug('No changelog found for version $currentVersion');
        await _saveLastShownVersion(currentVersion);
        return;
      }

      // Show the changelog dialog
      if (context.mounted) {
        await ResponsiveDialogHelper.showResponsiveDialog(
          context: context,
          child: ChangelogDialog(
            changelogEntry: changelogEntry,
            translationService: _translationService,
          ),
          size: DialogSize.large,
        );
      }

      // Store the current version as shown
      await _saveLastShownVersion(currentVersion);
    } catch (e) {
      DomainLogger.error('Error showing changelog dialog: $e');
      // Still try to save the version to avoid showing broken dialog repeatedly
      try {
        await _saveLastShownVersion(AppInfo.version);
      } catch (e) {
        DomainLogger.error('Failed to save last shown changelog version after error: $e');
      }
    }
  }

  Future<String?> _getLastShownVersion() async {
    try {
      final response = await _mediator.send<GetSettingQuery, GetSettingQueryResponse?>(
        GetSettingQuery(key: SettingKeys.lastShownChangelogVersion),
      );
      if (response == null) return null;
      return response.getValue<String>();
    } catch (e) {
      DomainLogger.error('Failed to get last shown changelog version: $e');
      return null;
    }
  }

  Future<void> _saveLastShownVersion(String version) async {
    await _mediator.send(SaveSettingCommand(
      key: SettingKeys.lastShownChangelogVersion,
      value: version,
      valueType: SettingValueType.string,
    ));
  }

  /// Extracts the core version number without build metadata
  /// Example: "0.18.0+65" -> "0.18.0"
  String getCoreVersion(String? fullVersion) {
    if (fullVersion == null || fullVersion.isEmpty) return '';
    return fullVersion.split('+')[0];
  }
}
