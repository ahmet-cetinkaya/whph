import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/tags/tag_tag.dart';
import 'package:whph/application/features/tags/constants/tag_translation_keys.dart';

class RemoveTagTagCommand implements IRequest<RemoveTagTagCommandResponse> {
  String id;

  RemoveTagTagCommand({
    required this.id,
  });
}

class RemoveTagTagCommandResponse {
  final String id;

  RemoveTagTagCommandResponse({
    required this.id,
  });
}

class RemoveTagTagCommandHandler implements IRequestHandler<RemoveTagTagCommand, RemoveTagTagCommandResponse> {
  final ITagTagRepository _tagTagRepository;

  RemoveTagTagCommandHandler({required ITagTagRepository tagTagRepository}) : _tagTagRepository = tagTagRepository;

  @override
  Future<RemoveTagTagCommandResponse> call(RemoveTagTagCommand request) async {
    TagTag? tagTag = await _tagTagRepository.getById(request.id);
    if (tagTag == null) {
      throw BusinessException(TagTranslationKeys.tagTagNotFoundError);
    }
    await _tagTagRepository.delete(tagTag);

    return RemoveTagTagCommandResponse(
      id: tagTag.id,
    );
  }
}
