import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/notes/commands/add_note_tag_command.dart';
import 'package:whph/application/features/tags/models/tag_time_category.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/notes/components/note_add_button.dart';
import 'package:whph/presentation/features/notes/components/note_filters.dart';
import 'package:whph/presentation/features/notes/components/notes_list.dart';
import 'package:whph/presentation/features/notes/constants/note_translation_keys.dart';
import 'package:whph/presentation/features/notes/pages/note_details_page.dart';
import 'package:whph/presentation/features/tags/services/tags_service.dart';
import 'package:whph/presentation/features/tasks/components/task_add_button.dart';
import 'package:whph/presentation/features/tasks/components/task_list_options.dart';
import 'package:whph/presentation/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/features/tags/components/tag_archive_button.dart';
import 'package:whph/presentation/features/tags/components/tag_delete_button.dart';
import 'package:whph/presentation/features/tags/components/tag_details_content.dart';
import 'package:whph/presentation/features/tags/components/tag_time_bar_chart.dart';
import 'package:whph/presentation/features/tags/components/time_chart_filters.dart';
import 'package:whph/presentation/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';

class TagDetailsPage extends StatefulWidget {
  static const String route = '/tags/details';
  final String tagId;

  const TagDetailsPage({super.key, required this.tagId});

  @override
  State<TagDetailsPage> createState() => _TagDetailsPageState();
}

class _TagDetailsPageState extends State<TagDetailsPage> with AutomaticKeepAliveClientMixin {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

  String? _taskSearchQuery;
  String? _noteSearchQuery;
  bool _showCompletedTasks = false;

  final _barChartKey = GlobalKey<TagTimeBarChartState>();
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  Set<TagTimeCategory> _selectedCategories = {TagTimeCategory.all};

  @override
  bool get wantKeepAlive => true;

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
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Archive
          TagArchiveButton(
            tagId: widget.tagId,
            onArchiveSuccess: () => Navigator.of(context).pop(),
            buttonColor: AppTheme.primaryColor,
            tooltip: _translationService.translate(TagTranslationKeys.archiveTagTooltip),
          ),

          // Delete
          TagDeleteButton(
            tagId: widget.tagId,
            onDeleteSuccess: () => Navigator.of(context).pop(),
            buttonColor: AppTheme.primaryColor,
            tooltip: _translationService.translate(TagTranslationKeys.deleteTagTooltip),
          ),

          // Help
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
            // Details
            TagDetailsContent(
              tagId: widget.tagId,
              onTagUpdated: () {
                // Force refresh of all tag-related components when tag properties change
                final tagsService = container.resolve<TagsService>();
                tagsService.notifyTagUpdated(widget.tagId);
              },
            ),
            const SizedBox(height: AppTheme.sizeSmall),

            // Tab sections
            Expanded(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    // Tab Bar with custom decoration
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: TabBar(
                        dividerColor: Colors.transparent,
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bar_chart),
                                const SizedBox(width: 8),
                                Text(_translationService.translate(TagTranslationKeys.timeBarChartTitle)),
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
                      ),
                    ),

                    // Tab Bar Views
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
                                    Text(
                                      _translationService.translate(TagTranslationKeys.timeBarChartTitle),
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    // Time Chart Filters
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppTheme.sizeSmall,
                                        vertical: AppTheme.sizeXSmall,
                                      ),
                                      child: TimeChartFilters(
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
                              ),

                              // Bar Chart
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
                              // Tasks header with filters
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
                                      ),
                                    ),
                                    if (!_showCompletedTasks)
                                      TaskAddButton(
                                        initialTagIds: [widget.tagId],
                                      ),
                                  ],
                                ),
                              ),

                              // Tasks List
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
                              // Notes header with filters and add button
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.sizeSmall,
                                  vertical: AppTheme.sizeXSmall,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: NoteFilters(
                                        search: _noteSearchQuery,
                                        onSearchChange: (query) {
                                          setState(() {
                                            _noteSearchQuery = query;
                                          });
                                        },
                                        showTagFilter: false,
                                      ),
                                    ),
                                    NoteAddButton(
                                      mini: true,
                                      onNoteCreated: (noteId) async {
                                        try {
                                          final command = AddNoteTagCommand(
                                            noteId: noteId,
                                            tagId: widget.tagId,
                                          );
                                          await _mediator.send(command);
                                          if (context.mounted) {
                                            await ResponsiveDialogHelper.showResponsiveDialog(
                                              context: context,
                                              title: _translationService.translate(NoteTranslationKeys.noteDetails),
                                              child: NoteDetailsPage(noteId: noteId),
                                            );
                                            setState(() {}); // Refresh the list after dialog closes
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ErrorHelper.showUnexpectedError(
                                              context,
                                              e as Exception,
                                              StackTrace.current,
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              // Notes List
                              Expanded(
                                child: NotesList(
                                  filterByTags: [widget.tagId],
                                  search: _noteSearchQuery,
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
