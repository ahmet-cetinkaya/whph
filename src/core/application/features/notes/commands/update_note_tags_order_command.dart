import 'package:mediatr/mediatr.dart';
import 'package:application/features/notes/services/abstraction/i_note_tag_repository.dart';

class UpdateNoteTagsOrderCommand implements IRequest<void> {
  final String noteId;
  final Map<String, int> tagOrders;

  UpdateNoteTagsOrderCommand({
    required this.noteId,
    required this.tagOrders,
  });
}

class UpdateNoteTagsOrderCommandHandler implements IRequestHandler<UpdateNoteTagsOrderCommand, void> {
  final INoteTagRepository _noteTagRepository;

  UpdateNoteTagsOrderCommandHandler({required INoteTagRepository noteTagRepository})
      : _noteTagRepository = noteTagRepository;

  @override
  Future<void> call(UpdateNoteTagsOrderCommand request) async {
    await _noteTagRepository.updateTagOrders(request.noteId, request.tagOrders);
  }
}
