import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/domain/features/tags/tag.dart';

class GetTagQuery implements IRequest<GetTagQueryResponse> {
  late int id;

  GetTagQuery({required this.id});
}

class TagTagListItem {
  late int id;
  late String name;

  TagTagListItem({
    required this.id,
    required this.name,
  });
}

class GetTagQueryResponse extends Tag {
  GetTagQueryResponse({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    required super.name,
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
      throw Exception('Tag with id ${request.id} not found');
    }

    return GetTagQueryResponse(
      id: tags.id,
      createdDate: tags.createdDate,
      modifiedDate: tags.modifiedDate,
      name: tags.name,
    );
  }
}
