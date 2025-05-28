import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/notes/constants/note_translation_keys.dart';
import 'package:whph/application/features/notes/services/abstraction/i_note_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';

class GetNoteQuery implements IRequest<GetNoteQueryResponse> {
  final String id;

  GetNoteQuery({
    required this.id,
  });
}

class NoteTagDto {
  String id;
  String tagId;
  String tagName;
  String? tagColor;

  NoteTagDto({
    required this.id,
    required this.tagId,
    required this.tagName,
    this.tagColor,
  });
}

class GetNoteQueryResponse {
  String id;
  String title;
  String? content;
  double order;
  DateTime createdDate;
  DateTime? modifiedDate;
  List<NoteTagDto> tags;

  GetNoteQueryResponse({
    required this.id,
    required this.title,
    this.content,
    required this.order,
    required this.createdDate,
    this.modifiedDate,
    required this.tags,
  });
}

class GetNoteQueryHandler implements IRequestHandler<GetNoteQuery, GetNoteQueryResponse> {
  final INoteRepository _noteRepository;

  GetNoteQueryHandler({
    required INoteRepository noteRepository,
  }) : _noteRepository = noteRepository;

  @override
  Future<GetNoteQueryResponse> call(GetNoteQuery request) async {
    final note = await _noteRepository.getById(request.id);

    if (note == null) {
      throw BusinessException('Note not found', NoteTranslationKeys.noteNotFound);
    }

    return GetNoteQueryResponse(
      id: note.id,
      title: note.title,
      content: note.content,
      order: note.order,
      createdDate: note.createdDate,
      modifiedDate: note.modifiedDate,
      tags: note.tags
          .map((noteTag) => NoteTagDto(
                id: noteTag.id,
                tagId: noteTag.tagId,
                tagName: noteTag.tag?.name ?? '',
                tagColor: noteTag.tag?.color,
              ))
          .toList(),
    );
  }
}
