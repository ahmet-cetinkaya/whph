abstract class IHabitNotificationHandler {
  void Function(String habitId)? onHabitCompleted;

  Future<void> handleNotificationHabitCompletion(String habitId);
}
