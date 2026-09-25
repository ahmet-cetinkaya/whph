import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/notes/commands/save_note_command.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_events.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_repository.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_tag_repository.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_transaction_service.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/domain/features/notes/note.dart';
import 'package:whph/core/domain/features/notes/note_tag.dart';

class SaveNoteWithTagsCommand implements IRequest<SaveNoteCommandResponse> {
  final String title;
  final String? content;
  final List<String> tagIds;
  final ApplicationMutationGuard? authorizeCommit;

  const SaveNoteWithTagsCommand({
    required this.title,
    this.content,
    this.tagIds = const [],
    this.authorizeCommit,
  });
}

class UpdateNoteWithTagsCommand implements IRequest<SaveNoteCommandResponse> {
  final String id;
  final DateTime expectedRevision;
  final String? title;
  final NoteContentUpdate content;
  final List<String>? tagIds;
  final Map<String, int>? tagOrder;
  final ApplicationMutationGuard? authorizeCommit;

  const UpdateNoteWithTagsCommand({
    required this.id,
    required this.expectedRevision,
    this.title,
    this.content = const NoteContentUpdate.unchanged(),
    this.tagIds,
    this.tagOrder,
    this.authorizeCommit,
  });
}

class ReorderNoteWithRevisionCommand implements IRequest<SaveNoteCommandResponse> {
  final String id;
  final DateTime expectedRevision;
  final String order;
  final ApplicationMutationGuard? authorizeCommit;

  const ReorderNoteWithRevisionCommand({
    required this.id,
    required this.expectedRevision,
    required this.order,
    this.authorizeCommit,
  });
}

class SaveNoteWithTagsCommandHandler implements IRequestHandler<SaveNoteWithTagsCommand, SaveNoteCommandResponse> {
  final INoteRepository _notes;
  final INoteTagRepository _noteTags;
  final ITagRepository _tags;
  final INoteEvents _events;
  final IApplicationTransactionService _transactions;

  SaveNoteWithTagsCommandHandler({
    required INoteRepository notes,
    required INoteTagRepository noteTags,
    required ITagRepository tags,
    required INoteEvents events,
    required IApplicationTransactionService transactions,
  })  : _notes = notes,
        _noteTags = noteTags,
        _tags = tags,
        _events = events,
        _transactions = transactions;

  @override
  Future<SaveNoteCommandResponse> call(SaveNoteWithTagsCommand request) async {
    final response = await _transactions.run(() async {
      await _requireTags(request.tagIds);
      final note = Note(
        id: KeyHelper.generateStringId(),
        createdDate: DateTime.now().toUtc(),
        title: request.title,
        content: request.content,
      );
      await _notes.add(note);
      await _replaceTags(note.id, const [], request.tagIds);
      await ensureMutationAuthorized(request.authorizeCommit);
      return SaveNoteCommandResponse(id: note.id, revision: _revision(note));
    });
    _events.notifyNoteCreated(response.id);
    return response;
  }

  Future<void> _requireTags(List<String> tagIds) async {
    final tags = await _tags.getByIds(tagIds);
    if (tags.length != tagIds.length) throw StateError('Tag not found');
  }

  Future<void> _replaceTags(String noteId, List<NoteTag> current, List<String> tagIds) async {
    final requested = tagIds.toSet();
    for (final relation in current.where((relation) => !requested.contains(relation.tagId))) {
      await _noteTags.delete(relation);
    }
    final existing = current.map((relation) => relation.tagId).toSet();
    for (var index = 0; index < tagIds.length; index++) {
      if (existing.contains(tagIds[index])) continue;
      await _noteTags.add(NoteTag(
        id: KeyHelper.generateStringId(),
        createdDate: DateTime.now().toUtc(),
        noteId: noteId,
        tagId: tagIds[index],
        tagOrder: index,
      ));
    }
  }

  DateTime _revision(Note note) => DateTime.fromMillisecondsSinceEpoch(
        ((note.modifiedDate ?? note.createdDate).millisecondsSinceEpoch ~/ 1000) * 1000,
        isUtc: true,
      );
}

class UpdateNoteWithTagsCommandHandler implements IRequestHandler<UpdateNoteWithTagsCommand, SaveNoteCommandResponse> {
  final INoteRepository _notes;
  final INoteTagRepository _noteTags;
  final ITagRepository _tags;
  final INoteEvents _events;
  final IApplicationTransactionService _transactions;

