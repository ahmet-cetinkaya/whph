import 'package:whph/src/core/application/shared/services/abstraction/i_repository.dart' as app;
import 'package:acore/acore.dart' hide IRepository;
import 'package:whph/src/core/domain/features/tags/tag_tag.dart';

abstract class ITagTagRepository extends app.IRepository<TagTag, String> {
  Future<PaginatedList<TagTag>> getListByPrimaryTagId(String id, int pageIndex, int pageSize);

  Future<bool> anyByPrimaryAndSecondaryId(String primaryTagId, String secondaryTagId);
}
