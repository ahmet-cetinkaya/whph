import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tags/commands/delete_tag_command.dart';
import 'package:whph/main.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/ui/features/tags/services/tags_service.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';

class TagDeleteButton extends StatefulWidget {
  final String tagId;
  final VoidCallback? onDeleteSuccess;
  final Color? buttonColor;
  final Color? buttonBackgroundColor;
  final String? tooltip;

  const TagDeleteButton({
    super.key,
    required this.tagId,
    this.onDeleteSuccess,
    this.buttonColor,
    this.buttonBackgroundColor,
    this.tooltip,
  });

  @override
  State<TagDeleteButton> createState() => _TagDeleteButtonState();
}

class _TagDeleteButtonState extends State<TagDeleteButton> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _tagsService = container.resolve<TagsService>();

  Future<void> _deleteTag(BuildContext context) async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(TagTranslationKeys.errorDeleting),
      operation: () async {
        final command = DeleteTagCommand(id: widget.tagId);
        await _mediator.send(command);
      },
      onSuccess: () {
        _tagsService.notifyTagDeleted(widget.tagId);
        if (widget.onDeleteSuccess != null) {
          widget.onDeleteSuccess!();
        }
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    bool? confirmed = await ResponsiveDialogHelper.showResponsiveDialog<bool>(
      context: context,
      size: DialogSize.min,
      child: AlertDialog(
        title: Text(_translationService.translate(TagTranslationKeys.deleteTag)),
        content: Text(_translationService.translate(TagTranslationKeys.confirmDelete)),
        actions: [
          TextButton(
            onPressed: () => _cancelDelete(context),
            child: Text(_translationService.translate(SharedTranslationKeys.cancelButton)),
          ),
          TextButton(
            onPressed: () => _confirmDeleteAction(context),
            child: Text(_translationService.translate(SharedTranslationKeys.deleteButton)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) _deleteTag(context);
  }

  void _cancelDelete(BuildContext context) {
    Navigator.of(context).pop(false);
  }

  void _confirmDeleteAction(BuildContext context) {
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _confirmDelete(context),
      icon: const Icon(Icons.delete),
      color: widget.buttonColor,
      tooltip: widget.tooltip,
      style: ButtonStyle(
        backgroundColor:
            widget.buttonBackgroundColor != null ? WidgetStatePropertyAll<Color>(widget.buttonBackgroundColor!) : null,
      ),
    );
  }
}
