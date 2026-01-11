import 'package:flutter/foundation.dart';

class HabitsService extends ChangeNotifier {
  // Event notifiers for habit-related events
  final ValueNotifier<String?> onHabitCreated = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onHabitUpdated = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onHabitDeleted = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onHabitRecordAdded = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onHabitRecordRemoved = ValueNotifier<String?>(null);
  final ValueNotifier<void> onSettingsChanged = ValueNotifier<void>(null);

  // Notification methods for habit events
  void notifyHabitCreated(String habitId) {
    onHabitCreated.value = habitId;
    onHabitCreated.notifyListeners();
  }

  void notifyHabitUpdated(String habitId) {
    onHabitUpdated.value = habitId;
    onHabitUpdated.notifyListeners();
  }

  void notifyHabitDeleted(String habitId) {
    onHabitDeleted.value = habitId;
    onHabitDeleted.notifyListeners();
  }

  void notifyHabitRecordAdded(String habitId) {
    onHabitRecordAdded.value = habitId;
    onHabitRecordAdded.notifyListeners();
  }

  void notifyHabitRecordRemoved(String habitId) {
    onHabitRecordRemoved.value = habitId;
    onHabitRecordRemoved.notifyListeners();
  }

  void notifySettingsChanged() {
    onSettingsChanged.notifyListeners();
  }

  @override
  void dispose() {
    onHabitCreated.dispose();
    onHabitUpdated.dispose();
    onHabitDeleted.dispose();
    onHabitRecordAdded.dispose();
    onHabitRecordRemoved.dispose();
    onSettingsChanged.dispose();
    super.dispose();
  }
}
