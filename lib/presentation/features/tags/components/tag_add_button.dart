import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/commands/save_tag_command.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';

class TagAddButton extends StatefulWidget {
  final Color? buttonColor;
  final Color? buttonBackgroundColor;
  final Function(String tagId)? onTagCreated;

  const TagAddButton({super.key, this.buttonColor, this.buttonBackgroundColor, this.onTagCreated});

  @override
  State<TagAddButton> createState() => _TagAddButtonState();
}

class _TagAddButtonState extends State<TagAddButton> {
  final Mediator mediator = container.resolve<Mediator>();
  bool isLoading = false;

  Future<void> _createTag(BuildContext context) async {
    if (isLoading) return;

    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
      var command = SaveTagCommand(
        name: TagUiConstants.newTagDefaultName,
      );
      var response = await mediator.send<SaveTagCommand, SaveTagCommandResponse>(command);

      if (widget.onTagCreated != null) {
        widget.onTagCreated!(response.id);
      }
    } catch (e, stackTrace) {
      if (context.mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace, message: TagUiConstants.errorSavingTag);
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _createTag(context),
      icon: Icon(SharedUiConstants.addIcon),
      color: widget.buttonColor,
      style: ButtonStyle(
        backgroundColor:
            widget.buttonBackgroundColor != null ? WidgetStatePropertyAll<Color>(widget.buttonBackgroundColor!) : null,
      ),
    );
  }
}
