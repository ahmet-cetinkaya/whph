abstract class IHabitNotificationHandler {
  void Function(String habitId)? onHabitActionHandled;

  Future<void> handleNotificationHabitAction(String habitId);
}
