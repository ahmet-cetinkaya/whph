import 'package:whph/application/features/tags/constants/tag_translation_keys.dart' as application;

class TagTranslationKeys extends application.TagTranslationKeys {
  // Common
  static const String defaultTagName = 'tags.default_name';

  // Actions
  static const String addTag = 'tags.actions.add';
  static const String editTag = 'tags.actions.edit';
  static const String deleteTag = 'tags.actions.delete';
  static const String archiveTag = 'tags.actions.archive';
  static const String unarchiveTag = 'tags.actions.unarchive';
  static const String showArchived = 'tags.actions.show_archived';
  static const String hideArchived = 'tags.actions.hide_archived';

  // Messages
  static const String confirmDelete = 'tags.messages.confirm_delete';
  static const String confirmArchive = 'tags.messages.confirm_archive';
  static const String confirmUnarchive = 'tags.messages.confirm_unarchive';
  static const String unarchiveTagConfirm = 'tags.messages.unarchive_confirm';
  static const String archiveTagConfirm = 'tags.messages.archive_confirm';

  // Errors
  static const String errorLoading = 'tags.errors.loading';
  static const String errorSaving = 'tags.errors.saving';
  static const String errorDeleting = 'tags.errors.deleting';
  static const String errorCreating = 'tags.errors.creating';
  static const String errorLoadingArchiveStatus = 'tags.errors.loading_archive_status';
  static const String errorTogglingArchive = 'tags.errors.toggling_archive';
  static const String tagNotFoundError = 'tags.errors.tag_not_found';
  static const String tagTagNotFoundError = 'tags.errors.tag_tag_not_found';
  static const String tagTagAlreadyExistsError = 'tags.errors.tag_tag_already_exists';
  static const String sameTagError = 'tags.errors.same_tag';

  // Labels
  static const String nameLabel = 'tags.labels.name';
  static const String colorLabel = 'tags.labels.color';
  static const String descriptionLabel = 'tags.labels.description';
  static const String tagsLabel = 'tags.labels.tags';
  static const String newTag = 'tags.new_tag';

  // Help
  static const String helpTitle = 'tags.help.title';
  static const String helpContent = 'tags.help.content';
  static const String overviewHelpTitle = 'tags.help.overview.title';
  static const String overviewHelpContent = 'tags.help.overview.content';

  // List
  static const String noTags = 'tags.list.no_tags';
  static const String filterTagsTooltip = 'tags.list.filter_tooltip';

  // Tooltips
  static const String colorTooltip = 'tags.tooltips.color';
  static const String selectTooltip = 'tags.tooltips.select';
  static const String addTagTooltip = 'tags.tooltips.add_tag';
  static const String deleteTagTooltip = 'tags.tooltips.delete_tag';
  static const String archiveTagTooltip = 'tags.tooltips.archive_tag';
  static const String unarchiveTagTooltip = 'tags.tooltips.unarchive_tag';
  static const String addTaskTooltip = 'tags.tooltips.add_task';
  static const String editNameTooltip = 'tags.tooltips.edit_name';
  static const String removeTagTooltip = 'tags.tooltips.remove_tag';

  // Search
  static const String searchLabel = 'tags.search.label';
  static const String clearAllButton = 'tags.search.clear_all';

  // Selection
  static const String doneButton = 'tags.selection.done';

  // Time Chart
  static const String timeChartNoData = 'tags.time_chart.no_data';
  static const String selectCategory = 'tags.filter.select_category';
  static const String allCategories = 'tags.filter.all_categories';
  static const String otherCategory = 'tags.time_chart.other_category';

  // Time Bar Chart
  static const String timeBarChartTitle = 'tags.time_bar_chart.title';
  static const String timeBarChartNoData = 'tags.time_bar_chart.no_data';
  static const String timeBarChartByElement = 'tags.time_bar_chart.by_element';

  // Time Categories
  static const String categoryAll = 'tags.categories.all';
  static const String categoryTasks = 'tags.categories.tasks';
  static const String categoryAppUsage = 'tags.categories.app_usage';
  static const String categoryHabits = 'tags.categories.habits';

  // Details Page
  static const String detailsHelpTitle = 'tags.details.help.title';
  static const String detailsHelpDescription = 'tags.details.help.description';
  static const String detailsTasksLabel = 'tags.details.tasks_label';

  // Details fields
  static const String detailsRelatedTags = 'tags.details.related_tags';
  static const String detailsArchived = 'tags.details.archived';

  // Page Sections
  static const String title = 'tags.title';
  static const String timeDistribution = 'tags.time_distribution';
  static const String listSectionTitle = 'tags.sections.list';

  static const String timeRecords = 'tags.time_records';
}
