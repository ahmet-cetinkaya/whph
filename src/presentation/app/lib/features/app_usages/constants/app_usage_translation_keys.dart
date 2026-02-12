import 'package:application/features/app_usages/constants/app_usage_translation_keys.dart' as application;

class AppUsageTranslationKeys extends application.AppUsageTranslationKeys {
  static const String noUsage = 'app_usages.no_usage';

  // Device
  static const String deviceLabel = 'app_usages.details.device.label';
  static const String unknownDeviceLabel = 'app_usages.details.device.unknown';

  // Tags
  static const String tagsLabel = 'app_usages.details.tags.label';
  static const String tagsHint = 'app_usages.details.tags.hint';

  // Color
  static const String colorLabel = 'app_usages.details.color.label';
  static const String colorHint = 'app_usages.details.color.hint';

  // Errors
  static const String getUsageError = 'app_usages.errors.get_usage';
  static const String statisticsError = 'app_usages.errors.statistics';
  static const String saveUsageError = 'app_usages.errors.save_usage';
  static const String getTagsError = 'app_usages.errors.get_tags';
  static const String addTagError = 'app_usages.errors.add_tag';
  static const String removeTagError = 'app_usages.errors.remove_tag';
  static const String saveRuleError = 'app_usages.errors.save_rule';
  static const String deleteError = 'app_usages.errors.delete';
  static const String tagAlreadyExistsError = 'app_usages.errors.tag_already_exists';
  static const String appUsageNotFoundError = 'app_usages.errors.app_usage_not_found';
  static const String appUsageTagNotFoundError = 'app_usages.errors.app_usage_tag_not_found';
  static const String appUsageTagRuleNotFoundError = 'app_usages.errors.app_usage_tag_rule_not_found';
  static const String appUsageIgnoreRuleNotFoundError = 'app_usages.errors.app_usage_ignore_rule_not_found';

  // Delete
  static const String deleteConfirmTitle = 'app_usages.delete.confirm_title';

  // Ignore Rules
  static const String noIgnoreRules = 'app_usages.ignore_rules.no_rules';
  static const String patternLabel = 'app_usages.ignore_rules.pattern_label';
  static const String deleteRuleTitle = 'app_usages.ignore_rules.delete_title';
  static const String deleteRuleConfirm = 'app_usages.ignore_rules.delete_confirm';
  static const String deleteRuleTooltip = 'app_usages.ignore_rules.delete_tooltip';

  // Form
  static const String patternFieldLabel = 'app_usages.form.pattern.label';
  static const String patternFieldHint = 'app_usages.form.pattern.hint';
  static const String patternFieldRequired = 'app_usages.form.pattern.required';
  static const String patternFieldHelpTooltip = 'app_usages.form.pattern.help_tooltip';
  static const String descriptionFieldLabel = 'app_usages.form.description.label';
  static const String descriptionFieldHint = 'app_usages.form.description.hint';
  static const String saveButton = 'app_usages.form.save';
  static const String savedButton = 'app_usages.form.saved';

  // Rules
  static const String rulesTitle = 'app_usages.rules.title';
  static const String tagRules = 'app_usages.rules.tag_rules';
  static const String ignoreRules = 'app_usages.rules.ignore_rules';
  static const String addNewRule = 'app_usages.rules.add_new_rule';
  static const String existingRules = 'app_usages.rules.existing_rules';
  static const String noRules = 'app_usages.rules.no_rules';
  static const String deleteRuleConfirmTitle = 'app_usages.rules.delete_confirm_title';
  static const String deleteRuleConfirmMessage = 'app_usages.rules.delete_confirm_message';
  static const String getRulesError = 'app_usages.rules.errors.get_rules';
  static const String deleteRuleError = 'app_usages.rules.errors.delete_rule';
  static const String rulesHelpTitle = 'app_usages.rules.help.title';
  static const String rulesHelpContent = 'app_usages.rules.help.content';

  // Help
  static const String helpTitle = 'app_usages.details.help.title';
  static const String helpContent = 'app_usages.details.help.content';

  // Pages
  static const String viewTitle = 'app_usages.pages.view.title';
  static const String tagRulesButton = 'app_usages.pages.view.buttons.tag_rules';
  static const String filterTagsButton = 'app_usages.pages.view.buttons.filter_tags';
  static const String filterDevicesButton = 'app_usages.pages.view.buttons.filter_devices';
  static const String viewHelpTitle = 'app_usages.pages.view.help.title';
  static const String viewHelpContent = 'app_usages.pages.view.help.content';

  // Device Filter
  static const String searchLabel = 'app_usages.device_filter.search.label';
  static const String clearAllButton = 'app_usages.device_filter.clear_all';

  // Tooltips
  static const String editNameTooltip = 'app_usages.tooltips.edit_name';

  // Tour translation keys
  static const String tourAppUsageInsightsTitle = 'app_usages.tour.app_usage_insights.title';
  static const String tourAppUsageInsightsDescription = 'app_usages.tour.app_usage_insights.description';
  static const String tourUsageStatisticsTitle = 'app_usages.tour.usage_statistics.title';
  static const String tourUsageStatisticsDescription = 'app_usages.tour.usage_statistics.description';
  static const String tourFilterSortTitle = 'app_usages.tour.filter_sort.title';
  static const String tourFilterSortDescription = 'app_usages.tour.filter_sort.description';
  static const String tourTrackingSettingsTitle = 'app_usages.tour.tracking_settings.title';
  static const String tourTrackingSettingsDescription = 'app_usages.tour.tracking_settings.description';

  // Sort
  static const String sortDuration = 'app_usages.sort.duration';
  static const String sortName = 'app_usages.sort.name';
  static const String sortDevice = 'app_usages.sort.device';

  // List Options
  static const String useTagColorForBars = 'app_usages.list_options.use_tag_color_for_bars';
  static const String useTagColorForBarsTooltip = 'app_usages.list_options.use_tag_color_for_bars_tooltip';
}
