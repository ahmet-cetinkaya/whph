import 'package:mediatr/mediatr.dart';
import 'package:application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:acore/acore.dart';
import 'package:domain/features/tags/tag.dart';
import 'package:domain/features/tags/tag_tag.dart';

class GetListTagTagsQuery implements IRequest<GetListTagTagsQueryResponse> {
  late String primaryTagId;
  late int pageIndex;
  late int pageSize;

  GetListTagTagsQuery({required this.primaryTagId, required this.pageIndex, required this.pageSize});
}

class TagTagListItem {
  String id;
  String primaryTagId;
  String primaryTagName;
  String? primaryTagColor;
  String secondaryTagId;
  String secondaryTagName;
  String? secondaryTagColor;

  TagTagListItem(
      {required this.id,
      required this.primaryTagId,
      required this.primaryTagName,
      this.primaryTagColor,
      required this.secondaryTagId,
      required this.secondaryTagName,
      this.secondaryTagColor});
}

class GetListTagTagsQueryResponse extends PaginatedList<TagTagListItem> {
  GetListTagTagsQueryResponse(
      {required super.items, required super.totalItemCount, required super.pageIndex, required super.pageSize});
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

    // Get all unique tag IDs and fetch them in batch to avoid N+1 problem
    final allTagIds = <String>{};
    for (final tagTag in tagTags.items) {
      allTagIds.add(tagTag.primaryTagId);
      allTagIds.add(tagTag.secondaryTagId);
    }
    final tagsMap = await _tagRepository.getByIds(allTagIds.toList());

    List<TagTagListItem> listItems = [];
    for (final tagTag in tagTags.items) {
      Tag primaryTag = tagsMap[tagTag.primaryTagId]!;
      Tag secondaryTag = tagsMap[tagTag.secondaryTagId]!;
      listItems.add(TagTagListItem(
        id: tagTag.id,
        primaryTagId: tagTag.primaryTagId,
        primaryTagName: primaryTag.name,
        primaryTagColor: primaryTag.color,
        secondaryTagId: tagTag.secondaryTagId,
        secondaryTagName: secondaryTag.name,
        secondaryTagColor: secondaryTag.color,
      ));
    }
    return GetListTagTagsQueryResponse(
      items: listItems,
      totalItemCount: tagTags.totalItemCount,
      pageIndex: tagTags.pageIndex,
      pageSize: tagTags.pageSize,
    );
  }
}
