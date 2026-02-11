import 'widget_service/widget_service.dart';

/// Handles automatic widget updates when data changes
class WidgetEventHandler {
  final WidgetService _widgetService;

  WidgetEventHandler({required WidgetService widgetService}) : _widgetService = widgetService;

  /// Call this method after task operations to update the widget
  Future<void> onTaskChanged() async {
    await _widgetService.updateWidget();
  }

  /// Call this method after habit operations to update the widget
  Future<void> onHabitChanged() async {
    await _widgetService.updateWidget();
  }

  /// Call this method after habit record operations to update the widget
  Future<void> onHabitRecordChanged() async {
    await _widgetService.updateWidget();
  }
}
