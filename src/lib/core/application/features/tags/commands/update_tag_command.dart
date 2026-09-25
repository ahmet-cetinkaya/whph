import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/notes/commands/save_note_command.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_events.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_transaction_service.dart';

class UpdateTagCommand implements IRequest<UpdateTagCommandResponse> {
  final String id;
  final DateTime expectedRevision;
  final String? name;
  final NoteContentUpdate color;
  final TagType? type;
  final bool? isArchived;
  final ApplicationMutationGuard? authorizeCommit;

  const UpdateTagCommand({
    required this.id,
    required this.expectedRevision,
    this.name,
    this.color = const NoteContentUpdate.unchanged(),
    this.type,
    this.isArchived,
    this.authorizeCommit,
  });
}

class UpdateTagCommandResponse {
  final String id;
  final DateTime revision;

  const UpdateTagCommandResponse({required this.id, required this.revision});
}

class TagRevisionConflictException implements Exception {
  final String tagId;

  const TagRevisionConflictException(this.tagId);
}

class UpdateTagCommandHandler implements IRequestHandler<UpdateTagCommand, UpdateTagCommandResponse> {
  final ITagRepository _tags;
  final ITagEvents _events;
  final IApplicationTransactionService _transactions;

  UpdateTagCommandHandler({
    required ITagRepository tags,
    required ITagEvents events,
    required IApplicationTransactionService transactions,
  })  : _tags = tags,
        _events = events,
        _transactions = transactions;

  @override
  Future<UpdateTagCommandResponse> call(UpdateTagCommand request) async {
    final revision = await _transactions.run(() async {
      final existing = await _tags.getById(request.id);
      if (existing == null) throw StateError('Tag not found');
      final updated = Tag(
        id: existing.id,
        createdDate: existing.createdDate,
        modifiedDate: existing.modifiedDate,
        name: request.name ?? existing.name,
        color: request.color.isChanged ? request.color.value : existing.color,
        type: request.type ?? existing.type,
        isArchived: request.isArchived ?? existing.isArchived,
      );
      final revision = await _tags.updateIfRevision(updated, request.expectedRevision);
      if (revision == null) throw TagRevisionConflictException(request.id);
      await ensureMutationAuthorized(request.authorizeCommit);
      return revision;
    });
    _events.notifyTagUpdated(request.id);
    return UpdateTagCommandResponse(id: request.id, revision: revision);
  }
}
