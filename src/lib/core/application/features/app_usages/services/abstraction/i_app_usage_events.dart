abstract class IAppUsageEvents {
  void notifyAppUsageCreated(String appUsageId);
  void notifyAppUsageUpdated(String appUsageId);
  void notifyAppUsageDeleted(String appUsageId);
  void notifyAppUsageIgnoreRuleUpdated(String ruleId);
  void notifyAppUsageRuleDeleted(String ruleId);
  void notifyAppUsageRuleCreated(String ruleId);
}
