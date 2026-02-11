import 'package:whph/core/application/shared/services/abstraction/i_repository.dart' as app;
import 'package:acore/acore.dart' hide IRepository;
import 'package:domain/features/tags/tag.dart';

abstract class ITagRepository extends app.IRepository<Tag, String> {
  Future<PaginatedList<(Tag, List<Tag>)>> getListWithRelatedTags({
    required int pageIndex,
    required int pageSize,
    CustomWhereFilter? customWhereFilter,
    List<CustomOrder>? customOrder,
  });

  Future<Map<String, Tag>> getByIds(List<String> tagIds);
}
