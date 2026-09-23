import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_events.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_repository.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/domain/features/notes/note.dart';

class SaveNoteCommand implements IRequest<SaveNoteCommandResponse> {
  final String? id;
  final String title;
  final String? content;

  const SaveNoteCommand({this.id, required this.title, this.content});
}

class UpdateNoteCommand implements IRequest<SaveNoteCommandResponse> {
  final String id;
  final DateTime expectedRevision;
  final String? title;
  final NoteContentUpdate content;

  const UpdateNoteCommand({
    required this.id,
    required this.expectedRevision,
    this.title,
    this.content = const NoteContentUpdate.unchanged(),
  });
}

class NoteContentUpdate {
  final bool isChanged;
  final String? value;

  const NoteContentUpdate.unchanged()
      : isChanged = false,
        value = null;

  const NoteContentUpdate.set(String this.value) : isChanged = true;

  const NoteContentUpdate.clear()
      : isChanged = true,
        value = null;
}

class SaveNoteCommandResponse {
  final String id;
  final DateTime revision;

  const SaveNoteCommandResponse({required this.id, required this.revision});
}

class NoteRevisionConflictException implements Exception {
  final String noteId;

  const NoteRevisionConflictException(this.noteId);

  @override
  String toString() => 'The note was changed by another operation.';
}

class SaveNoteCommandHandler implements IRequestHandler<SaveNoteCommand, SaveNoteCommandResponse> {
  final INoteRepository _noteRepository;
  final INoteEvents _noteEvents;

  SaveNoteCommandHandler({required INoteRepository noteRepository, required INoteEvents noteEvents})
      : _noteRepository = noteRepository,
        _noteEvents = noteEvents;

  @override
  Future<SaveNoteCommandResponse> call(SaveNoteCommand request) async {
    final id = request.id ?? KeyHelper.generateStringId();
    final existingNote = await _noteRepository.getById(id);
    final now = DateTime.now().toUtc();

    if (existingNote != null) {
      throw StateError('Note already exists');
    }

    final note = Note(
      id: id,
      title: request.title,
      content: request.content,
      createdDate: now,
    );
    await _noteRepository.add(note);
    _noteEvents.notifyNoteCreated(note.id);
    return SaveNoteCommandResponse(id: note.id, revision: _databaseRevision(note.createdDate));
  }

  DateTime _databaseRevision(DateTime value) => DateTime.fromMillisecondsSinceEpoch(
        (value.millisecondsSinceEpoch ~/ 1000) * 1000,
        isUtc: true,
      );
}

class UpdateNoteCommandHandler implements IRequestHandler<UpdateNoteCommand, SaveNoteCommandResponse> {
  final INoteRepository _noteRepository;
  final INoteEvents _noteEvents;

  UpdateNoteCommandHandler({required INoteRepository noteRepository, required INoteEvents noteEvents})
      : _noteRepository = noteRepository,
        _noteEvents = noteEvents;

  @override
  Future<SaveNoteCommandResponse> call(UpdateNoteCommand request) async {
    final existingNote = await _noteRepository.getById(request.id);
    if (existingNote == null) {
      throw StateError('Note not found');
    }

    final updatedNote = Note(
      id: existingNote.id,
      title: request.title ?? existingNote.title,
      content: request.content.isChanged ? request.content.value : existingNote.content,
      createdDate: existingNote.createdDate,
      modifiedDate: existingNote.modifiedDate,
      deletedDate: existingNote.deletedDate,
      order: existingNote.order,
      tags: List.unmodifiable(existingNote.tags),
    );
    final revision = await _noteRepository.updateIfRevision(updatedNote, request.expectedRevision);
    if (revision == null) {
      throw NoteRevisionConflictException(request.id);
    }

    _noteEvents.notifyNoteUpdated(updatedNote.id);
    return SaveNoteCommandResponse(id: updatedNote.id, revision: revision);
  }
}
