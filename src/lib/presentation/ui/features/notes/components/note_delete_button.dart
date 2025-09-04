import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/notes/commands/delete_note_command.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/notes/constants/note_translation_keys.dart';
import 'package:whph/presentation/ui/features/notes/constants/note_ui_constants.dart';
import 'package:whph/presentation/ui/features/notes/services/notes_service.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/utils/responsive_dialog_helper.dart';

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
    final confirmed = await ResponsiveDialogHelper.showResponsiveDialog<bool>(
      context: context,
      size: DialogSize.min,
      child: AlertDialog(
        title: Text(_translationService.translate(NoteTranslationKeys.confirmDeleteTitle)),
        content: Text(_translationService.translate(NoteTranslationKeys.confirmDeleteMessage)),
        actions: [
          TextButton(
            onPressed: () => _cancelDelete(context),
            child: Text(_translationService.translate(SharedTranslationKeys.cancelButton)),
          ),
          TextButton(
            onPressed: () => _confirmDeleteAction(context),
            child: Text(_translationService.translate(SharedTranslationKeys.deleteButton)),
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

  void _cancelDelete(BuildContext context) {
    Navigator.of(context).pop(false);
  }

  void _confirmDeleteAction(BuildContext context) {
    Navigator.of(context).pop(true);
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
