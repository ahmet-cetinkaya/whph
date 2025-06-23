import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/src/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/core/domain/features/tags/tag.dart';
import 'package:whph/src/core/application/features/app_usages/constants/app_usage_translation_keys.dart';

class GetListAppUsageTagRulesQuery implements IRequest<GetListAppUsageTagRulesQueryResponse> {
  final int pageIndex;
  final int pageSize;
  final List<String>? filterByTags;

  GetListAppUsageTagRulesQuery({
    required this.pageIndex,
    required this.pageSize,
    this.filterByTags,
  });
}

class GetListAppUsageTagRulesQueryResponse extends PaginatedList<AppUsageTagRuleListItem> {
  GetListAppUsageTagRulesQueryResponse({
    required super.items,
    required super.pageIndex,
    required super.pageSize,
    required super.totalItemCount,
  });
}

class AppUsageTagRuleListItem {
  final String id;
  final String pattern;
  final String tagId;
  final String tagName;
  final String? tagColor;
  final String? description;
  final DateTime createdDate;

  AppUsageTagRuleListItem({
    required this.id,
    required this.pattern,
    required this.tagId,
    required this.tagName,
    this.tagColor,
    this.description,
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

    // Filter by tags
    if (request.filterByTags != null && request.filterByTags!.isNotEmpty) {
      whereFilter ??= CustomWhereFilter.empty();
      if (whereFilter.query.isNotEmpty) {
        whereFilter.query += ' AND ';
      }
      whereFilter.query += 'tag_id IN (${List.filled(request.filterByTags!.length, '?').join(',')})';
      whereFilter.variables.add(request.filterByTags!);
    }

    final result = await _repository.getList(
      request.pageIndex,
      request.pageSize,
      customWhereFilter: whereFilter,
    );

    Map<String, Tag> cachedTags = {};
    List<AppUsageTagRuleListItem> items = await Future.wait(result.items.map((rule) async {
      if (!cachedTags.containsKey(rule.tagId)) {
        Tag? tag = await _tagRepository.getById(rule.tagId);
        if (tag == null) {
          throw BusinessException(
              'Tag not found for app usage tag rule', AppUsageTranslationKeys.appUsageTagRuleNotFoundError);
        }

        cachedTags[rule.tagId] = tag;
      }

      return AppUsageTagRuleListItem(
        id: rule.id,
        pattern: rule.pattern,
        tagId: rule.tagId,
        tagName: cachedTags[rule.tagId]!.name,
        tagColor: cachedTags[rule.tagId]?.color,
        description: rule.description,
        createdDate: rule.createdDate,
      );
    }).toList());

    return GetListAppUsageTagRulesQueryResponse(
      items: items,
      pageIndex: result.pageIndex,
      pageSize: result.pageSize,
      totalItemCount: result.totalItemCount,
    );
  }
}
