import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/tags/tag.dart';

class GetListAppUsageTagRulesQuery implements IRequest<GetListAppUsageTagRulesQueryResponse> {
  final int pageIndex;
  final int pageSize;
  final List<String>? filterByTags;
  final bool? filterByActive;

  GetListAppUsageTagRulesQuery({
    required this.pageIndex,
    required this.pageSize,
    this.filterByTags,
    this.filterByActive,
  });
}

class GetListAppUsageTagRulesQueryResponse extends PaginatedList<AppUsageTagRuleListItem> {
  GetListAppUsageTagRulesQueryResponse({
    required super.items,
    required super.pageIndex,
    required super.pageSize,
    required super.totalItemCount,
    required super.totalPageCount,
  });
}

class AppUsageTagRuleListItem {
  final String id;
  final String pattern;
  final String tagId;
  final String tagName;
  final String? tagColor;
  final String? description;
  final bool isActive;
  final DateTime createdDate;

  AppUsageTagRuleListItem({
    required this.id,
    required this.pattern,
    required this.tagId,
    required this.tagName,
    this.tagColor,
    this.description,
    required this.isActive,
    required this.createdDate,
  });
}

class GetListAppUsageTagRulesQueryHandler
    implements IRequestHandler<GetListAppUsageTagRulesQuery, GetListAppUsageTagRulesQueryResponse> {
  final IAppUsageTagRuleRepository _repository;
  final ITagRepository _tagRepository;

  GetListAppUsageTagRulesQueryHandler(
      {required IAppUsageTagRuleRepository appUsageRulesRepository, required ITagRepository tagRepository})
      : _repository = appUsageRulesRepository,
        _tagRepository = tagRepository;

  @override
  Future<GetListAppUsageTagRulesQueryResponse> call(GetListAppUsageTagRulesQuery request) async {
    CustomWhereFilter? whereFilter;

    // Filter by active status
    if (request.filterByActive != null) {
      whereFilter ??= CustomWhereFilter.empty();
      whereFilter.query += 'is_active = ?';
      whereFilter.variables.add(request.filterByActive! ? 1 : 0);
    }

    // Filter by tags
    if (request.filterByTags != null && request.filterByTags!.isNotEmpty) {
      whereFilter ??= CustomWhereFilter.empty();
      if (whereFilter.query.isNotEmpty) {
        whereFilter.query += ' AND ';
      }
      whereFilter.query += 'tag_id IN (${List.filled(request.filterByTags!.length, '?').join(',')})';
      whereFilter.variables.add(request.filterByTags!);
    }

    var result = await _repository.getList(
      request.pageIndex,
      request.pageSize,
      customWhereFilter: whereFilter,
    );

    Map<String, Tag> cachedTags = {};
    List<AppUsageTagRuleListItem> items = await Future.wait(result.items.map((rule) async {
      if (!cachedTags.containsKey(rule.tagId)) {
        Tag? tag = await _tagRepository.getById(rule.tagId);
        if (tag == null) throw Exception('Tag not found');

        cachedTags[rule.tagId] = tag;
      }

      return AppUsageTagRuleListItem(
        id: rule.id,
        pattern: rule.pattern,
        tagId: rule.tagId,
        tagName: cachedTags[rule.tagId]!.name,
        tagColor: cachedTags[rule.tagId]?.color,
        description: rule.description,
        isActive: rule.isActive,
        createdDate: rule.createdDate,
      );
    }).toList());

    return GetListAppUsageTagRulesQueryResponse(
      items: items,
      pageIndex: result.pageIndex,
      pageSize: result.pageSize,
      totalItemCount: result.totalItemCount,
      totalPageCount: result.totalPageCount,
    );
  }
}
