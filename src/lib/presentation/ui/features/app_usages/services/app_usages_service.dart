import 'package:flutter/foundation.dart';

class AppUsagesService extends ChangeNotifier {
  // Event listeners for app usage-related events - keeping nullable for the value
  final ValueNotifier<String?> onAppUsageCreated = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onAppUsageUpdated = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onAppUsageDeleted = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onAppUsageTimeRecordUpdated = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onAppUsageIgnoreRuleUpdated = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onAppUsageRuleDeleted = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onAppUsageRuleUpdated = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onAppUsageRuleCreated = ValueNotifier<String?>(null);

  void notifyAppUsageCreated(String appUsageId) {
    onAppUsageCreated.value = appUsageId;
    onAppUsageCreated.notifyListeners();
  }

  void notifyAppUsageUpdated(String appUsageId) {
    onAppUsageUpdated.value = appUsageId;
    onAppUsageUpdated.notifyListeners();
  }

  void notifyAppUsageDeleted(String appUsageId) {
    onAppUsageDeleted.value = appUsageId;
    onAppUsageDeleted.notifyListeners();
  }

  void notifyAppUsageTimeRecordUpdated(String appUsageId) {
    onAppUsageTimeRecordUpdated.value = appUsageId;
    onAppUsageTimeRecordUpdated.notifyListeners();
  }

  void notifyAppUsageIgnoreRuleUpdated(String ruleId) {
    onAppUsageIgnoreRuleUpdated.value = ruleId;
    onAppUsageIgnoreRuleUpdated.notifyListeners();
  }

  void notifyAppUsageRuleDeleted(String ruleId) {
    onAppUsageRuleDeleted.value = ruleId;
    onAppUsageRuleDeleted.notifyListeners();
  }

  void notifyAppUsageRuleUpdated(String ruleId) {
    onAppUsageRuleUpdated.value = ruleId;
    onAppUsageRuleUpdated.notifyListeners();
  }

  void notifyAppUsageRuleCreated(String ruleId) {
    onAppUsageRuleCreated.value = ruleId;
    onAppUsageRuleCreated.notifyListeners();
  }

  void notifyRefresh() {
    onAppUsageCreated.value = null;
    onAppUsageUpdated.value = null;
    onAppUsageDeleted.value = null;
    onAppUsageTimeRecordUpdated.value = null;
    onAppUsageIgnoreRuleUpdated.value = null;
    onAppUsageRuleDeleted.value = null;
    onAppUsageRuleUpdated.value = null;
    onAppUsageRuleCreated.value = null;
    onAppUsageCreated.notifyListeners();
    onAppUsageUpdated.notifyListeners();
    onAppUsageDeleted.notifyListeners();
    onAppUsageTimeRecordUpdated.notifyListeners();
    onAppUsageIgnoreRuleUpdated.notifyListeners();
    onAppUsageRuleDeleted.notifyListeners();
    onAppUsageRuleUpdated.notifyListeners();
    onAppUsageRuleCreated.notifyListeners();
  }

  @override
  void dispose() {
    onAppUsageCreated.dispose();
    onAppUsageUpdated.dispose();
    onAppUsageDeleted.dispose();
    onAppUsageTimeRecordUpdated.dispose();
    onAppUsageIgnoreRuleUpdated.dispose();
    onAppUsageRuleDeleted.dispose();
    onAppUsageRuleUpdated.dispose();
    onAppUsageRuleCreated.dispose();
    super.dispose();
  }
}
