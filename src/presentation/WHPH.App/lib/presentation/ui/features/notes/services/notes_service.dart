import 'package:flutter/foundation.dart';

class NotesService extends ChangeNotifier {
  // Event listeners for note-related events
  final ValueNotifier<String?> onNoteCreated = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onNoteUpdated = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onNoteDeleted = ValueNotifier<String?>(null);

  void notifyNoteCreated(String noteId) {
    onNoteCreated.value = noteId;
    onNoteCreated.notifyListeners();
  }

  void notifyNoteUpdated(String noteId) {
    onNoteUpdated.value = noteId;
    onNoteUpdated.notifyListeners();
  }

  void notifyNoteDeleted(String noteId) {
    onNoteDeleted.value = noteId;
    onNoteDeleted.notifyListeners();
  }

  @override
  void dispose() {
    onNoteCreated.dispose();
    onNoteUpdated.dispose();
    onNoteDeleted.dispose();
    super.dispose();
  }
}
