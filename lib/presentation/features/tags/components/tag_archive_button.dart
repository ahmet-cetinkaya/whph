import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_tag_query.dart';
import 'package:whph/main.dart';
import 'package:whph/application/features/tags/commands/save_tag_command.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';

class TagArchiveButton extends StatefulWidget {
  final String tagId;
  final VoidCallback? onArchiveSuccess;
  final Color buttonColor;
  final Color buttonBackgroundColor;

  const TagArchiveButton({
    super.key,
    required this.tagId,
    this.onArchiveSuccess,
    this.buttonColor = AppTheme.primaryColor,
    this.buttonBackgroundColor = Colors.transparent,
  });

  @override
  State<TagArchiveButton> createState() => _TagArchiveButtonState();
}

class _TagArchiveButtonState extends State<TagArchiveButton> {
  bool? _isArchived;

  @override
  void initState() {
    super.initState();
    _loadArchiveStatus();
  }

  Future<void> _loadArchiveStatus() async {
    final mediator = container.resolve<Mediator>();
    try {
      final tag = await mediator.send<GetTagQuery, GetTagQueryResponse>(
        GetTagQuery(id: widget.tagId),
      );
      if (mounted) {
        setState(() {
          _isArchived = tag.isArchived;
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace, message: 'Failed to load archive status.');
      }
    }
  }

  Future<void> _toggleArchiveStatus() async {
    final newStatus = !(_isArchived ?? false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isArchived! ? TagUiConstants.unarchiveTagTitle : TagUiConstants.archiveTagTitle),
        content: Text(_isArchived! ? TagUiConstants.unarchiveTagMessage : TagUiConstants.archiveTagMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(SharedUiConstants.cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_isArchived! ? 'Unarchive' : 'Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final mediator = container.resolve<Mediator>();
      try {
        final tag = await mediator.send<GetTagQuery, GetTagQueryResponse>(
          GetTagQuery(id: widget.tagId),
        );

        await mediator.send(SaveTagCommand(
          id: widget.tagId,
          name: tag.name,
          isArchived: newStatus,
        ));

        if (mounted) {
          setState(() {
            _isArchived = newStatus;
          });
        }

        widget.onArchiveSuccess?.call();
      } catch (e, stackTrace) {
        if (mounted) {
          ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
              message: 'Failed to toggle archive status.');
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
      icon: Icon(_isArchived! ? TagUiConstants.unarchiveIcon : TagUiConstants.archiveIcon),
      tooltip: _isArchived! ? TagUiConstants.unarchiveTagTooltip : TagUiConstants.archiveTagTooltip,
      onPressed: _toggleArchiveStatus,
      color: widget.buttonColor,
      style: IconButton.styleFrom(
        backgroundColor: widget.buttonBackgroundColor,
      ),
    );
  }
}
