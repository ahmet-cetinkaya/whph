import 'package:flutter/foundation.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_events.dart';

class NotesService extends ChangeNotifier implements INoteEvents {
  final ValueNotifier<String?> onNoteCreated = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onNoteUpdated = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onNoteDeleted = ValueNotifier<String?>(null);

  @override
  void notifyNoteCreated(String noteId) {
    onNoteCreated.value = noteId;
    onNoteCreated.notifyListeners();
  }

  @override
  void notifyNoteUpdated(String noteId) {
    onNoteUpdated.value = noteId;
    onNoteUpdated.notifyListeners();
  }

  @override
  void notifyNoteDeleted(String noteId) {
    onNoteDeleted.value = noteId;
    onNoteDeleted.notifyListeners();
  }

  void notifyRefresh() {
    onNoteCreated.value = null;
    onNoteUpdated.value = null;
    onNoteDeleted.value = null;
    onNoteCreated.notifyListeners();
    onNoteUpdated.notifyListeners();
    onNoteDeleted.notifyListeners();
    notifyListeners();
  }

  @override
  void dispose() {
    onNoteCreated.dispose();
    onNoteUpdated.dispose();
    onNoteDeleted.dispose();
    super.dispose();
  }
}
