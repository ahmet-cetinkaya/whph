import 'package:whph/core/application/shared/services/abstraction/i_repository.dart' as app;
import 'package:acore/acore.dart' hide IRepository;
import 'package:whph/core/domain/features/tags/tag.dart';

abstract class ITagRepository extends app.IRepository<Tag, String> {
  Future<DateTime?> updateIfRevision(Tag tag, DateTime expectedRevision);

  Future<bool> deleteIfRevision(String id, DateTime expectedRevision);

  Future<PaginatedList<(Tag, List<Tag>)>> getListWithRelatedTags({
    required int pageIndex,
    required int pageSize,
    CustomWhereFilter? customWhereFilter,
    List<CustomOrder>? customOrder,
  });

  Future<Map<String, Tag>> getByIds(List<String> tagIds);
}
