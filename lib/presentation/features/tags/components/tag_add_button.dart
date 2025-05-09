import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/commands/save_tag_command.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/features/tags/services/tags_service.dart';

class TagAddButton extends StatefulWidget {
  final Color? buttonColor;
  final Color? buttonBackgroundColor;
  final Function(String tagId)? onTagCreated;
  final String? tooltip;

  const TagAddButton({
    super.key,
    this.buttonColor,
    this.buttonBackgroundColor,
    this.onTagCreated,
    this.tooltip,
  });

  @override
  State<TagAddButton> createState() => _TagAddButtonState();
}

class _TagAddButtonState extends State<TagAddButton> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _tagsService = container.resolve<TagsService>();

  Future<void> _addTag() async {
    try {
      final command = SaveTagCommand(
        name: _translationService.translate(TagTranslationKeys.newTag),
      );
      final SaveTagCommandResponse savedTag = await _mediator.send<SaveTagCommand, SaveTagCommandResponse>(command);

      _tagsService.notifyTagCreated(savedTag.id);
      if (widget.onTagCreated != null) widget.onTagCreated!(savedTag.id);
    } on BusinessException catch (e) {
      if (mounted) ErrorHelper.showError(context, e);
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(TagTranslationKeys.errorSaving),
        );
      }
    }
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
