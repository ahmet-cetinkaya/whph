import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/notes/services/abstraction/i_note_repository.dart';

class UpdateNoteOrderCommand implements IRequest<UpdateNoteOrderCommandResponse> {
  final List<String> noteIds;
  final List<double> orders;

  UpdateNoteOrderCommand({
    required this.noteIds,
    required this.orders,
  });
}

class UpdateNoteOrderCommandResponse {}

class UpdateNoteOrderCommandHandler implements IRequestHandler<UpdateNoteOrderCommand, UpdateNoteOrderCommandResponse> {
  final INoteRepository _noteRepository;

  UpdateNoteOrderCommandHandler({
    required INoteRepository noteRepository,
  }) : _noteRepository = noteRepository;

  @override
  Future<UpdateNoteOrderCommandResponse> call(UpdateNoteOrderCommand request) async {
    if (request.noteIds.length != request.orders.length) {
      throw ArgumentError('Note IDs and orders must have the same length');
    }

    await _noteRepository.updateNoteOrder(
      request.noteIds,
      request.orders,
    );

    return UpdateNoteOrderCommandResponse();
  }
}
