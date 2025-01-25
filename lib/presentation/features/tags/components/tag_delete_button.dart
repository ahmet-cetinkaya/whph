import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/commands/delete_tag_command.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';

import 'package:whph/main.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';

class TagDeleteButton extends StatefulWidget {
  final String tagId;
  final VoidCallback? onDeleteSuccess;
  final Color? buttonColor;
  final Color? buttonBackgroundColor;

  const TagDeleteButton({
    super.key,
    required this.tagId,
    this.onDeleteSuccess,
    this.buttonColor,
    this.buttonBackgroundColor,
  });

  @override
  State<TagDeleteButton> createState() => _TagDeleteButtonState();
}

class _TagDeleteButtonState extends State<TagDeleteButton> {
  final Mediator mediator = container.resolve<Mediator>();

  Future<void> _deleteTag(BuildContext context) async {
    try {
      var command = DeleteTagCommand(id: widget.tagId);
      await mediator.send(command);

      if (widget.onDeleteSuccess != null) {
        widget.onDeleteSuccess!();
      }
    } on BusinessException catch (e) {
      if (context.mounted) ErrorHelper.showError(context, e);
    } catch (e, stackTrace) {
      if (context.mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: 'Unexpected error occurred while deleting tag.');
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(TagUiConstants.deleteTagTitle),
        content: Text(TagUiConstants.deleteTagMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(SharedUiConstants.cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(SharedUiConstants.deleteLabel),
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
      icon: Icon(SharedUiConstants.deleteIcon),
      color: widget.buttonColor,
      style: ButtonStyle(
        backgroundColor:
            widget.buttonBackgroundColor != null ? WidgetStateProperty.all<Color>(widget.buttonBackgroundColor!) : null,
      ),
    );
  }
}
