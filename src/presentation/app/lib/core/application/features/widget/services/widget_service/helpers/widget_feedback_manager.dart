import 'dart:convert';
import 'dart:developer' as developer;
import 'package:home_widget/home_widget.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

/// Manages feedback display for widget interactions.
class WidgetFeedbackManager {
  final String _tasksWidgetName;
  final String _habitsWidgetName;
  final String _dataKey;

  WidgetFeedbackManager({
    required String tasksWidgetName,
    required String habitsWidgetName,
    required String dataKey,
  })  : _tasksWidgetName = tasksWidgetName,
        _habitsWidgetName = habitsWidgetName,
        _dataKey = dataKey;

  /// Shows completion feedback on the widget.
  Future<void> showCompletionFeedback(String action, String itemId) async {
    try {
      final feedbackMessage = action == 'toggle_task' ? 'Task completed! ✓' : 'Habit completed! ✓';

      final feedbackData = {
        'tasks': [],
        'habits': [],
        'lastUpdated': DateTime.now().toIso8601String(),
        'feedback': feedbackMessage,
      };

      final jsonData = jsonEncode(feedbackData);
      await HomeWidget.saveWidgetData(_dataKey, jsonData);

      await Future.wait([
        HomeWidget.updateWidget(
          name: _tasksWidgetName,
          androidName: _tasksWidgetName,
        ),
        HomeWidget.updateWidget(
          name: _habitsWidgetName,
          androidName: _habitsWidgetName,
        ),
      ]);

      developer.log('Completion feedback shown for $action', name: 'WidgetFeedbackManager');
    } catch (e) {
      developer.log('Error showing completion feedback: $e', name: 'WidgetFeedbackManager');
    }
  }

  /// Shows error feedback on the widget.
  Future<void> showErrorFeedback(String action, String itemId) async {
    try {
      final errorMessage = 'Error completing ${action == 'toggle_task' ? 'task' : 'habit'}';

      final feedbackData = {
        'tasks': [],
        'habits': [],
        'lastUpdated': DateTime.now().toIso8601String(),
        'error': errorMessage,
      };

      final jsonData = jsonEncode(feedbackData);
      await HomeWidget.saveWidgetData(_dataKey, jsonData);

      await Future.wait([
        HomeWidget.updateWidget(
          name: _tasksWidgetName,
          androidName: _tasksWidgetName,
        ),
        HomeWidget.updateWidget(
          name: _habitsWidgetName,
          androidName: _habitsWidgetName,
        ),
      ]);
    } catch (e) {
      Logger.error('Error showing error feedback: $e');
    }
  }
}
