import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tags/commands/update_tag_command.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_events.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_transaction_service.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/core/domain/features/tags/tag_tag.dart';

class SetTagRelationshipsCommand
    implements IRequest<SetTagRelationshipsCommandResponse> {
  final String tagId;
  final DateTime expectedRevision;
  final List<String> relatedTagIds;
  final ApplicationMutationGuard? authorizeCommit;

  SetTagRelationshipsCommand({
    required this.tagId,
    required this.expectedRevision,
    required List<String> relatedTagIds,
    this.authorizeCommit,
  }) : relatedTagIds = List.unmodifiable(relatedTagIds);
}

class SetTagRelationshipsCommandResponse {
  final String tagId;
  final List<String> relatedTagIds;
  final DateTime revision;

  SetTagRelationshipsCommandResponse({
    required this.tagId,
    required List<String> relatedTagIds,
    required this.revision,
  }) : relatedTagIds = List.unmodifiable(relatedTagIds);
}

class TagRelationshipCycleException implements Exception {
  const TagRelationshipCycleException();
}

class SetTagRelationshipsCommandHandler
    implements
        IRequestHandler<SetTagRelationshipsCommand,
            SetTagRelationshipsCommandResponse> {
  final ITagRepository _tags;
  final ITagTagRepository _relationships;
  final ITagEvents _events;
  final IApplicationTransactionService _transactions;

  SetTagRelationshipsCommandHandler({
    required ITagRepository tags,
    required ITagTagRepository relationships,
    required ITagEvents events,
    required IApplicationTransactionService transactions,
  })  : _tags = tags,
        _relationships = relationships,
        _events = events,
        _transactions = transactions;

  @override
  Future<SetTagRelationshipsCommandResponse> call(
      SetTagRelationshipsCommand request) async {
    final response = await _transactions.run(() async {
      if (request.relatedTagIds.contains(request.tagId))
        throw const TagRelationshipCycleException();
      final tag = await _tags.getById(request.tagId);
      if (tag == null) throw StateError('Tag not found');
      if ((await _tags.getByIds(request.relatedTagIds)).length !=
          request.relatedTagIds.length) {
        throw StateError('Related tag not found');
      }
      for (final relatedId in request.relatedTagIds) {
        if (await _reaches(relatedId, request.tagId, <String>{})) {
          throw const TagRelationshipCycleException();
        }
      }
      final touched = Tag(
        id: tag.id,
        createdDate: tag.createdDate,
        modifiedDate: tag.modifiedDate,
        name: tag.name,
        color: tag.color,
        type: tag.type,
        isArchived: tag.isArchived,
      );
      final revision =
          await _tags.updateIfRevision(touched, request.expectedRevision);
      if (revision == null) {
        throw TagRevisionConflictException(request.tagId);
      }
      final current = await _relationships.getByPrimaryTagId(request.tagId);
      final requested = request.relatedTagIds.toSet();
      for (final relation in current
          .where((relation) => !requested.contains(relation.secondaryTagId))) {
        await _relationships.delete(relation);
      }
      final existing =
          current.map((relation) => relation.secondaryTagId).toSet();
      for (final relatedId
          in request.relatedTagIds.where((id) => !existing.contains(id))) {
        await _relationships.add(TagTag(
          id: KeyHelper.generateStringId(),
          createdDate: DateTime.now().toUtc(),
          primaryTagId: request.tagId,
          secondaryTagId: relatedId,
        ));
      }
      await ensureMutationAuthorized(request.authorizeCommit);
      final canonicalRelatedTagIds = requested.toList()..sort();
      return SetTagRelationshipsCommandResponse(
        tagId: request.tagId,
        relatedTagIds: canonicalRelatedTagIds,
        revision: revision,
      );
    });
    _events.notifyTagUpdated(request.tagId);
    return response;
  }

  Future<bool> _reaches(
      String currentId, String targetId, Set<String> visited) async {
    if (currentId == targetId) return true;
    if (!visited.add(currentId)) return false;
    final related = await _relationships.getByPrimaryTagId(currentId);
    for (final relation in related) {
      if (await _reaches(relation.secondaryTagId, targetId, visited))
        return true;
    }
    return false;
  }
}
