import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/notes/commands/delete_note_command.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/notes/constants/note_translation_keys.dart';
import 'package:whph/presentation/features/notes/constants/note_ui_constants.dart';
import 'package:whph/presentation/features/notes/services/notes_service.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';

class NoteDeleteButton extends StatefulWidget {
  final String noteId;
  final VoidCallback? onDeleted;
  final Color? buttonColor;

  const NoteDeleteButton({
    super.key,
    required this.noteId,
    this.onDeleted,
    this.buttonColor,
  });

  @override
  State<NoteDeleteButton> createState() => _NoteDeleteButtonState();
}

class _NoteDeleteButtonState extends State<NoteDeleteButton> {
  final _mediator = container.resolve<Mediator>();
  final _notesService = container.resolve<NotesService>();
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

    await AsyncErrorHandler.executeWithLoading(
      context: context,
      setLoading: (isLoading) => setState(() {
        _isDeleting = isLoading;
      }),
      errorMessage: _translationService.translate(NoteTranslationKeys.deletingError),
      operation: () async {
        final command = DeleteNoteCommand(id: widget.noteId);
        await _mediator.send(command);
        return true;
      },
      onSuccess: (_) {
        // Notify note deleted
        _notesService.notifyNoteDeleted(widget.noteId);

        if (widget.onDeleted != null) {
          widget.onDeleted!();
        }
      },
    );
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
