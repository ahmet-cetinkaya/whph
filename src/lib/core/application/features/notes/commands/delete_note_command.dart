import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/notes/commands/save_note_command.dart';
import 'package:whph/core/application/features/notes/constants/note_translation_keys.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_repository.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_tag_repository.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_events.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_transaction_service.dart';
import 'package:acore/acore.dart';

class DeleteNoteCommand implements IRequest<DeleteNoteCommandResponse> {
  final String id;
  final DateTime? expectedRevision;
  final ApplicationMutationGuard? authorizeCommit;

  DeleteNoteCommand({
    required this.id,
    this.expectedRevision,
    this.authorizeCommit,
  });
}

class DeleteNoteCommandResponse {}

class DeleteNoteCommandHandler
    implements IRequestHandler<DeleteNoteCommand, DeleteNoteCommandResponse> {
  final INoteRepository _noteRepository;
  final INoteTagRepository _noteTagRepository;
  final INoteEvents _noteEvents;
  final IApplicationTransactionService _transactions;

  DeleteNoteCommandHandler({
    required INoteRepository noteRepository,
    required INoteTagRepository noteTagRepository,
    required INoteEvents noteEvents,
    required IApplicationTransactionService transactions,
  })  : _noteRepository = noteRepository,
        _noteTagRepository = noteTagRepository,
        _noteEvents = noteEvents,
        _transactions = transactions;

  @override
  Future<DeleteNoteCommandResponse> call(DeleteNoteCommand request) async {
    final note = await _noteRepository.getById(request.id);

    if (note == null) {
      throw BusinessException(
          'Note not found', NoteTranslationKeys.noteNotFound);
    }

    await _transactions.run(() async {
      final noteTags = await _noteTagRepository.getByNoteId(request.id);
      for (final noteTag in noteTags) {
        await _noteTagRepository.delete(noteTag);
      }
      if (request.expectedRevision == null) {
        await _noteRepository.delete(note);
      } else if (!await _noteRepository.deleteIfRevision(
          note.id, request.expectedRevision!)) {
        throw NoteRevisionConflictException(note.id);
      }
      await ensureMutationAuthorized(request.authorizeCommit);
    });
    _noteEvents.notifyNoteDeleted(note.id);

    return DeleteNoteCommandResponse();
  }
}
