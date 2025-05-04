import 'package:flutter/foundation.dart';

class NotesService {
  // Event listeners for note-related events
  final ValueNotifier<void> onNoteSaved = ValueNotifier<void>(null);
  final ValueNotifier<void> onNoteDeleted = ValueNotifier<void>(null);
  final ValueNotifier<void> onNoteTagUpdated = ValueNotifier<void>(null);

  void notifyNoteSaved() {
    onNoteSaved.value = null;
    onNoteSaved.notifyListeners();
  }

  void notifyNoteDeleted() {
    onNoteDeleted.value = null;
    onNoteDeleted.notifyListeners();
  }

  void notifyNoteTagUpdated() {
    onNoteTagUpdated.value = null;
    onNoteTagUpdated.notifyListeners();
  }
}
