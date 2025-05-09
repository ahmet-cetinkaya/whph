import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/notes/commands/save_note_command.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/notes/constants/note_translation_keys.dart';
import 'package:whph/presentation/features/notes/constants/note_ui_constants.dart';
import 'package:whph/presentation/features/notes/services/notes_service.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';

class NoteAddButton extends StatefulWidget {
  /// Callback when a note is created, provides the created note ID
  final Function(String noteId)? onNoteCreated;
  final bool mini;
  final Color? buttonColor;

  const NoteAddButton({
    super.key,
    this.onNoteCreated,
    this.mini = false,
    this.buttonColor,
  });

  @override
  State<NoteAddButton> createState() => _NoteAddButtonState();
}

class _NoteAddButtonState extends State<NoteAddButton> {
  final _mediator = container.resolve<Mediator>();
  final _notesService = container.resolve<NotesService>();
  final _translationService = container.resolve<ITranslationService>();
  bool _isCreating = false;

  Future<void> _createNote() async {
    if (_isCreating) return;

    setState(() {
      _isCreating = true;
    });

    try {
      final command = SaveNoteCommand(
        title: _translationService.translate(NoteTranslationKeys.newNote),
        content: '',
      );

      final response = await _mediator.send<SaveNoteCommand, SaveNoteCommandResponse>(command);

      // Notify the app that a note was created
      _notesService.notifyNoteCreated(response.id);

      if (widget.onNoteCreated != null) {
        widget.onNoteCreated!(response.id);
      }
    } on BusinessException catch (e) {
      if (mounted) ErrorHelper.showError(context, e);
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(NoteTranslationKeys.savingError),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mini) {
      return IconButton(
        icon: Icon(_isCreating ? Icons.hourglass_empty : NoteUiConstants.addIcon),
        onPressed: _isCreating ? null : _createNote,
        tooltip: _translationService.translate(NoteTranslationKeys.addNote),
        color: widget.buttonColor,
      );
    }

    return FilledButton.icon(
      onPressed: _isCreating ? null : _createNote,
      icon: Icon(
        _isCreating ? Icons.hourglass_empty : NoteUiConstants.addIcon,
        size: AppTheme.iconSizeMedium,
      ),
      label: Text(_translationService.translate(NoteTranslationKeys.addNote)),
      style: FilledButton.styleFrom(
        backgroundColor: widget.buttonColor,
        foregroundColor: AppTheme.textColor,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
