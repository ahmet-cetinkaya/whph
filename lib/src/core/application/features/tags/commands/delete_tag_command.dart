import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/corePackages/acore/errors/business_exception.dart';
import 'package:whph/src/core/domain/features/tags/tag.dart';
import 'package:whph/src/core/application/features/tags/constants/tag_translation_keys.dart';

class DeleteTagCommand implements IRequest<DeleteTagCommandResponse> {
  final String id;

  DeleteTagCommand({required this.id});
}

class DeleteTagCommandResponse {}

class DeleteTagCommandHandler implements IRequestHandler<DeleteTagCommand, DeleteTagCommandResponse> {
  final ITagRepository _tagRepository;

  DeleteTagCommandHandler({required ITagRepository tagRepository}) : _tagRepository = tagRepository;

  @override
  Future<DeleteTagCommandResponse> call(DeleteTagCommand request) async {
    Tag? tag = await _tagRepository.getById(request.id);
    if (tag == null) {
      throw BusinessException('Tag not found', TagTranslationKeys.tagNotFoundError);
    }

    await _tagRepository.delete(tag);

    return DeleteTagCommandResponse();
  }
}
