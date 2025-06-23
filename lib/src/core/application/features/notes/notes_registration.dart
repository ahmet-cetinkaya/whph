import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/notes/commands/add_note_tag_command.dart';
import 'package:whph/src/core/application/features/notes/commands/delete_note_command.dart';
import 'package:whph/src/core/application/features/notes/commands/remove_note_tag_command.dart';
import 'package:whph/src/core/application/features/notes/commands/save_note_command.dart';
import 'package:whph/src/core/application/features/notes/commands/update_note_order_command.dart';
import 'package:whph/src/core/application/features/notes/queries/get_note_query.dart';
import 'package:whph/src/core/application/features/notes/queries/get_list_notes_query.dart';
import 'package:whph/src/core/application/features/notes/services/abstraction/i_note_repository.dart';
import 'package:whph/src/core/application/features/notes/services/abstraction/i_note_tag_repository.dart';
import 'package:whph/src/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:acore/acore.dart';

void registerNotesFeature(
  IContainer container,
  Mediator mediator,
  INoteRepository noteRepository,
  INoteTagRepository noteTagRepository,
  ITagRepository tagRepository,
) {
  // Register Command Handlers
  mediator.registerHandler<SaveNoteCommand, SaveNoteCommandResponse, SaveNoteCommandHandler>(
    () => SaveNoteCommandHandler(noteRepository: noteRepository),
  );

  mediator.registerHandler<DeleteNoteCommand, DeleteNoteCommandResponse, DeleteNoteCommandHandler>(
    () => DeleteNoteCommandHandler(
      noteRepository: noteRepository,
      noteTagRepository: noteTagRepository,
    ),
  );

  mediator.registerHandler<AddNoteTagCommand, AddNoteTagCommandResponse, AddNoteTagCommandHandler>(
    () => AddNoteTagCommandHandler(noteTagRepository: noteTagRepository),
  );

  mediator.registerHandler<RemoveNoteTagCommand, RemoveNoteTagCommandResponse, RemoveNoteTagCommandHandler>(
    () => RemoveNoteTagCommandHandler(noteTagRepository: noteTagRepository),
  );

  mediator.registerHandler<UpdateNoteOrderCommand, UpdateNoteOrderCommandResponse, UpdateNoteOrderCommandHandler>(
    () => UpdateNoteOrderCommandHandler(noteRepository: noteRepository),
  );

  // Register Query Handlers
  mediator.registerHandler<GetNoteQuery, GetNoteQueryResponse, GetNoteQueryHandler>(
    () => GetNoteQueryHandler(noteRepository: noteRepository),
  );

  mediator.registerHandler<GetListNotesQuery, GetListNotesQueryResponse, GetListNotesQueryHandler>(
    () => GetListNotesQueryHandler(noteRepository: noteRepository),
  );
}
