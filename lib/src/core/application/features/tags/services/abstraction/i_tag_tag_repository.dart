import 'package:whph/src/core/application/shared/services/abstraction/i_repository.dart';
import 'package:whph/corePackages/acore/repository/models/paginated_list.dart';
import 'package:whph/src/core/domain/features/tags/tag_tag.dart';

abstract class ITagTagRepository extends IRepository<TagTag, String> {
  Future<PaginatedList<TagTag>> getListByPrimaryTagId(String id, int pageIndex, int pageSize);

  Future<bool> anyByPrimaryAndSecondaryId(String primaryTagId, String secondaryTagId);
}
