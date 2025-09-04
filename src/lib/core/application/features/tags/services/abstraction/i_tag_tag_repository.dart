import 'package:whph/core/application/shared/services/abstraction/i_repository.dart' as app;
import 'package:acore/acore.dart' hide IRepository;
import 'package:whph/core/domain/features/tags/tag_tag.dart';

abstract class ITagTagRepository extends app.IRepository<TagTag, String> {
  Future<PaginatedList<TagTag>> getListByPrimaryTagId(String id, int pageIndex, int pageSize);

  Future<List<TagTag>> getByPrimaryTagId(String primaryTagId);

  Future<List<TagTag>> getBySecondaryTagId(String secondaryTagId);

  Future<bool> anyByPrimaryAndSecondaryId(String primaryTagId, String secondaryTagId);
}
