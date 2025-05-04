import 'package:whph/application/shared/services/abstraction/i_repository.dart';
import 'package:whph/core/acore/repository/models/custom_order.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/notes/note.dart';

abstract class INoteRepository extends IRepository<Note, String> {
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
  Future<Note?> getById(String id);
}
