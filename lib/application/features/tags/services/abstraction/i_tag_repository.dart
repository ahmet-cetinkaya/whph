import 'package:whph/core/acore/repository/abstraction/i_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/tags/tag.dart';

abstract class ITagRepository extends IRepository<Tag, int> {
  Future<PaginatedList<Tag>> getListBySearch(String? search, int pageIndex, int pageSize);
}
