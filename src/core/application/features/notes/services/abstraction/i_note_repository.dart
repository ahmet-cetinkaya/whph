import 'package:whph/core/application/shared/services/abstraction/i_repository.dart' as app;
import 'package:acore/acore.dart' hide IRepository;
import 'package:domain/features/notes/note.dart';

abstract class INoteRepository extends app.IRepository<Note, String> {
  Future<void> updateNoteOrder(List<String> noteIds, List<double> orders);

  /// Gets a paginated list of notes with their associated tags included
  @override
  Future<PaginatedList<Note>> getList(
    int pageIndex,
    int pageSize, {
    CustomWhereFilter? customWhereFilter,
    List<CustomOrder>? customOrder,
    bool includeDeleted = false,
  });

  /// Gets a note by ID with its associated tags included
  @override
  Future<Note?> getById(String id, {bool includeDeleted = false});
}
