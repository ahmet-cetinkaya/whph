abstract class INoteEvents {
  void notifyNoteCreated(String noteId);
  void notifyNoteUpdated(String noteId);
  void notifyNoteDeleted(String noteId);
}
