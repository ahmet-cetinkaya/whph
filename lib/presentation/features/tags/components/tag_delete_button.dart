import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/commands/delete_tag_command.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/features/tags/services/tags_service.dart';

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
    bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_translationService.translate(TagTranslationKeys.deleteTag)),
        content: Text(_translationService.translate(TagTranslationKeys.confirmDelete)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_translationService.translate(SharedTranslationKeys.cancelButton)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_translationService.translate(SharedTranslationKeys.deleteButton)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) _deleteTag(context);
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
