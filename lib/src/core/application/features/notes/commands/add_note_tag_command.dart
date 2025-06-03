import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/notes/constants/note_translation_keys.dart';
import 'package:whph/src/core/application/features/notes/services/abstraction/i_note_tag_repository.dart';
import 'package:whph/src/core/application/shared/utils/key_helper.dart';
import 'package:whph/corePackages/acore/errors/business_exception.dart';
import 'package:whph/src/core/domain/features/notes/note_tag.dart';

class AddNoteTagCommand implements IRequest<AddNoteTagCommandResponse> {
  final String noteId;
  final String tagId;

  AddNoteTagCommand({
    required this.noteId,
    required this.tagId,
  });
}

class AddNoteTagCommandResponse {
  final String id;

  AddNoteTagCommandResponse({required this.id});
}

class AddNoteTagCommandHandler implements IRequestHandler<AddNoteTagCommand, AddNoteTagCommandResponse> {
  final INoteTagRepository _noteTagRepository;

  AddNoteTagCommandHandler({required INoteTagRepository noteTagRepository}) : _noteTagRepository = noteTagRepository;

  @override
  Future<AddNoteTagCommandResponse> call(AddNoteTagCommand request) async {
    final existingNoteTag = await _noteTagRepository.getByNoteIdAndTagId(request.noteId, request.tagId);

    if (existingNoteTag != null) {
      throw BusinessException('Tag already exists', NoteTranslationKeys.tagAlreadyExists);
    }

    final id = KeyHelper.generateStringId();
    final now = DateTime.now().toUtc();

    final noteTag = NoteTag(
      id: id,
      noteId: request.noteId,
      tagId: request.tagId,
      createdDate: now,
    );

    await _noteTagRepository.add(noteTag);

    return AddNoteTagCommandResponse(id: id);
  }
}
