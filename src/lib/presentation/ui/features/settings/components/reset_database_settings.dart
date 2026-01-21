import 'package:flutter/material.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/components/reset_database_dialog.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class ResetDatabaseSettings extends StatelessWidget {
  const ResetDatabaseSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
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
        leading: Icon(
          Icons.delete_forever,
          color: theme.colorScheme.error,
        ),
        onTap: () {
          ResponsiveDialogHelper.showResponsiveDialog(
            context: context,
            child: const ResetDatabaseDialog(),
            size: DialogSize.large,
          );
        },
      ),
    );
  }
}
