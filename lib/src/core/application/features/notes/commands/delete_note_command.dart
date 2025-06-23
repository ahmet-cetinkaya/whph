import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/notes/constants/note_translation_keys.dart';
import 'package:whph/src/core/application/features/notes/services/abstraction/i_note_repository.dart';
import 'package:whph/src/core/application/features/notes/services/abstraction/i_note_tag_repository.dart';
import 'package:acore/acore.dart';

class DeleteNoteCommand implements IRequest<DeleteNoteCommandResponse> {
  final String id;

  DeleteNoteCommand({
    required this.id,
  });
}

class DeleteNoteCommandResponse {}

class DeleteNoteCommandHandler implements IRequestHandler<DeleteNoteCommand, DeleteNoteCommandResponse> {
  final INoteRepository _noteRepository;
  final INoteTagRepository _noteTagRepository;

  DeleteNoteCommandHandler({
    required INoteRepository noteRepository,
    required INoteTagRepository noteTagRepository,
  })  : _noteRepository = noteRepository,
        _noteTagRepository = noteTagRepository;

  @override
  Future<DeleteNoteCommandResponse> call(DeleteNoteCommand request) async {
    final note = await _noteRepository.getById(request.id);

    if (note == null) {
      throw BusinessException('Note not found', NoteTranslationKeys.noteNotFound);
    }

    // Delete associated tags first
    final noteTags = await _noteTagRepository.getByNoteId(request.id);
    for (final noteTag in noteTags) {
      await _noteTagRepository.delete(noteTag);
    }

    // Then delete the note
    await _noteRepository.delete(note);

    return DeleteNoteCommandResponse();
  }
}
