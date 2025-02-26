import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/acore/repository/models/custom_order.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/tags/tag.dart';

class GetListTagsQuery implements IRequest<GetListTagsQueryResponse> {
  late int pageIndex;
  late int pageSize;
  String? search;
  List<String>? filterByTags;
  bool showArchived = false;

  GetListTagsQuery(
      {required this.pageIndex, required this.pageSize, this.search, this.filterByTags, this.showArchived = false});
}

class TagListItem {
  String id;
  String name;
  String? color;

  TagListItem({required this.id, required this.name, this.color});
}

class GetListTagsQueryResponse extends PaginatedList<TagListItem> {
  GetListTagsQueryResponse(
      {required super.items,
      required super.totalItemCount,
      required super.totalPageCount,
      required super.pageIndex,
      required super.pageSize});
}

class GetListTagsQueryHandler implements IRequestHandler<GetListTagsQuery, GetListTagsQueryResponse> {
  late final ITagRepository _tagRepository;

  GetListTagsQueryHandler({required ITagRepository tagRepository}) : _tagRepository = tagRepository;

  @override
  Future<GetListTagsQueryResponse> call(GetListTagsQuery request) async {
    PaginatedList<Tag> tags = await _tagRepository.getList(
      request.pageIndex,
      request.pageSize,
      customWhereFilter: _getFilters(request),
      customOrder: [CustomOrder(field: "name")],
    );

    return GetListTagsQueryResponse(
      items: tags.items
          .map((e) => TagListItem(
                id: e.id,
                name: e.name,
                color: e.color,
              ))
          .toList(),
      totalItemCount: tags.totalItemCount,
      totalPageCount: tags.totalPageCount,
      pageIndex: tags.pageIndex,
      pageSize: tags.pageSize,
    );
  }

  CustomWhereFilter? _getFilters(GetListTagsQuery request) {
    CustomWhereFilter? filter = CustomWhereFilter.empty();
    List<String> conditions = [];

    // Archive filter
    conditions.add('is_archived = ?');
    filter.variables.add(request.showArchived ? 1 : 0);

    // Search filter
    if (request.search != null && request.search!.isNotEmpty) {
      conditions.add('name LIKE ?');
      filter.variables.add('%${request.search}%');
    }

    // Tag relationship filter
    if (request.filterByTags != null && request.filterByTags!.isNotEmpty) {
      conditions.add('''(
        id IN (${request.filterByTags!.map((_) => '?').join(',')})
        OR
        (SELECT COUNT(*) FROM tag_tag_table 
         WHERE tag_tag_table.primary_tag_id = tag_table.id 
         AND tag_tag_table.secondary_tag_id IN (${request.filterByTags!.map((_) => '?').join(',')})
         AND tag_tag_table.deleted_date IS NULL) > 0
      )''');

      // Add variables for both IN clause and EXISTS subquery
      filter.variables.addAll([...request.filterByTags!, ...request.filterByTags!]);
    }

    filter.query = conditions.join(' AND ');
    return filter;
  }
}
