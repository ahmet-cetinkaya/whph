import 'package:flutter/material.dart';
import 'package:whph/core/application/features/tags/models/tag_time_category.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/notes/components/note_add_button.dart';
import 'package:whph/presentation/ui/features/notes/components/note_list_options.dart';
import 'package:whph/presentation/ui/features/notes/components/notes_list.dart';
import 'package:whph/presentation/ui/features/notes/constants/note_translation_keys.dart';
import 'package:whph/presentation/ui/features/notes/pages/note_details_page.dart';
import 'package:whph/presentation/ui/features/tags/services/tags_service.dart';
import 'package:whph/corePackages/acore/lib/utils/dialog_size.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_add_button.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_list_options.dart';
import 'package:whph/presentation/ui/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/ui/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_archive_button.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_delete_button.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_details_content.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_time_bar_chart.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_time_chart_options.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/corePackages/acore/lib/utils/responsive_dialog_helper.dart';
import 'package:whph/core/application/features/notes/queries/get_list_notes_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_defaults.dart';
import 'package:whph/presentation/ui/shared/models/date_filter_setting.dart';
import 'package:whph/presentation/ui/shared/components/custom_tab_bar.dart';

class TagDetailsPage extends StatefulWidget {
  static const String route = '/tags/details';
  final String tagId;

  const TagDetailsPage({super.key, required this.tagId});

  @override
  State<TagDetailsPage> createState() => _TagDetailsPageState();
}

