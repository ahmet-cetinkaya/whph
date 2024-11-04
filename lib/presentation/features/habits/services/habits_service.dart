import 'package:flutter/foundation.dart';
import 'package:whph/application/features/habits/commands/save_habit_command.dart';

class HabitsService {
  final ValueNotifier<SaveHabitCommandResponse?> onHabitSaved = ValueNotifier(null);
}
