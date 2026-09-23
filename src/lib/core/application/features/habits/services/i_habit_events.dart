abstract class IHabitEvents {
  void notifyHabitCreated(String habitId);
  void notifyHabitUpdated(String habitId);
  void notifyHabitDeleted(String habitId);
  void notifyHabitRecordAdded(String habitId);
  void notifyHabitRecordRemoved(String habitId);
}
