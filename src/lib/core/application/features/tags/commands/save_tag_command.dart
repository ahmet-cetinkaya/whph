import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_events.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/core/application/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_transaction_service.dart';

class SaveTagCommand implements IRequest<SaveTagCommandResponse> {
  final String? id;
  final String name;
  final bool isArchived;
  final String? color;
  final TagType type;
  final ApplicationMutationGuard? authorizeCommit;

  SaveTagCommand({
    this.id,
    required this.name,
    this.isArchived = false,
    this.color,
    this.type = TagType.label,
    this.authorizeCommit,
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
  final ITagEvents? _tagEvents;
  final IApplicationTransactionService? _transactions;

  SaveTagCommandHandler({
    required ITagRepository tagRepository,
    ITagEvents? tagEvents,
    IApplicationTransactionService? transactions,
  })  : _tagRepository = tagRepository,
        _tagEvents = tagEvents,
        _transactions = transactions;

  @override
  Future<SaveTagCommandResponse> call(SaveTagCommand request) async {
    final isCreating = request.id == null;
    Future<Tag> operation() async {
      final existing = request.id == null ? null : await _tagRepository.getById(request.id!);
      if (request.id != null && existing == null) {
        throw BusinessException('Tag not found', TagTranslationKeys.tagNotFoundError);
      }
      final tag = Tag(
        id: existing?.id ?? KeyHelper.generateStringId(),
        createdDate: existing?.createdDate ?? DateTime.now().toUtc(),
        modifiedDate: existing?.modifiedDate,
        deletedDate: existing?.deletedDate,
        name: request.name,
        isArchived: request.isArchived,
        color: request.color,
        type: request.type,
      );
      if (existing == null) {
        await _tagRepository.add(tag);
      } else {
        await _tagRepository.update(tag);
      }
      await ensureMutationAuthorized(request.authorizeCommit);
      return tag;
    }

    if (request.authorizeCommit != null && _transactions == null) {
      throw StateError('A transaction service is required for guarded writes');
    }
    final tag = _transactions == null ? await operation() : await _transactions.run(operation);

    if (isCreating) {
      _tagEvents?.notifyTagCreated(tag.id);
    } else {
      _tagEvents?.notifyTagUpdated(tag.id);
    }
    return SaveTagCommandResponse(
      id: tag.id,
      createdDate: tag.createdDate,
      modifiedDate: tag.modifiedDate,
    );
  }
}
