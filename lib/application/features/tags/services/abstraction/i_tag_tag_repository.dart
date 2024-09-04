import 'package:whph/core/acore/repository/abstraction/i_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/tags/tag_tag.dart';

abstract class ITagTagRepository extends IRepository<TagTag, int> {
  Future<PaginatedList<TagTag>> getListByPrimaryTagId(int id, int pageIndex, int pageSize);

  Future<bool> anyByPrimaryAndSecondaryId(int primaryTagId, int secondaryTagId);
}
