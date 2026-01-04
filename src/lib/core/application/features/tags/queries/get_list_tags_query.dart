import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:acore/acore.dart';

import 'package:whph/core/application/features/tags/utils/tag_grouping_helper.dart';

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
  DateTime? createdDate;
  DateTime? modifiedDate;
  String? groupName;
  bool isGroupNameTranslatable;

  TagListItem({
    required this.id,
    required this.name,
    this.color,
    this.isArchived = false,
    this.relatedTags = const [],
    this.createdDate,
    this.modifiedDate,
    this.groupName,
    this.isGroupNameTranslatable = false,
  });
}

class GetListTagsQueryResponse extends PaginatedList<TagListItem> {
  GetListTagsQueryResponse(
      {required super.items, required super.totalItemCount, required super.pageIndex, required super.pageSize});
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
      final item = TagListItem(
        id: tag.id,
        name: tag.name,
        color: tag.color,
        isArchived: tag.isArchived,
        createdDate: tag.createdDate,
        modifiedDate: tag.modifiedDate,
        relatedTags: relatedTags
            .map((relatedTag) => TagListItem(
                  id: relatedTag.id,
                  name: relatedTag.name,
                  color: relatedTag.color,
                  isArchived: relatedTag.isArchived,
                  createdDate: relatedTag.createdDate,
                  modifiedDate: relatedTag.modifiedDate,
                ))
            .toList(),
      );

      if (request.sortBy != null) {
        final groupInfo = getTagGroupInfo(item, request.sortBy!.firstOrNull?.field);
        if (groupInfo != null) {
          item.groupName = groupInfo.name;
          item.isGroupNameTranslatable = groupInfo.isTranslatable;
        }
      }

      return item;
    }).toList();

    return GetListTagsQueryResponse(
      items: items,
      totalItemCount: tagsWithRelated.totalItemCount,
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
