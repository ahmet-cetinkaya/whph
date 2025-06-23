import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/shared/utils/key_helper.dart';
import 'package:whph/src/core/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/core/domain/features/tags/tag_tag.dart';
import 'package:whph/src/core/application/features/tags/constants/tag_translation_keys.dart';

class AddTagTagCommand implements IRequest<AddTagTagCommandResponse> {
  String primaryTagId;
  String secondaryTagId;

  AddTagTagCommand({
    required this.primaryTagId,
    required this.secondaryTagId,
  });
}

class AddTagTagCommandResponse {
  final String id;

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
      throw BusinessException('Cannot tag the same tag', TagTranslationKeys.sameTagError);
    }
    if (await _tagTagRepository.anyByPrimaryAndSecondaryId(request.primaryTagId, request.secondaryTagId)) {
      throw BusinessException('Tag tag already exists', TagTranslationKeys.tagTagAlreadyExistsError);
    }

    final tagTag = TagTag(
      id: KeyHelper.generateStringId(),
      createdDate: DateTime.now().toUtc(),
      primaryTagId: request.primaryTagId,
      secondaryTagId: request.secondaryTagId,
    );
    await _tagTagRepository.add(tagTag);

    return AddTagTagCommandResponse(
      id: tagTag.id,
    );
  }
}
