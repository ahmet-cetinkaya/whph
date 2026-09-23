import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_events.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_tag_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/core/application/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/core/application/features/tags/commands/update_tag_command.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_transaction_service.dart';

class DeleteTagCommand implements IRequest<DeleteTagCommandResponse> {
  final String id;
  final DateTime? expectedRevision;
  final ApplicationMutationGuard? authorizeCommit;

  DeleteTagCommand(
      {required this.id, this.expectedRevision, this.authorizeCommit});
}

class DeleteTagCommandResponse {}

class DeleteTagCommandHandler
    implements IRequestHandler<DeleteTagCommand, DeleteTagCommandResponse> {
  final ITagRepository _tagRepository;
  final ITagTagRepository _tagTagRepository;
  final ITaskTagRepository _taskTagRepository;
  final IHabitTagsRepository _habitTagsRepository;
  final INoteTagRepository _noteTagRepository;
  final IAppUsageTagRepository _appUsageTagRepository;
  final ITagEvents? _tagEvents;
  final IApplicationTransactionService _transactions;

  DeleteTagCommandHandler({
    required ITagRepository tagRepository,
    required ITagTagRepository tagTagRepository,
    required ITaskTagRepository taskTagRepository,
    required IHabitTagsRepository habitTagsRepository,
    required INoteTagRepository noteTagRepository,
    required IAppUsageTagRepository appUsageTagRepository,
    ITagEvents? tagEvents,
    required IApplicationTransactionService transactions,
  })  : _tagRepository = tagRepository,
        _tagTagRepository = tagTagRepository,
        _taskTagRepository = taskTagRepository,
        _habitTagsRepository = habitTagsRepository,
        _noteTagRepository = noteTagRepository,
        _appUsageTagRepository = appUsageTagRepository,
        _tagEvents = tagEvents,
        _transactions = transactions;

  @override
  Future<DeleteTagCommandResponse> call(DeleteTagCommand request) async {
    Tag? tag = await _tagRepository.getById(request.id);
    if (tag == null) {
      throw BusinessException(
          'Tag not found', TagTranslationKeys.tagNotFoundError);
    }

    await _transactions.run(() async {
      await _deleteRelatedEntities(request.id);
      if (request.expectedRevision == null) {
        await _tagRepository.delete(tag);
      } else if (!await _tagRepository.deleteIfRevision(
          tag.id, request.expectedRevision!)) {
        throw TagRevisionConflictException(tag.id);
      }
      await ensureMutationAuthorized(request.authorizeCommit);
    });
    _tagEvents?.notifyTagDeleted(tag.id);

    return DeleteTagCommandResponse();
  }

  /// Deletes all entities related to the tag
  Future<void> _deleteRelatedEntities(String tagId) async {
    // Delete tag-tag relationships where this tag is primary
    final primaryTagTags = await _tagTagRepository.getByPrimaryTagId(tagId);
    for (final tagTag in primaryTagTags) {
      await _tagTagRepository.delete(tagTag);
    }

    // Delete tag-tag relationships where this tag is secondary
    final secondaryTagTags = await _tagTagRepository.getBySecondaryTagId(tagId);
    for (final tagTag in secondaryTagTags) {
      await _tagTagRepository.delete(tagTag);
    }

    // Delete task tags
    final taskTags = await _taskTagRepository.getByTagId(tagId);
    for (final taskTag in taskTags) {
      await _taskTagRepository.delete(taskTag);
    }

    // Delete habit tags
    final habitTags = await _habitTagsRepository.getByTagId(tagId);
    for (final habitTag in habitTags) {
      await _habitTagsRepository.delete(habitTag);
    }

    // Delete note tags
    final noteTags = await _noteTagRepository.getByTagId(tagId);
    for (final noteTag in noteTags) {
      await _noteTagRepository.delete(noteTag);
    }

    // Delete app usage tags
    // Note: We need to get all app usage tags that reference this tag
    // Since there's no direct getByTagId method, we'll use a custom filter
    final appUsageTags = await _appUsageTagRepository.getAll(
      customWhereFilter: CustomWhereFilter('tag_id = ?', [tagId]),
    );
    for (final appUsageTag in appUsageTags) {
      await _appUsageTagRepository.delete(appUsageTag);
    }
  }
}
