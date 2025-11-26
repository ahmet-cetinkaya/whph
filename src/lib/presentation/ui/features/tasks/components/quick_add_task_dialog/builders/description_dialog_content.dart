import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:whph/presentation/ui/shared/components/markdown_editor.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';

/// Dialog content component for editing task description
/// Follows the same architectural pattern as EstimatedTimeDialogContent
class DescriptionDialogContent extends StatelessWidget {
  final String description;
  final ValueChanged<String> onChanged;
  final ITranslationService translationService;
  final ThemeData theme;

  const DescriptionDialogContent({
    super.key,
    required this.description,
    required this.onChanged,
    required this.translationService,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        title: Text(
          TaskTranslationKeys.descriptionLabel.tr(),
        ),
        automaticallyImplyLeading: true,
        actions: [
          if (description.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => onChanged(''),
              tooltip: translationService.translate(SharedTranslationKeys.clearButton),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(translationService.translate(SharedTranslationKeys.doneButton)),
          ),
          const SizedBox(width: AppTheme.sizeSmall),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.sizeMedium),
          child: Column(
            children: [
              Expanded(
                child: _buildMarkdownEditorSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarkdownEditorSection() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: MarkdownEditor(
        controller: TextEditingController(text: description),
        hintText: translationService.translate('tasks.details.description.hint'),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        toolbarBackground: theme.colorScheme.surface,
        onChanged: onChanged,
      ),
    );
  }
}
