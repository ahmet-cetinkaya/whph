import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/habits/habit_tag.dart';
import 'package:whph/domain/features/tags/tag.dart';

class GetListHabitTagsQuery implements IRequest<GetListHabitTagsQueryResponse> {
  late String habitId;
  late int pageIndex;
  late int pageSize;

  GetListHabitTagsQuery({required this.habitId, required this.pageIndex, required this.pageSize});
}

class HabitTagListItem {
  String id;
  String habitId;
  String tagId;
  String tagName;
  String? tagColor;

  HabitTagListItem(
      {required this.id, required this.habitId, required this.tagId, required this.tagName, this.tagColor});
}

class GetListHabitTagsQueryResponse extends PaginatedList<HabitTagListItem> {
  GetListHabitTagsQueryResponse(
      {required super.items, required super.totalItemCount, required super.pageIndex, required super.pageSize});
}

class GetListHabitTagsQueryHandler implements IRequestHandler<GetListHabitTagsQuery, GetListHabitTagsQueryResponse> {
  late final ITagRepository _tagRepository;
  late final IHabitTagsRepository _habitTagRepository;

  GetListHabitTagsQueryHandler(
      {required ITagRepository tagRepository, required IHabitTagsRepository habitTagRepository})
      : _tagRepository = tagRepository,
        _habitTagRepository = habitTagRepository;

  @override
  Future<GetListHabitTagsQueryResponse> call(GetListHabitTagsQuery request) async {
    PaginatedList<HabitTag> habitTags = await _habitTagRepository.getList(request.pageIndex, request.pageSize,
        customWhereFilter: CustomWhereFilter("habit_id = ?", [request.habitId]));

    List<HabitTagListItem> listItems = [];
    for (final habitTag in habitTags.items) {
      Tag secondaryTag = (await _tagRepository.getById(habitTag.tagId))!;
      listItems.add(HabitTagListItem(
        id: habitTag.id,
        habitId: habitTag.habitId,
        tagId: habitTag.tagId,
        tagName: secondaryTag.name,
        tagColor: secondaryTag.color,
      ));
    }
    return GetListHabitTagsQueryResponse(
      items: listItems,
      totalItemCount: habitTags.totalItemCount,
      pageIndex: habitTags.pageIndex,
      pageSize: habitTags.pageSize,
    );
  }
}
