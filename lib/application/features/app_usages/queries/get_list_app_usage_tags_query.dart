import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/domain/features/tags/tag.dart';

class GetListAppUsageTagsQuery implements IRequest<GetListAppUsageTagsQueryResponse> {
  late String appUsageId;
  late int pageIndex;
  late int pageSize;

  GetListAppUsageTagsQuery({required this.appUsageId, required this.pageIndex, required this.pageSize});
}

class AppUsageTagListItem {
  String id;
  String appUsageId;
  String tagId;
  String tagName;
  String? tagColor;

  AppUsageTagListItem(
      {required this.id, required this.appUsageId, required this.tagId, required this.tagName, this.tagColor});
}

class GetListAppUsageTagsQueryResponse extends PaginatedList<AppUsageTagListItem> {
  GetListAppUsageTagsQueryResponse(
      {required super.items,
      required super.totalItemCount,
      required super.totalPageCount,
      required super.pageIndex,
      required super.pageSize});
}

class GetListAppUsageTagsQueryHandler
    implements IRequestHandler<GetListAppUsageTagsQuery, GetListAppUsageTagsQueryResponse> {
  late final ITagRepository _tagRepository;
  late final IAppUsageTagRepository _appUsageTagRepository;

  GetListAppUsageTagsQueryHandler(
      {required ITagRepository tagRepository, required IAppUsageTagRepository appUsageTagRepository})
      : _tagRepository = tagRepository,
        _appUsageTagRepository = appUsageTagRepository;

  @override
  Future<GetListAppUsageTagsQueryResponse> call(GetListAppUsageTagsQuery request) async {
    PaginatedList<AppUsageTag> appUsageTags = await _appUsageTagRepository.getListByAppUsageId(
      request.appUsageId,
      request.pageIndex,
      request.pageSize,
    );

    List<AppUsageTagListItem> listItems = [];
    for (final appUsageTag in appUsageTags.items) {
      Tag secondaryTag = (await _tagRepository.getById(appUsageTag.tagId))!;
      listItems.add(AppUsageTagListItem(
        id: appUsageTag.id,
        appUsageId: appUsageTag.appUsageId,
        tagId: appUsageTag.tagId,
        tagName: secondaryTag.name,
        tagColor: secondaryTag.color,
      ));
    }
    return GetListAppUsageTagsQueryResponse(
      items: listItems,
      totalItemCount: appUsageTags.totalItemCount,
      totalPageCount: appUsageTags.totalPageCount,
      pageIndex: appUsageTags.pageIndex,
      pageSize: appUsageTags.pageSize,
    );
  }
}
