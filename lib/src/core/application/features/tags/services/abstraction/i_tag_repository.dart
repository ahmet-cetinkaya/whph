import 'package:whph/src/core/application/shared/services/abstraction/i_repository.dart';
import 'package:whph/corePackages/acore/repository/models/custom_order.dart';
import 'package:whph/corePackages/acore/repository/models/custom_where_filter.dart';
import 'package:whph/corePackages/acore/repository/models/paginated_list.dart';
import 'package:whph/src/core/domain/features/tags/tag.dart';

abstract class ITagRepository extends IRepository<Tag, String> {
  Future<PaginatedList<(Tag, List<Tag>)>> getListWithRelatedTags({
    required int pageIndex,
    required int pageSize,
    CustomWhereFilter? customWhereFilter,
    List<CustomOrder>? customOrder,
  });
}
