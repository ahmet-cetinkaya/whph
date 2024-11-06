import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/commands/delete_tag_command.dart';
import 'package:whph/core/acore/errors/business_exception.dart';

import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/utils/error_helper.dart';

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
    } catch (error) {
      if (context.mounted) ErrorHelper.showError(context, error);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this tag?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
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
      style: ButtonStyle(
        backgroundColor:
            widget.buttonBackgroundColor != null ? WidgetStateProperty.all<Color>(widget.buttonBackgroundColor!) : null,
      ),
    );
  }
}
