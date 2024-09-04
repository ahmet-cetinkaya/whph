import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/domain/features/tags/tag_tag.dart';

class AddTagTagCommand implements IRequest<AddTagTagCommandResponse> {
  int primaryTagId;
  int secondaryTagId;

  AddTagTagCommand({
    required this.primaryTagId,
    required this.secondaryTagId,
  });
}

class AddTagTagCommandResponse {
  final int id;

  AddTagTagCommandResponse({
    required this.id,
  });
}

class AddTagTagCommandHandler implements IRequestHandler<AddTagTagCommand, AddTagTagCommandResponse> {
  final ITagTagRepository _tagTagRepository;

  AddTagTagCommandHandler({required ITagTagRepository tagTagRepository}) : _tagTagRepository = tagTagRepository;

  @override
  Future<AddTagTagCommandResponse> call(AddTagTagCommand request) async {
    if (request.primaryTagId == request.secondaryTagId) {
      throw Exception('Primary tag and secondary tag cannot be the same');
    }
    if (await _tagTagRepository.anyByPrimaryAndSecondaryId(request.primaryTagId, request.secondaryTagId)) {
      throw Exception('Tag tag already exists');
    }

    var tagTag = TagTag(
      id: 0,
      createdDate: DateTime(0),
      primaryTagId: request.primaryTagId,
      secondaryTagId: request.secondaryTagId,
    );
    await _tagTagRepository.add(tagTag);

    return AddTagTagCommandResponse(
      id: tagTag.id,
    );
  }
}
