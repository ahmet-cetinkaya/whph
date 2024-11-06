import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/commands/save_tag_command.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/utils/error_helper.dart';

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
      setState(() {
        isLoading = true;
      });
    }

    try {
      var command = SaveTagCommand(
        name: "New Tag",
      );
      var response = await mediator.send<SaveTagCommand, SaveTagCommandResponse>(command);

      if (widget.onTagCreated != null) {
        widget.onTagCreated!(response.id);
      }
    } on BusinessException catch (e) {
      if (context.mounted) ErrorHelper.showError(context, e);
    } catch (e) {
      if (context.mounted) {
        ErrorHelper.showUnexpectedError(context, e, message: 'Unexpected error occurred while creating tag.');
      }
    } finally {
      if (!mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _createTag(context),
      icon: const Icon(Icons.add),
      color: widget.buttonColor,
      style: ButtonStyle(
        backgroundColor:
            widget.buttonBackgroundColor != null ? WidgetStateProperty.all<Color>(widget.buttonBackgroundColor!) : null,
      ),
    );
  }
}
