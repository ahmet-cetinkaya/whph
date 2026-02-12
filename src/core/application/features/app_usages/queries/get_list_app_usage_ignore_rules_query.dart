import 'package:mediatr/mediatr.dart';
import 'package:application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:acore/acore.dart';

class GetListAppUsageIgnoreRulesQuery implements IRequest<GetListAppUsageIgnoreRulesQueryResponse> {
  final int pageIndex;
  final int pageSize;

  GetListAppUsageIgnoreRulesQuery({
    required this.pageIndex,
    required this.pageSize,
  });
}

class GetListAppUsageIgnoreRulesQueryResponse extends PaginatedList<AppUsageIgnoreRuleListItem> {
  GetListAppUsageIgnoreRulesQueryResponse({
    required super.items,
    required super.pageIndex,
    required super.pageSize,
    required super.totalItemCount,
  });
}

class AppUsageIgnoreRuleListItem {
  final String id;
  final String pattern;
  final String? description;
  final DateTime createdDate;

  AppUsageIgnoreRuleListItem({
    required this.id,
    required this.pattern,
    this.description,
    required this.createdDate,
  });
}

class GetListAppUsageIgnoreRulesQueryHandler
    implements IRequestHandler<GetListAppUsageIgnoreRulesQuery, GetListAppUsageIgnoreRulesQueryResponse> {
  final IAppUsageIgnoreRuleRepository _repository;

  GetListAppUsageIgnoreRulesQueryHandler({required IAppUsageIgnoreRuleRepository repository})
      : _repository = repository;

  @override
  Future<GetListAppUsageIgnoreRulesQueryResponse> call(GetListAppUsageIgnoreRulesQuery request) async {
    final result = await _repository.getList(
      request.pageIndex,
      request.pageSize,
    );

    List<AppUsageIgnoreRuleListItem> items = result.items
        .map((rule) => AppUsageIgnoreRuleListItem(
              id: rule.id,
              pattern: rule.pattern,
              description: rule.description,
              createdDate: rule.createdDate,
            ))
        .toList();

    return GetListAppUsageIgnoreRulesQueryResponse(
      items: items,
      pageIndex: result.pageIndex,
      pageSize: result.pageSize,
      totalItemCount: result.totalItemCount,
    );
  }
}
