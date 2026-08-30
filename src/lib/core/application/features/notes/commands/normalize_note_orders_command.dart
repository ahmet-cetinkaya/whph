import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_repository.dart';
import 'package:whph/core/domain/features/notes/note.dart';
import 'package:acore/acore.dart';

class NormalizeNoteOrdersCommand implements IRequest<NormalizeNoteOrdersResponse> {
  const NormalizeNoteOrdersCommand();
}

class NormalizeNoteOrdersResponse {
  final int normalizedCount;

  NormalizeNoteOrdersResponse(this.normalizedCount);
}

class NormalizeNoteOrdersCommandHandler
    implements IRequestHandler<NormalizeNoteOrdersCommand, NormalizeNoteOrdersResponse> {
  final INoteRepository _noteRepository;

  NormalizeNoteOrdersCommandHandler(this._noteRepository);

  @override
  Future<NormalizeNoteOrdersResponse> call(NormalizeNoteOrdersCommand request) async {
    // Get all non-deleted notes
    final allNotes = await _noteRepository.getAll(
      customWhereFilter: CustomWhereFilter('deleted_date IS NULL', []),
      customOrder: [CustomOrder(field: "order")],
    );

    if (allNotes.isEmpty) {
      return NormalizeNoteOrdersResponse(0);
    }

    // Sort by current order to maintain relative positions
    allNotes.sort((a, b) => a.order.compareTo(b.order));

    // Assign clean, evenly spaced orders and batch update in one transaction.
    OrderRank.assignSequential<Note>(allNotes, setOrder: (note, order) => note.order = order);
    await _noteRepository.updateMultiple(allNotes);

    return NormalizeNoteOrdersResponse(allNotes.length);
  }
}
