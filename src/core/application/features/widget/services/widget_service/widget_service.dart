import 'dart:convert';
import 'dart:developer' as developer;
import 'package:home_widget/home_widget.dart';
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart';
import 'package:domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/shared/services/filter_settings_manager.dart';
import 'helpers/widget_background_callback_handler.dart';
import 'helpers/widget_toggle_helper.dart';
import 'helpers/widget_data_aggregator.dart';
import 'helpers/widget_feedback_manager.dart';

// Re-export the background callback for HomeWidget registration
export 'helpers/widget_background_callback_handler.dart' show widgetBackgroundCallback;

/// Service for managing home widget updates and interactions.
class WidgetService {
  static const String _tasksWidgetName = 'WhphTasksWidgetProvider';
  static const String _habitsWidgetName = 'WhphHabitsWidgetProvider';
  static const String _dataKey = 'widget_data';

  final Mediator _mediator;
  late final WidgetToggleHelper _toggleHelper;
  late final WidgetDataAggregator _dataAggregator;
  late final WidgetFeedbackManager _feedbackManager;

  WidgetService({required Mediator mediator, required IContainer container}) : _mediator = mediator {
    final filterSettingsManager = FilterSettingsManager(_mediator);

    _toggleHelper = WidgetToggleHelper(mediator: _mediator);
    _dataAggregator = WidgetDataAggregator(
      mediator: _mediator,
      container: container,
      filterSettingsManager: filterSettingsManager,
    );
    _feedbackManager = WidgetFeedbackManager(
      tasksWidgetName: _tasksWidgetName,
      habitsWidgetName: _habitsWidgetName,
      dataKey: _dataKey,
    );
  }

  /// Update both tasks and habits widgets.
  Future<void> updateWidget() async {
    await Future.wait([
      updateTasksWidget(),
      updateHabitsWidget(),
    ]);
  }

  /// Update only the tasks widget.
  Future<void> updateTasksWidget() async {
    try {
      final widgetData = await _dataAggregator.getWidgetData();
      final jsonData = jsonEncode(widgetData.toJson());

      await HomeWidget.saveWidgetData(_dataKey, jsonData);
      await HomeWidget.updateWidget(
        name: _tasksWidgetName,
        androidName: _tasksWidgetName,
      );
    } catch (e) {
      DomainLogger.error('Error updating tasks widget: $e');
    }
  }

  /// Update only the habits widget.
  Future<void> updateHabitsWidget() async {
    try {
      final widgetData = await _dataAggregator.getWidgetData();
      final jsonData = jsonEncode(widgetData.toJson());

      await HomeWidget.saveWidgetData(_dataKey, jsonData);
      await HomeWidget.updateWidget(
        name: _habitsWidgetName,
        androidName: _habitsWidgetName,
      );
    } catch (e) {
      DomainLogger.error('Error updating habits widget: $e');
    }
  }

  /// Handles a widget click action.
  Future<void> handleWidgetClick(String action, String itemId) async {
    try {
      developer.log('=== HANDLE WIDGET CLICK START ===', name: 'WidgetService');
      developer.log('Action: $action', name: 'WidgetService');
      developer.log('Item ID: $itemId', name: 'WidgetService');

      developer.log('Showing completion feedback...', name: 'WidgetService');
      await _feedbackManager.showCompletionFeedback(action, itemId);
      developer.log('Completion feedback shown', name: 'WidgetService');

      switch (action) {
        case 'toggle_task':
          developer.log('Processing task toggle for ID: $itemId', name: 'WidgetService');
          await _toggleHelper.toggleTask(itemId);
          developer.log('Task $itemId toggled successfully', name: 'WidgetService');
          break;
        case 'toggle_habit':
          developer.log('Processing habit toggle for ID: $itemId', name: 'WidgetService');
          await _toggleHelper.toggleHabit(itemId);
          developer.log('Habit $itemId toggled successfully', name: 'WidgetService');
          break;
        default:
          developer.log('ERROR: Unknown widget action: $action', name: 'WidgetService');
          return;
      }

      developer.log('Updating widget after successful $action...', name: 'WidgetService');
      await updateWidget();
    } catch (e, stackTrace) {
      DomainLogger.error('Error handling widget click ($action, $itemId): $e');
      DomainLogger.debug('Stack trace: $stackTrace');

      await _feedbackManager.showErrorFeedback(action, itemId);

      try {
        await updateWidget();
      } catch (updateError) {
        DomainLogger.error('Error updating widget after failed action: $updateError');
      }
      developer.log('=== HANDLE WIDGET CLICK ERROR END ===', name: 'WidgetService');
    }
  }

  /// Initializes the widget service.
  Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId('group.me.ahmetcetinkaya.whph');

      HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);

      HomeWidget.widgetClicked.listen((uri) {
        if (uri == null) {
          DomainLogger.error('Received null URI from widget click');
          return;
        }

        final action = uri.queryParameters['action'];
        final itemId = uri.queryParameters['itemId'];

        if (action != null && itemId != null) {
          handleWidgetClick(action, itemId);
        } else {
          DomainLogger.error('Missing action or itemId in widget click URI');
        }
      });
    } catch (e, stackTrace) {
      DomainLogger.error('ERROR during widget service initialization: $e');
      DomainLogger.debug('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Debug method to force widget refresh.
  Future<void> forceRefresh() async {
    await HomeWidget.saveWidgetData(_dataKey, '');
    await updateWidget();
    DomainLogger.info('Force widget refresh completed');
  }
}
