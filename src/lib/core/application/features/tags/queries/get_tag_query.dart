import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/core/application/features/tags/constants/tag_translation_keys.dart';

class GetTagQuery implements IRequest<GetTagQueryResponse> {
  late String id;

  GetTagQuery({required this.id});
}

class GetTagQueryResponse extends Tag {
  GetTagQueryResponse({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required super.name,
    super.isArchived = false,
    super.color,
  });
}

class GetTagQueryHandler implements IRequestHandler<GetTagQuery, GetTagQueryResponse> {
  late final ITagRepository _tagRepository;

  GetTagQueryHandler({required ITagRepository tagRepository}) : _tagRepository = tagRepository;

  @override
  Future<GetTagQueryResponse> call(GetTagQuery request) async {
    Tag? tags = await _tagRepository.getById(
      request.id,
    );
    if (tags == null) {
      throw BusinessException('Tag not found', TagTranslationKeys.tagNotFoundError);
    }

    return GetTagQueryResponse(
      id: tags.id,
      name: tags.name,
      isArchived: tags.isArchived,
      createdDate: tags.createdDate,
      modifiedDate: tags.modifiedDate,
      color: tags.color,
    );
  }
}
