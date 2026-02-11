import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_repository.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:domain/features/notes/note.dart';

class SaveNoteCommand implements IRequest<SaveNoteCommandResponse> {
  final String? id;
  final String title;
  final String? content;

  SaveNoteCommand({
    this.id,
    required this.title,
    this.content,
  });
}

class SaveNoteCommandResponse {
  final String id;

  SaveNoteCommandResponse({required this.id});
}

class SaveNoteCommandHandler implements IRequestHandler<SaveNoteCommand, SaveNoteCommandResponse> {
  final INoteRepository _noteRepository;

  SaveNoteCommandHandler({required INoteRepository noteRepository}) : _noteRepository = noteRepository;

  @override
  Future<SaveNoteCommandResponse> call(SaveNoteCommand request) async {
    final id = request.id ?? KeyHelper.generateStringId();
    final now = DateTime.now().toUtc();

    final existingNote = await _noteRepository.getById(id).catchError((_) => null);

    if (existingNote == null) {
      // Create a new note
      final newNote = Note(
        id: id,
        title: request.title,
        content: request.content,
        createdDate: now,
      );
      await _noteRepository.add(newNote);
    } else {
      // Update existing note
      final updatedNote = Note(
        id: existingNote.id,
        title: request.title,
        content: request.content,
        createdDate: existingNote.createdDate,
        modifiedDate: now,
        deletedDate: existingNote.deletedDate,
        order: existingNote.order,
      );
      await _noteRepository.update(updatedNote);
    }

    return SaveNoteCommandResponse(id: id);
  }
}