class _TagDetailsPageState extends State<TagDetailsPage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();

  // Note list options state
  bool _isNoteListVisible = false;
  String? _noteSearchQuery;
  SortConfig<NoteSortFields>? _sortConfig;

  // Task list options state
  String? _taskSearchQuery;
  bool _showCompletedTasks = false;
  bool _showSubTasks = false;
  SortConfig<TaskSortFields> _taskSortConfig = TaskDefaults.sorting;

  final _barChartKey = GlobalKey<TagTimeBarChartState>();
  DateFilterSetting? _dateFilterSetting;
  DateTime? _startDate;
  DateTime? _endDate;
  Set<TagTimeCategory> _selectedCategories = {TagTimeCategory.all};

  static const String _listOptionSettingKey = 'TAG_DETAILS_PAGE';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _goBack() {
    Navigator.of(context).pop();
  }

  Future<void> _openNoteDetails(String noteId) async {
    if (!mounted) return;
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: NoteDetailsPage(noteId: noteId),
      size: DialogSize.large,
    );
    setState(() {}); // Refresh the list after dialog closes
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        actions: [
          TagArchiveButton(
            tagId: widget.tagId,
            onArchiveSuccess: _goBack,
            buttonColor: _themeService.primaryColor,
            tooltip: _translationService.translate(TagTranslationKeys.archiveTagTooltip),
          ),
          TagDeleteButton(
            tagId: widget.tagId,
            onDeleteSuccess: _goBack,
            buttonColor: _themeService.primaryColor,
            tooltip: _translationService.translate(TagTranslationKeys.deleteTagTooltip),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.sizeLarge),
            child: TagDetailsContent(
              tagId: widget.tagId,
              onTagUpdated: () {
                final tagsService = container.resolve<TagsService>();
                tagsService.notifyTagUpdated(widget.tagId);
              },
            ),
          ),
          const SizedBox(height: AppTheme.sizeSmall),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeLarge),
                  child: CustomTabBar(
                    selectedIndex: _tabController.index,
                    onTap: (index) {
                      setState(() {
                        _tabController.animateTo(index);
                      });
                    },
                    items: [
                      CustomTabItem(
                        icon: Icons.bar_chart,
                        label: _translationService.translate(TagTranslationKeys.timeRecords),
                      ),
                      CustomTabItem(
                        icon: Icons.task,
                        label: _translationService.translate(TagTranslationKeys.detailsTasksLabel),
                      ),
                      CustomTabItem(
                        icon: Icons.note_alt_outlined,
                        label: _translationService.translate(NoteTranslationKeys.notes),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.sizeSmall),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Time Bar Chart Tab
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.sizeLarge,
                          vertical: AppTheme.sizeSmall,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TagTimeChartOptions(
                                    dateFilterSetting: _dateFilterSetting,
                                    selectedStartDate: _dateFilterSetting != null ? _startDate : null,
                                    selectedEndDate: _dateFilterSetting != null ? _endDate : null,
                                    selectedCategories: _selectedCategories,
                                    onDateFilterChange: (start, end) {
                                      if (start != null && end != null) {
                                        setState(() {
                                          _startDate = start;
                                          _endDate = end;
                                          _barChartKey.currentState?.refresh();
                                        });
                                      }
                                    },
                                    onDateFilterSettingChange: (dateFilterSetting) {
                                      setState(() {
                                        _dateFilterSetting = dateFilterSetting;
                                        if (dateFilterSetting?.isQuickSelection == true) {
                                          final currentRange = dateFilterSetting!.calculateCurrentDateRange();
                                          _startDate = currentRange.startDate;
                                          _endDate = currentRange.endDate;
                                        } else if (dateFilterSetting != null) {
                                          _startDate = dateFilterSetting.startDate;
                                          _endDate = dateFilterSetting.endDate;
                                        } else {
                                          // Clear operation
                                          _startDate = null;
                                          _endDate = null;
                                        }
                                        _barChartKey.currentState?.refresh();
                                      });
                                    },
                                    onCategoriesChanged: (categories) {
                                      setState(() {
                                        _selectedCategories = categories;
                                        _barChartKey.currentState?.refresh();
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.sizeSmall),
                            Expanded(
                              child: TagTimeBarChart(
                                key: _barChartKey,
                                filterByTags: [widget.tagId],
                                startDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                                endDate: _endDate ?? DateTime.now(),
                                selectedCategories: _selectedCategories,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Tasks Tab
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.sizeLarge,
                          vertical: AppTheme.sizeSmall,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TaskListOptions(
                                    onSearchChange: (query) {
                                      setState(() {
                                        _taskSearchQuery = query;
                                      });
                                    },
                                    showCompletedTasks: _showCompletedTasks,
                                    onCompletedTasksToggle: (showCompleted) {
                                      setState(() {
                                        _showCompletedTasks = showCompleted;
                                      });
                                    },
                                    showSubTasks: _showSubTasks,
                                    onSubTasksToggle: (showSubTasks) {
                                      setState(() {
                                        _showSubTasks = showSubTasks;
                                      });
                                    },
                                    showDateFilter: false,
                                    showTagFilter: false,
                                    showSubTasksToggle: true,
                                    hasItems: true,
                                    sortConfig: _taskSortConfig,
                                    onSortChange: (newConfig) {
                                      setState(() {
                                        _taskSortConfig = newConfig;
                                      });
                                    },
                                    settingKeyVariantSuffix: _listOptionSettingKey,
                                  ),
                                ),
                                if (!_showCompletedTasks) ...[
                                  const SizedBox(width: AppTheme.sizeSmall),
                                  TaskAddButton(
                                    initialTagIds: [widget.tagId],
                                    initialTitle: _taskSearchQuery,
                                    initialCompleted: _showCompletedTasks,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: AppTheme.sizeSmall),
                            Expanded(
                              child: TaskList(
                                filterByTags: [widget.tagId],
                                filterByCompleted: _showCompletedTasks,
                                search: _taskSearchQuery,
                                includeSubTasks: _showSubTasks,
                                sortConfig: _taskSortConfig,
                                enableReordering: !_showCompletedTasks && _taskSortConfig.useCustomOrder,
                                ignoreArchivedTagVisibility: true,
                                useParentScroll: false,
                                onClickTask: (task) async {
                                  await ResponsiveDialogHelper.showResponsiveDialog(
                                    context: context,
                                    child: TaskDetailsPage(
                                      taskId: task.id,
                                      hideSidebar: true,
                                    ),
                                    size: DialogSize.large,
                                  );
                                  setState(() {}); // Refresh the list after dialog closes
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Notes Tab
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.sizeLarge,
                          vertical: AppTheme.sizeSmall,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: NoteListOptions(
                                    search: _noteSearchQuery,
                                    sortConfig: _sortConfig,
                                    onSearchChange: (query) {
                                      setState(() {
                                        _noteSearchQuery = query;
                                      });
                                    },
                                    onSortChange: (sortConfig) {
                                      setState(() {
                                        _sortConfig = sortConfig;
                                      });
                                    },
                                    showTagFilter: false,
                                    onSettingsLoaded: () {
                                      setState(() {
                                        _isNoteListVisible = true;
                                      });
                                    },
                                    onSaveSettings: () {
                                      setState(() {});
                                    },
                                    settingKeyVariantSuffix: _listOptionSettingKey,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.sizeSmall),
                                NoteAddButton(
                                  mini: true,
                                  initialTagIds: [widget.tagId],
                                  initialTitle: _noteSearchQuery,
                                  onNoteCreated: (noteId) async {
                                    // Open note details dialog
                                    await _openNoteDetails(noteId);
                                    // Refresh the list after dialog closes
                                    setState(() {});
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.sizeSmall),
                            Expanded(
                              child: _isNoteListVisible
                                  ? NotesList(
                                      filterByTags: [widget.tagId],
                                      search: _noteSearchQuery,
                                      sortConfig: _sortConfig,
                                      ignoreArchivedTagVisibility: true,
                                      onClickNote: _openNoteDetails,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
