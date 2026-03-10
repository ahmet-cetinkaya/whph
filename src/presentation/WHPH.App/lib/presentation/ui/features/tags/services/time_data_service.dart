import 'package:flutter/foundation.dart';

class TimeDataService extends ChangeNotifier {
  // Event notifiers for time data-related events
  final ValueNotifier<String?> onTimeDataUpdated = ValueNotifier<String?>(null);
  final ValueNotifier<void> onTimeDataChanged = ValueNotifier<void>(null);

  // Notification methods for time data events
  void notifyTimeDataUpdated(String? tagId) {
    onTimeDataUpdated.value = tagId;
    onTimeDataUpdated.notifyListeners();
  }

  void notifyTimeDataChanged() {
    onTimeDataChanged.value = null;
    onTimeDataChanged.notifyListeners();
  }

  @override
  void dispose() {
    onTimeDataUpdated.dispose();
    onTimeDataChanged.dispose();
    super.dispose();
  }
}
