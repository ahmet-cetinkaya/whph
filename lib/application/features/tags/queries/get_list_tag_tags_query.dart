import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/tags/tag.dart';
import 'package:whph/domain/features/tags/tag_tag.dart';

class GetListTagTagsQuery implements IRequest<GetListTagTagsQueryResponse> {
  late String primaryTagId;
  late int pageIndex;
  late int pageSize;

  GetListTagTagsQuery({required this.primaryTagId, required this.pageIndex, required this.pageSize});
}

class TagTagListItem {
  String id;
  String secondaryTagName;

  TagTagListItem({required this.id, required this.secondaryTagName});
}

class GetListTagTagsQueryResponse extends PaginatedList<TagTagListItem> {
  GetListTagTagsQueryResponse(
      {required super.items,
      required super.totalItemCount,
      required super.totalPageCount,
      required super.pageIndex,
      required super.pageSize});
}

class GetListTagTagsQueryHandler implements IRequestHandler<GetListTagTagsQuery, GetListTagTagsQueryResponse> {
  late final ITagRepository _tagRepository;
  late final ITagTagRepository _tagTagRepository;

  GetListTagTagsQueryHandler({required ITagRepository tagRepository, required ITagTagRepository tagTagRepository})
      : _tagRepository = tagRepository,
        _tagTagRepository = tagTagRepository;

  @override
  Future<GetListTagTagsQueryResponse> call(GetListTagTagsQuery request) async {
    PaginatedList<TagTag> tagTags = await _tagTagRepository.getListByPrimaryTagId(
      request.primaryTagId,
      request.pageIndex,
      request.pageSize,
    );

    List<TagTagListItem> listItems = [];
    for (var tagTag in tagTags.items) {
      Tag secondaryTag = (await _tagRepository.getById(tagTag.secondaryTagId))!;
      listItems.add(TagTagListItem(
        id: tagTag.id,
        secondaryTagName: secondaryTag.name,
      ));
    }
    return GetListTagTagsQueryResponse(
      items: listItems,
      totalItemCount: tagTags.totalItemCount,
      totalPageCount: tagTags.totalPageCount,
      pageIndex: tagTags.pageIndex,
      pageSize: tagTags.pageSize,
    );
  }
}
