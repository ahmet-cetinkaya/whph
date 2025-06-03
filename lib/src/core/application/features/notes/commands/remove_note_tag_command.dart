import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/notes/constants/note_translation_keys.dart';
import 'package:whph/src/core/application/features/notes/services/abstraction/i_note_tag_repository.dart';
import 'package:whph/corePackages/acore/errors/business_exception.dart';
// ignore: unused_import
import 'package:whph/src/core/domain/features/notes/note_tag.dart';

class RemoveNoteTagCommand implements IRequest<RemoveNoteTagCommandResponse> {
  final String id;

  RemoveNoteTagCommand({
    required this.id,
  });
}

class RemoveNoteTagCommandResponse {}

class RemoveNoteTagCommandHandler implements IRequestHandler<RemoveNoteTagCommand, RemoveNoteTagCommandResponse> {
  final INoteTagRepository _noteTagRepository;

  RemoveNoteTagCommandHandler({required INoteTagRepository noteTagRepository}) : _noteTagRepository = noteTagRepository;

  @override
  Future<RemoveNoteTagCommandResponse> call(RemoveNoteTagCommand request) async {
    final noteTag = await _noteTagRepository.getById(request.id);

    if (noteTag == null) {
      throw BusinessException('Note tag not found', NoteTranslationKeys.noteTagNotFound);
    }

    await _noteTagRepository.delete(noteTag);

    return RemoveNoteTagCommandResponse();
  }
}
