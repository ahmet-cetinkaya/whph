import 'package:flutter/foundation.dart';
import 'package:whph/core/application/features/habits/services/i_habit_events.dart';

class HabitsService extends ChangeNotifier implements IHabitEvents {
  final ValueNotifier<String?> onHabitCreated = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onHabitUpdated = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onHabitDeleted = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onHabitRecordAdded = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onHabitRecordRemoved = ValueNotifier<String?>(null);
  final ValueNotifier<void> onSettingsChanged = ValueNotifier<void>(null);

  @override
  void notifyHabitCreated(String habitId) {
    onHabitCreated.value = habitId;
    onHabitCreated.notifyListeners();
  }

  @override
  void notifyHabitUpdated(String habitId) {
    onHabitUpdated.value = habitId;
    onHabitUpdated.notifyListeners();
  }

  @override
  void notifyHabitDeleted(String habitId) {
    onHabitDeleted.value = habitId;
    onHabitDeleted.notifyListeners();
  }

  @override
  void notifyHabitRecordAdded(String habitId) {
    onHabitRecordAdded.value = habitId;
    onHabitRecordAdded.notifyListeners();
  }

  @override
  void notifyHabitRecordRemoved(String habitId) {
    onHabitRecordRemoved.value = habitId;
    onHabitRecordRemoved.notifyListeners();
  }

  void notifySettingsChanged() {
    onSettingsChanged.notifyListeners();
  }

  void notifyRefresh() {
    onHabitCreated.value = null;
    onHabitUpdated.value = null;
    onHabitDeleted.value = null;
    onHabitRecordAdded.value = null;
    onHabitRecordRemoved.value = null;
    onHabitCreated.notifyListeners();
    onHabitUpdated.notifyListeners();
    onHabitDeleted.notifyListeners();
    onHabitRecordAdded.notifyListeners();
    onHabitRecordRemoved.notifyListeners();
    notifyListeners();
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
