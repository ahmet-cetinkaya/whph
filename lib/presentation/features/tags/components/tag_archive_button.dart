import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_tag_query.dart';
import 'package:whph/main.dart';
import 'package:whph/application/features/tags/commands/save_tag_command.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/features/tags/services/tags_service.dart';

class TagArchiveButton extends StatefulWidget {
  final String tagId;
  final VoidCallback? onArchiveSuccess;
  final Color buttonColor;
  final Color buttonBackgroundColor;
  final String? tooltip;

  const TagArchiveButton({
    super.key,
    required this.tagId,
    this.onArchiveSuccess,
    this.buttonColor = AppTheme.primaryColor,
    this.buttonBackgroundColor = Colors.transparent,
    this.tooltip,
  });

  @override
  State<TagArchiveButton> createState() => _TagArchiveButtonState();
}

class _TagArchiveButtonState extends State<TagArchiveButton> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _tagsService = container.resolve<TagsService>();
  bool? _isArchived;

  @override
  void initState() {
    super.initState();
    _loadArchiveStatus();
  }

  Future<void> _loadArchiveStatus() async {
    try {
      final tag = await _mediator.send<GetTagQuery, GetTagQueryResponse>(
        GetTagQuery(id: widget.tagId),
      );
      if (mounted) {
        setState(() {
          _isArchived = tag.isArchived;
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(TagTranslationKeys.errorLoadingArchiveStatus),
        );
      }
    }
  }

  Future<void> _toggleArchiveStatus() async {
    final newStatus = !(_isArchived ?? false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_translationService.translate(
          _isArchived! ? TagTranslationKeys.unarchiveTag : TagTranslationKeys.archiveTag,
        )),
        content: Text(_translationService.translate(
          _isArchived! ? TagTranslationKeys.unarchiveTagConfirm : TagTranslationKeys.archiveTagConfirm,
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_translationService.translate(SharedTranslationKeys.cancelButton)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_translationService.translate(
              _isArchived! ? TagTranslationKeys.unarchiveTag : TagTranslationKeys.archiveTag,
            )),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final tag = await _mediator.send<GetTagQuery, GetTagQueryResponse>(
          GetTagQuery(id: widget.tagId),
        );

        await _mediator.send(SaveTagCommand(
          id: widget.tagId,
          name: tag.name,
          isArchived: newStatus,
        ));

        if (mounted) {
          setState(() {
            _isArchived = newStatus;
          });
        }

        // Notify that the tag has been updated
        _tagsService.notifyTagUpdated(widget.tagId);

        widget.onArchiveSuccess?.call();
      } catch (e, stackTrace) {
        if (mounted) {
          ErrorHelper.showUnexpectedError(
            context,
            e as Exception,
            stackTrace,
            message: _translationService.translate(TagTranslationKeys.errorTogglingArchive),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isArchived == null) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: Icon(_isArchived! ? Icons.unarchive : Icons.archive),
      tooltip: widget.tooltip ??
          _translationService.translate(
            _isArchived! ? TagTranslationKeys.unarchiveTagTooltip : TagTranslationKeys.archiveTagTooltip,
          ),
      onPressed: _toggleArchiveStatus,
      color: widget.buttonColor,
      style: IconButton.styleFrom(
        backgroundColor: widget.buttonBackgroundColor,
      ),
    );
  }
}
