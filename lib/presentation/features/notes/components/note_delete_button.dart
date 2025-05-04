import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/notes/commands/delete_note_command.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/notes/constants/note_translation_keys.dart';
import 'package:whph/presentation/features/notes/constants/note_ui_constants.dart';
import 'package:whph/presentation/features/notes/services/notes_service.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';

class NoteDeleteButton extends StatefulWidget {
  final String noteId;
  final VoidCallback? onDeleteSuccess;
  final Color? buttonColor;

  const NoteDeleteButton({
    super.key,
    required this.noteId,
    this.onDeleteSuccess,
    this.buttonColor,
  });

  @override
  State<NoteDeleteButton> createState() => _NoteDeleteButtonState();
}

class _NoteDeleteButtonState extends State<NoteDeleteButton> {
  final Mediator _mediator = container.resolve<Mediator>();
  final NotesService _notesService = container.resolve<NotesService>();
  final _translationService = container.resolve<ITranslationService>();
  bool _isDeleting = false;

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_translationService.translate(NoteTranslationKeys.confirmDeleteTitle)),
        content: Text(_translationService.translate(NoteTranslationKeys.confirmDeleteMessage)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_translationService.translate('shared.buttons.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_translationService.translate('shared.buttons.delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteNote();
    }
  }

  Future<void> _deleteNote() async {
    if (_isDeleting) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final command = DeleteNoteCommand(id: widget.noteId);
      await _mediator.send(command);

      // Notify note deleted
      _notesService.notifyNoteDeleted();

      if (widget.onDeleteSuccess != null) {
        widget.onDeleteSuccess!();
      }
    } on BusinessException catch (e) {
      if (mounted) ErrorHelper.showError(context, e);
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(NoteTranslationKeys.deletingError),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _isDeleting ? Icons.hourglass_empty : NoteUiConstants.deleteIcon,
        color: widget.buttonColor,
      ),
      onPressed: _isDeleting ? null : _confirmDelete,
      tooltip: _translationService.translate(NoteTranslationKeys.deleteNote),
    );
  }
}
