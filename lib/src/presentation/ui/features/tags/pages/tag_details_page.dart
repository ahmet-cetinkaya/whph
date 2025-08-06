import 'package:flutter/material.dart';
import 'package:whph/src/core/application/features/tags/models/tag_time_category.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/notes/components/note_add_button.dart';
import 'package:whph/src/presentation/ui/features/notes/components/note_list_options.dart';
import 'package:whph/src/presentation/ui/features/notes/components/notes_list.dart';
import 'package:whph/src/presentation/ui/features/notes/constants/note_translation_keys.dart';
import 'package:whph/src/presentation/ui/features/notes/pages/note_details_page.dart';
import 'package:whph/src/presentation/ui/features/tags/services/tags_service.dart';
import 'package:whph/src/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/src/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/src/presentation/ui/features/tasks/components/task_add_button.dart';
import 'package:whph/src/presentation/ui/features/tasks/components/task_list_options.dart';
import 'package:whph/src/presentation/ui/features/tasks/components/tasks_list.dart';
import 'package:whph/src/presentation/ui/features/tasks/pages/task_details_page.dart';
import 'package:whph/src/presentation/ui/features/tags/components/tag_archive_button.dart';
import 'package:whph/src/presentation/ui/features/tags/components/tag_delete_button.dart';
import 'package:whph/src/presentation/ui/features/tags/components/tag_details_content.dart';
import 'package:whph/src/presentation/ui/features/tags/components/tag_time_bar_chart.dart';
import 'package:whph/src/presentation/ui/features/tags/components/tag_time_chart_options.dart';
import 'package:whph/src/presentation/ui/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/components/border_fade_overlay.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/src/core/application/features/notes/queries/get_list_notes_query.dart';
import 'package:whph/src/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/src/presentation/ui/features/tasks/constants/task_defaults.dart';

class TagDetailsPage extends StatefulWidget {
  static const String route = '/tags/details';
  final String tagId;

  const TagDetailsPage({super.key, required this.tagId});

  @override
  State<TagDetailsPage> createState() => _TagDetailsPageState();
}

class _TagDetailsPageState extends State<TagDetailsPage> with AutomaticKeepAliveClientMixin {
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();

  // Note list options state
  bool _isNoteListVisible = false;
  String? _noteSearchQuery;
  SortConfig<NoteSortFields>? _sortConfig;

  // Task list options state
  String? _taskSearchQuery;
  bool _showCompletedTasks = false;
  SortConfig<TaskSortFields> _taskSortConfig = TaskDefaults.sorting;

  final _barChartKey = GlobalKey<TagTimeBarChartState>();
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  Set<TagTimeCategory> _selectedCategories = {TagTimeCategory.all};

  static const String _listOptionSettingKey = 'TAG_DETAILS_PAGE';

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
        backgroundColor: Theme.of(context).cardColor,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.sizeLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TagDetailsContent(
              tagId: widget.tagId,
              onTagUpdated: () {
                final tagsService = container.resolve<TagsService>();
                tagsService.notifyTagUpdated(widget.tagId);
              },
            ),
            const SizedBox(height: AppTheme.sizeSmall),
            SizedBox(
              height: MediaQuery.sizeOf(context).height - 200, // Fixed height to prevent overflow
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    BorderFadeOverlay(
                      fadeBorders: {FadeBorder.right},
                      child: TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bar_chart),
                                const SizedBox(width: 8),
                                Text(_translationService.translate(TagTranslationKeys.timeRecords)),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.task),
                                const SizedBox(width: 8),
                                Text(_translationService.translate(TagTranslationKeys.detailsTasksLabel)),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.note_alt_outlined),
                                const SizedBox(width: 8),
                                Text(_translationService.translate(NoteTranslationKeys.notes)),
                              ],
                            ),
                          ),
                        ],
                        dividerColor: Colors.transparent,
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Time Bar Chart Tab
                          Padding(
                            padding: const EdgeInsets.all(AppTheme.sizeSmall),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TagTimeChartOptions(
                                        selectedStartDate: _startDate,
                                        selectedEndDate: _endDate,
                                        selectedCategories: _selectedCategories,
                                        onDateFilterChange: (start, end) {
                                          setState(() {
                                            _startDate = start;
                                            _endDate = end;
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
                                    startDate: _startDate,
                                    endDate: _endDate,
                                    selectedCategories: _selectedCategories,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Tasks Tab
                          Padding(
                            padding: const EdgeInsets.all(AppTheme.sizeSmall),
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
                                        showDateFilter: false,
                                        showTagFilter: false,
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
                                    sortConfig: _taskSortConfig,
                                    enableReordering: !_showCompletedTasks && _taskSortConfig.useCustomOrder,
                                    ignoreArchivedTagVisibility: true,
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
                            padding: const EdgeInsets.all(AppTheme.sizeSmall),
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
            ),
          ],
        ),
      ),
    );
  }
}
