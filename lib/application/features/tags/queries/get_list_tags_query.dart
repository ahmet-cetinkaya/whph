import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/tags/tag.dart';

class GetListTagsQuery implements IRequest<GetListTagsQueryResponse> {
  String? search;
  late int pageIndex;
  late int pageSize;

  GetListTagsQuery({required this.pageIndex, required this.pageSize, this.search});
}

class TagListItem {
  String id;
  String name;

  TagListItem({required this.id, required this.name});
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
    PaginatedList<Tag> tags = await _tagRepository.getListBySearch(
      request.search,
      request.pageIndex,
      request.pageSize,
    );

    return GetListTagsQueryResponse(
      items: tags.items.map((e) => TagListItem(id: e.id, name: e.name)).toList(),
      totalItemCount: tags.totalItemCount,
      totalPageCount: tags.totalPageCount,
      pageIndex: tags.pageIndex,
      pageSize: tags.pageSize,
    );
  }
}
