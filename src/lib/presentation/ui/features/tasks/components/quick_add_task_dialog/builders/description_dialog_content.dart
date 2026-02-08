import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:acore/acore.dart' show MarkdownEditor;
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';

/// Dialog content component for editing task description
/// Follows the same architectural pattern as EstimatedTimeDialogContent
class DescriptionDialogContent extends StatefulWidget {
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
  State<DescriptionDialogContent> createState() => _DescriptionDialogContentState();
}

class _DescriptionDialogContentState extends State<DescriptionDialogContent> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.description);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          TaskTranslationKeys.descriptionLabel.tr(),
        ),
        automaticallyImplyLeading: true,
        actions: [
          if (widget.description.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => widget.onChanged(''),
              tooltip: widget.translationService.translate(SharedTranslationKeys.clearButton),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(widget.translationService.translate(SharedTranslationKeys.doneButton)),
          ),
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
        border: Border.all(color: widget.theme.colorScheme.outline.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: MarkdownEditor.simple(
        controller: _controller,
        hintText: widget.translationService.translate('tasks.details.description.hint'),
        style: widget.theme.textTheme.bodySmall?.copyWith(
          color: widget.theme.colorScheme.onSurface,
        ),
        toolbarBackground: widget.theme.colorScheme.surface,
        onChanged: widget.onChanged,
        translations: SharedTranslationKeys.mapMarkdownTranslations(widget.translationService),
      ),
    );
  }
}
