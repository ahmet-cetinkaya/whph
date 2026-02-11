import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tags/commands/save_tag_command.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/ui/features/tags/services/tags_service.dart';

class TagAddButton extends StatefulWidget {
  /// The color of the button icon
  final Color? buttonColor;

  /// The background color of the button
  final Color? buttonBackgroundColor;

  /// Callback when a tag is created
  final Function(String tagId)? onTagCreated;

  /// Button tooltip text
  final String? tooltip;

  /// Initial name for the tag
  final String? initialName;

  /// Whether to create the tag as archived
  final bool? initialArchived;

  const TagAddButton({
    super.key,
    this.buttonColor,
    this.buttonBackgroundColor,
    this.onTagCreated,
    this.tooltip,
    this.initialName,
    this.initialArchived,
  });

  @override
  State<TagAddButton> createState() => _TagAddButtonState();
}

class _TagAddButtonState extends State<TagAddButton> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _tagsService = container.resolve<TagsService>();

  Future<void> _addTag() async {
    await AsyncErrorHandler.execute<SaveTagCommandResponse>(
      context: context,
      errorMessage: _translationService.translate(TagTranslationKeys.errorSaving),
      operation: () async {
        final command = SaveTagCommand(
          name: widget.initialName ?? "",
          isArchived: widget.initialArchived == true,
        );
        return await _mediator.send<SaveTagCommand, SaveTagCommandResponse>(command);
      },
      onSuccess: (savedTag) {
        _tagsService.notifyTagCreated(savedTag.id);
        if (widget.onTagCreated != null) widget.onTagCreated!(savedTag.id);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _addTag,
      icon: const Icon(Icons.add),
      color: widget.buttonColor,
      tooltip: widget.tooltip,
      style: ButtonStyle(
        backgroundColor:
            widget.buttonBackgroundColor != null ? WidgetStatePropertyAll<Color>(widget.buttonBackgroundColor!) : null,
      ),
    );
  }
}