  UpdateNoteWithTagsCommandHandler({
    required INoteRepository notes,
    required INoteTagRepository noteTags,
    required ITagRepository tags,
    required INoteEvents events,
    required IApplicationTransactionService transactions,
  })  : _notes = notes,
        _noteTags = noteTags,
        _tags = tags,
        _events = events,
        _transactions = transactions;

  @override
  Future<SaveNoteCommandResponse> call(UpdateNoteWithTagsCommand request) async {
    final response = await _transactions.run(() async {
      final existing = await _notes.getById(request.id);
      if (existing == null) throw StateError('Note not found');
      if (request.tagIds != null) await _requireTags(request.tagIds!);
      final updated = Note(
        id: existing.id,
        createdDate: existing.createdDate,
        modifiedDate: existing.modifiedDate,
        title: request.title ?? existing.title,
        content: request.content.isChanged ? request.content.value : existing.content,
        order: existing.order,
        tags: List.unmodifiable(existing.tags),
      );
      final revision = await _notes.updateIfRevision(updated, request.expectedRevision);
      if (revision == null) throw NoteRevisionConflictException(request.id);
      final current = await _noteTags.getByNoteId(request.id);
      if (request.tagIds != null) await _replaceTags(request.id, current, request.tagIds!);
      final effectiveTagIds = request.tagIds?.toSet() ?? current.map((relation) => relation.tagId).toSet();
      if (request.tagOrder != null &&
          (!effectiveTagIds.containsAll(request.tagOrder!.keys) ||
              request.tagOrder!.values.any((order) => order < 0))) {
        throw ArgumentError.value(request.tagOrder, 'tagOrder');
      }
      if (request.tagOrder != null) await _noteTags.updateTagOrders(request.id, request.tagOrder!);
      await ensureMutationAuthorized(request.authorizeCommit);
      return SaveNoteCommandResponse(id: request.id, revision: revision);
    });
    _events.notifyNoteUpdated(request.id);
    return response;
  }

  Future<void> _requireTags(List<String> tagIds) async {
    if ((await _tags.getByIds(tagIds)).length != tagIds.length) throw StateError('Tag not found');
  }

  Future<void> _replaceTags(String noteId, List<NoteTag> current, List<String> tagIds) async {
    final requested = tagIds.toSet();
    for (final relation in current.where((relation) => !requested.contains(relation.tagId))) {
      await _noteTags.delete(relation);
    }
    final existing = current.map((relation) => relation.tagId).toSet();
    for (var index = 0; index < tagIds.length; index++) {
      if (existing.contains(tagIds[index])) continue;
      await _noteTags.add(NoteTag(
        id: KeyHelper.generateStringId(),
        createdDate: DateTime.now().toUtc(),
        noteId: noteId,
        tagId: tagIds[index],
        tagOrder: index,
      ));
    }
  }
}

class ReorderNoteWithRevisionCommandHandler
    implements IRequestHandler<ReorderNoteWithRevisionCommand, SaveNoteCommandResponse> {
  final INoteRepository _notes;
  final INoteEvents _events;
  final IApplicationTransactionService _transactions;

  ReorderNoteWithRevisionCommandHandler({
    required INoteRepository notes,
    required INoteEvents events,
    required IApplicationTransactionService transactions,
  })  : _notes = notes,
        _events = events,
        _transactions = transactions;

  @override
  Future<SaveNoteCommandResponse> call(ReorderNoteWithRevisionCommand request) async {
    final revision = await _transactions.run(() async {
      final existing = await _notes.getById(request.id);
      if (existing == null) throw StateError('Note not found');
      final updated = Note(
        id: existing.id,
        createdDate: existing.createdDate,
        modifiedDate: existing.modifiedDate,
        title: existing.title,
        content: existing.content,
        order: request.order,
        tags: List.unmodifiable(existing.tags),
      );
      final revision = await _notes.updateIfRevision(updated, request.expectedRevision);
      if (revision == null) throw NoteRevisionConflictException(request.id);
      await ensureMutationAuthorized(request.authorizeCommit);
      return revision;
    });
    _events.notifyNoteUpdated(request.id);
    return SaveNoteCommandResponse(id: request.id, revision: revision);
  }
}
