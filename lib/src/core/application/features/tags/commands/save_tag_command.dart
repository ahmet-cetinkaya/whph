import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/shared/utils/key_helper.dart';
import 'package:whph/src/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/core/domain/features/tags/tag.dart';
import 'package:whph/src/core/application/features/tags/constants/tag_translation_keys.dart';

class SaveTagCommand implements IRequest<SaveTagCommandResponse> {
  final String? id;
  final String name;
  final bool isArchived;
  final String? color;

  SaveTagCommand({
    this.id,
    required this.name,
    this.isArchived = false,
    this.color,
  });
}

class SaveTagCommandResponse {
  final String id;
  final DateTime createdDate;
  final DateTime? modifiedDate;

  SaveTagCommandResponse({
    required this.id,
    required this.createdDate,
    this.modifiedDate,
  });
}

class SaveTagCommandHandler implements IRequestHandler<SaveTagCommand, SaveTagCommandResponse> {
  final ITagRepository _tagRepository;

  SaveTagCommandHandler({required ITagRepository tagRepository}) : _tagRepository = tagRepository;

  @override
  Future<SaveTagCommandResponse> call(SaveTagCommand request) async {
    Tag? tag;

    if (request.id != null) {
      tag = await _tagRepository.getById(request.id!);
      if (tag == null) {
        throw BusinessException('Tag not found', TagTranslationKeys.tagNotFoundError);
      }

      tag.name = request.name;
      tag.isArchived = request.isArchived;
      tag.color = request.color;
      await _tagRepository.update(tag);
    } else {
      tag = Tag(
        id: KeyHelper.generateStringId(),
        createdDate: DateTime.now().toUtc(),
        name: request.name,
        isArchived: request.isArchived,
        color: request.color,
      );
      await _tagRepository.add(tag);
    }

    return SaveTagCommandResponse(
      id: tag.id,
      createdDate: tag.createdDate,
      modifiedDate: tag.modifiedDate,
    );
  }
}
