import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/notes/commands/add_note_tag_command.dart';
import 'package:whph/application/features/notes/commands/save_note_command.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/notes/constants/note_translation_keys.dart';
import 'package:whph/presentation/features/notes/constants/note_ui_constants.dart';
import 'package:whph/presentation/features/notes/services/notes_service.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';

class NoteAddButton extends StatefulWidget {
  /// Callback when a note is created, provides the created note ID
  final Function(String noteId)? onNoteCreated;
  final bool mini;
  final Color? buttonColor;
  final List<String>? initialTagIds;

  const NoteAddButton({
    super.key,
    this.onNoteCreated,
    this.mini = false,
    this.buttonColor,
    this.initialTagIds,
  });

  @override
  State<NoteAddButton> createState() => _NoteAddButtonState();
}

class _NoteAddButtonState extends State<NoteAddButton> {
  final _mediator = container.resolve<Mediator>();
  final _notesService = container.resolve<NotesService>();
  final _translationService = container.resolve<ITranslationService>();
  bool _isCreating = false;

  Future<void> _addTagsToNote(String noteId, List<String> tagIds) async {
    for (final tagId in tagIds) {
      await AsyncErrorHandler.execute(
        context: context,
        errorMessage: _translationService.translate(NoteTranslationKeys.savingError),
        operation: () async {
          final command = AddNoteTagCommand(noteId: noteId, tagId: tagId);
          return await _mediator.send(command);
        },
      );
    }
  }

  Future<void> _createNote() async {
    if (_isCreating) return;

    await AsyncErrorHandler.executeWithLoading(
      context: context,
      setLoading: (isLoading) => setState(() {
        _isCreating = isLoading;
      }),
      errorMessage: _translationService.translate(NoteTranslationKeys.savingError),
      operation: () async {
        final command = SaveNoteCommand(
          title: _translationService.translate(NoteTranslationKeys.newNote),
          content: '',
        );

        final response = await _mediator.send<SaveNoteCommand, SaveNoteCommandResponse>(command);

        if (widget.initialTagIds != null && widget.initialTagIds!.isNotEmpty) {
          await _addTagsToNote(response.id, widget.initialTagIds!);
        }

        return response;
      },
      onSuccess: (response) {
        // Notify the app that a note was created
        _notesService.notifyNoteCreated(response.id);

        if (widget.onNoteCreated != null) {
          widget.onNoteCreated!(response.id);
        }
      },
    );
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
