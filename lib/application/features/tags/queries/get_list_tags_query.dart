import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/acore/queries/models/sort_option.dart';
import 'package:whph/core/acore/repository/models/custom_order.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';

enum TagSortFields {
  name,
  createdDate,
  modifiedDate,
}

class GetListTagsQuery implements IRequest<GetListTagsQueryResponse> {
  late int pageIndex;
  late int pageSize;
  String? search;
  List<String>? filterByTags;
  bool showArchived = false;
  List<SortOption<TagSortFields>>? sortBy;

  GetListTagsQuery({
    required this.pageIndex,
    required this.pageSize,
    this.search,
    this.filterByTags,
    this.showArchived = false,
    this.sortBy,
  });
}

class TagListItem {
  String id;
  String name;
  String? color;
  bool isArchived;
  List<TagListItem> relatedTags;

  TagListItem({
    required this.id,
    required this.name,
    this.color,
    this.isArchived = false,
    this.relatedTags = const [],
  });
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
  final ITagRepository _tagRepository;

  GetListTagsQueryHandler({required ITagRepository tagRepository}) : _tagRepository = tagRepository;

  @override
  Future<GetListTagsQueryResponse> call(GetListTagsQuery request) async {
    final tagsWithRelated = await _tagRepository.getListWithRelatedTags(
      pageIndex: request.pageIndex,
      pageSize: request.pageSize,
      customWhereFilter: _getFilters(request),
      customOrder: _getCustomOrders(request),
    );

    final items = tagsWithRelated.items.map((tagPair) {
      final (tag, relatedTags) = tagPair;
      return TagListItem(
        id: tag.id,
        name: tag.name,
        color: tag.color,
        isArchived: tag.isArchived,
        relatedTags: relatedTags
            .map((relatedTag) => TagListItem(
                  id: relatedTag.id,
                  name: relatedTag.name,
                  color: relatedTag.color,
                  isArchived: relatedTag.isArchived,
                ))
            .toList(),
      );
    }).toList();

    return GetListTagsQueryResponse(
      items: items,
      totalItemCount: tagsWithRelated.totalItemCount,
      totalPageCount: tagsWithRelated.totalPageCount,
      pageIndex: tagsWithRelated.pageIndex,
      pageSize: tagsWithRelated.pageSize,
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

  List<CustomOrder>? _getCustomOrders(GetListTagsQuery request) {
    if (request.sortBy == null || request.sortBy!.isEmpty) {
      return null;
    }

    List<CustomOrder> customOrders = [];
    for (var option in request.sortBy!) {
      String field;
      switch (option.field) {
        case TagSortFields.name:
          field = "name";
          break;
        case TagSortFields.createdDate:
          field = "created_date";
          break;
        case TagSortFields.modifiedDate:
          field = "modified_date";
          break;
      }
      customOrders.add(CustomOrder(field: field, direction: option.direction));
    }
    return customOrders;
  }
}
