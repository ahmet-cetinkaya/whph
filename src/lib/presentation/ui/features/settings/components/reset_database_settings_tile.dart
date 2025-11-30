import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/features/settings/components/reset_database_dialog.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/corePackages/acore/lib/utils/responsive_dialog_helper.dart';
import 'package:whph/corePackages/acore/lib/utils/dialog_size.dart';

class ResetDatabaseSettingsTile extends StatelessWidget {
  final ITranslationService translationService;

  const ResetDatabaseSettingsTile({
    super.key,
    required this.translationService,
  });

  void _showResetDatabaseDialog(BuildContext context) {
    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: const ResetDatabaseDialog(),
      size: DialogSize.medium,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: Icon(
          Icons.delete_forever,
          color: theme.colorScheme.error,
        ),
        title: Text(
          translationService.translate(SettingsTranslationKeys.resetDatabaseTitle),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        subtitle: Text(
          translationService.translate(SettingsTranslationKeys.resetDatabaseDescription),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          size: 16,
        ),
        onTap: () => _showResetDatabaseDialog(context),
      ),
    );
  }
}
