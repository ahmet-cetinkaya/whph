import 'package:flutter/material.dart';
import 'package:whph/application/features/tags/models/tag_time_category.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/notes/components/note_add_button.dart';
import 'package:whph/presentation/features/notes/components/note_list_options.dart';
import 'package:whph/presentation/features/notes/components/notes_list.dart';
import 'package:whph/presentation/features/notes/constants/note_translation_keys.dart';
import 'package:whph/presentation/features/notes/pages/note_details_page.dart';
import 'package:whph/presentation/features/tags/services/tags_service.dart';
import 'package:whph/presentation/shared/models/sort_config.dart';
import 'package:whph/presentation/features/tasks/components/task_add_button.dart';
import 'package:whph/presentation/features/tasks/components/task_list_options.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/features/tags/components/tag_archive_button.dart';
import 'package:whph/presentation/features/tags/components/tag_delete_button.dart';
import 'package:whph/presentation/features/tags/components/tag_details_content.dart';
import 'package:whph/presentation/features/tags/components/tag_time_bar_chart.dart';
import 'package:whph/presentation/features/tags/components/tag_time_chart_options.dart';
import 'package:whph/presentation/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';
import 'package:whph/presentation/shared/components/border_fade_overlay.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/application/features/notes/queries/get_list_notes_query.dart';

class TagDetailsPage extends StatefulWidget {
  static const String route = '/tags/details';
  final String tagId;

  const TagDetailsPage({super.key, required this.tagId});

  @override
  State<TagDetailsPage> createState() => _TagDetailsPageState();
}

class _TagDetailsPageState extends State<TagDetailsPage> with AutomaticKeepAliveClientMixin {
  final _translationService = container.resolve<ITranslationService>();

  // Note list options state
  bool _isNoteListVisible = false;
  String? _noteSearchQuery;
  SortConfig<NoteSortFields>? _sortConfig;

  // Task list options state
  String? _taskSearchQuery;
  bool _showCompletedTasks = false;

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
    );
    setState(() {}); // Refresh the list after dialog closes
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        actions: [
          TagArchiveButton(
            tagId: widget.tagId,
            onArchiveSuccess: _goBack,
            buttonColor: AppTheme.primaryColor,
            tooltip: _translationService.translate(TagTranslationKeys.archiveTagTooltip),
          ),
          TagDeleteButton(
            tagId: widget.tagId,
            onDeleteSuccess: _goBack,
            buttonColor: AppTheme.primaryColor,
            tooltip: _translationService.translate(TagTranslationKeys.deleteTagTooltip),
          ),
          HelpMenu(
            titleKey: TagTranslationKeys.detailsHelpTitle,
            markdownContentKey: TagTranslationKeys.helpContent,
          ),
          const SizedBox(width: 2),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeMedium),
        child: Column(
          children: [
            TagDetailsContent(
              tagId: widget.tagId,
              onTagUpdated: () {
                final tagsService = container.resolve<TagsService>();
                tagsService.notifyTagUpdated(widget.tagId);
              },
            ),
            const SizedBox(height: AppTheme.sizeSmall),
            Expanded(
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
                          Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.sizeSmall,
                                  vertical: AppTheme.sizeXSmall,
                                ),
                                child: Row(
                                  children: [
                                    TagTimeChartOptions(
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
                                  ],
                                ),
                              ),
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

                          // Tasks Tab
                          Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.sizeSmall,
                                  vertical: AppTheme.sizeXSmall,
                                ),
                                child: Row(
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
                                        settingKeyVariantSuffix: _listOptionSettingKey,
                                      ),
                                    ),
                                    if (!_showCompletedTasks)
                                      TaskAddButton(
                                        initialTagIds: [widget.tagId],
                                        initialTitle: _taskSearchQuery,
                                        initialCompleted: _showCompletedTasks,
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: TaskList(
                                  filterByTags: [widget.tagId],
                                  filterByCompleted: _showCompletedTasks,
                                  search: _taskSearchQuery,
                                  onClickTask: (task) async {
                                    await ResponsiveDialogHelper.showResponsiveDialog(
                                      context: context,
                                      title: _translationService.translate(TagTranslationKeys.detailsTasksLabel),
                                      child: TaskDetailsPage(
                                        taskId: task.id,
                                        hideSidebar: true,
                                      ),
                                    );
                                    setState(() {}); // Refresh the list after dialog closes
                                  },
                                ),
                              ),
                            ],
                          ),

                          // Notes Tab
                          Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.sizeSmall,
                                  vertical: AppTheme.sizeXSmall,
                                ),
                                child: Row(
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
                              ),
                              if (_isNoteListVisible)
                                Expanded(
                                  child: NotesList(
                                    filterByTags: [widget.tagId],
                                    search: _noteSearchQuery,
                                    sortConfig: _sortConfig,
                                    onClickNote: _openNoteDetails,
                                  ),
                                ),
                            ],
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
