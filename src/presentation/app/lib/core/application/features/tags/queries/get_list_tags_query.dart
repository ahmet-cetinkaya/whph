import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tags/tag.dart';

import 'package:whph/core/application/features/tags/models/tag_sort_fields.dart';
import 'package:whph/core/application/features/tags/utils/tag_grouping_helper.dart';

class GetListTagsQuery implements IRequest<GetListTagsQueryResponse> {
  late int pageIndex;
  late int pageSize;
  String? search;
  List<String>? filterByTags;
  bool showArchived = false;
  List<SortOption<TagSortFields>>? sortBy;
  SortOption<TagSortFields>? groupBy;
  bool enableGrouping;

  GetListTagsQuery({
    required this.pageIndex,
    required this.pageSize,
    this.search,
    this.filterByTags,
    this.showArchived = false,
    this.sortBy,
    this.groupBy,
    this.enableGrouping = false,
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
  TagType type;
  int tagOrder;

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
    this.type = TagType.label,
    this.tagOrder = 0,
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
        type: tag.type,
        relatedTags: relatedTags
            .map((relatedTag) => TagListItem(
                  id: relatedTag.id,
                  name: relatedTag.name,
                  color: relatedTag.color,
                  isArchived: relatedTag.isArchived,
                  createdDate: relatedTag.createdDate,
                  modifiedDate: relatedTag.modifiedDate,
                  type: relatedTag.type,
                ))
            .toList(),
      );

      final groupField = request.enableGrouping ? request.groupBy?.field ?? request.sortBy?.firstOrNull?.field : null;
      if (groupField != null) {
        final groupInfo = getTagGroupInfo(item, groupField);
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
    if ((request.sortBy == null || request.sortBy!.isEmpty) && (!request.enableGrouping || request.groupBy == null)) {
      return null;
    }

    List<CustomOrder> customOrders = [];

    // Prioritize grouping field if exists
    if (request.enableGrouping && request.groupBy != null) {
      _addCustomOrder(customOrders, request.groupBy!);
    }

    if (request.sortBy != null) {
      for (var option in request.sortBy!) {
        // Avoid duplicate if group by is same as first sort option
        if (request.enableGrouping && request.groupBy != null && option.field == request.groupBy!.field) {
          continue;
        }
        _addCustomOrder(customOrders, option);
      }
    }
    return customOrders;
  }

  void _addCustomOrder(List<CustomOrder> orders, SortOption<TagSortFields> option) {
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
      case TagSortFields.type:
        field = "type";
        break;
      // ignore: unreachable_switch_default
      default:
        throw UnimplementedError('Sort field ${option.field} not implemented');
    }
    orders.add(CustomOrder(field: field, direction: option.direction));
  }
}
