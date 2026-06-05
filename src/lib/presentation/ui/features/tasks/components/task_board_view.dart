import 'package:acore/acore.dart';
import 'package:boardview/board_item.dart';
import 'package:boardview/board_list.dart';
import 'package:boardview/boardview.dart';
import 'package:flutter/material.dart';
import 'package:whph/core/application/features/tasks/models/task_list_item.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_card.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';

/// A horizontal-scroll Kanban board backed by the [boardview] package.
///
/// Each entry in [groupedTasks] becomes one column. Dragging a card within
/// a column reorders it (fires [onReorderWithinColumn]). Dragging across
/// columns invokes [onCardMovedAcrossColumns] so the host can persist the
/// group-defining field; when [canMoveAcrossColumns] is false a cross-column
/// drop is rejected with an informational snackbar.
class TaskBoardView extends StatefulWidget {
  final Map<String, List<TaskListItem>> groupedTasks;

  /// Map of group key → whether the group name is a translation key.
  final Map<String, bool> groupTranslatable;

  /// Whether cross-column drops should be persisted.
  final bool canMoveAcrossColumns;

  final void Function(TaskListItem task) onClickTask;
  final void Function(String taskId)? onTaskCompleted;
  final void Function(TaskListItem task, DateTime date)? onScheduleTask;

  /// Called when a card lands on a different column.
  final void Function(TaskListItem task, String fromGroupKey, String toGroupKey)? onCardMovedAcrossColumns;

  /// Called when a card is reordered within its column.
  final void Function(int oldIndex, int newIndex, List<TaskListItem> columnTasks)? onReorderWithinColumn;

  final List<Widget> Function(TaskListItem task)? trailingButtons;
  final bool transparentCards;

  final void Function(String groupKey)? onAddToGroup;

  const TaskBoardView({
    super.key,
    required this.groupedTasks,
    required this.groupTranslatable,
    required this.onClickTask,
    this.canMoveAcrossColumns = false,
    this.onTaskCompleted,
    this.onScheduleTask,
    this.onCardMovedAcrossColumns,
    this.onReorderWithinColumn,
    this.trailingButtons,
    this.transparentCards = false,
    this.onAddToGroup,
  });

  @override
  State<TaskBoardView> createState() => _TaskBoardViewState();
}

class _TaskBoardViewState extends State<TaskBoardView> {
  final _translationService = container.resolve<ITranslationService>();

  /// Ordered list of group keys, derived from [widget.groupedTasks].
  /// No local shadow state — the widget rebuilds on every drag and reads the
  /// current data straight from the host. This avoids stale-index bugs from
  /// out-of-sync local copies.
  List<String> get _groupKeys => widget.groupedTasks.keys.toList();

  bool _isColumnInBounds(int listIndex) => listIndex >= 0 && listIndex < _groupKeys.length;

  /// The source must reference an existing card.
  bool _isSourceInBounds(int listIndex, int itemIndex) {
    if (!_isColumnInBounds(listIndex)) return false;
    final column = widget.groupedTasks[_groupKeys[listIndex]];
    return column != null && itemIndex >= 0 && itemIndex < column.length;
  }

  void _onDropItem(int? listIndex, int? itemIndex, int? oldListIndex, int? oldItemIndex, BoardItemState state) {
    if (listIndex == null || itemIndex == null || oldListIndex == null || oldItemIndex == null) return;
    // The source must point at a real card; the destination only needs a valid
    // column — dropping into an empty or shorter column yields a drop index at
    // or beyond that column's length, which is a legal insertion point.
    if (!_isSourceInBounds(oldListIndex, oldItemIndex) || !_isColumnInBounds(listIndex)) return;

    final groupKeys = _groupKeys;
    final fromList = oldListIndex;
    final fromItem = oldItemIndex;
    final toList = listIndex;
    final task = widget.groupedTasks[groupKeys[fromList]]![fromItem];

    if (fromList == toList) {
      // Within-column reorder
      final tasks = List<TaskListItem>.from(widget.groupedTasks[groupKeys[fromList]]!);
      tasks.removeAt(fromItem);
      final toItem = itemIndex.clamp(0, tasks.length);
      tasks.insert(toItem, task);
      widget.onReorderWithinColumn?.call(fromItem, toItem, tasks);
      return;
    }

    // Cross-column move
    if (!widget.canMoveAcrossColumns) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_translationService.translate(TaskTranslationKeys.boardCrossColumnMoveNotSupported)),
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    widget.onCardMovedAcrossColumns?.call(task, groupKeys[fromList], groupKeys[toList]);
  }

  String _columnTitle(String groupKey) {
    if (groupKey.isEmpty) return '';
    final isTranslatable = widget.groupTranslatable[groupKey] ?? false;
    return isTranslatable ? _translationService.translate(groupKey) : groupKey;
  }

  @override
  Widget build(BuildContext context) {
    if (_groupKeys.isEmpty) return const SizedBox.shrink();

    final lists = List.generate(_groupKeys.length, (li) {
      final groupKey = _groupKeys[li];
      final tasks = widget.groupedTasks[groupKey] ?? const <TaskListItem>[];
      final title = _columnTitle(groupKey);

      final items = List.generate(tasks.length, (ii) {
        final task = tasks[ii];
        final buttons = widget.trailingButtons?.call(task) ?? [];

        return BoardItem(
          onStartDragItem: (_, __, ___) {},
          onDropItem: _onDropItem,
          onTapItem: (_, __, ___) => widget.onClickTask(task),
          draggable: true,
          item: Padding(
            key: ValueKey('board_task_${task.id}'),
            padding: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
            child: TaskCard(
              key: ValueKey('board_card_${task.id}'),
              taskItem: task,
              onOpenDetails: () => widget.onClickTask(task),
              onCompleted: widget.onTaskCompleted,
              onScheduled: (task.isCompleted || widget.onScheduleTask == null)
                  ? null
                  : () => widget.onScheduleTask!(task, DateTime.now()),
              transparent: widget.transparentCards,
              trailingButtons: buttons.isNotEmpty ? buttons : null,
            ),
          ),
        );
      });

      return BoardList(
        draggable: false,
        onDropList: (_, __) {},
        header: title.isEmpty
            ? null
            : [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall, vertical: AppTheme.sizeXSmall),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${tasks.length}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.onAddToGroup != null)
                  Padding(
                    padding: const EdgeInsets.only(right: AppTheme.sizeXSmall),
                    child: IconButton(
                      icon: const Icon(Icons.add, size: AppTheme.boardHeaderIconSize),
                      iconSize: AppTheme.boardHeaderIconSize,
                      onPressed: () => widget.onAddToGroup!(groupKey),
                      tooltip: _translationService.translate(TaskTranslationKeys.addTaskButtonTooltip),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: AppTheme.buttonSizeSmall,
                        minHeight: AppTheme.buttonSizeSmall,
                      ),
                    ),
                  ),
              ],
        items: items,
        backgroundColor: Colors.transparent,
        headerBackgroundColor: Colors.transparent,
      );
    });

    return BoardView(
      width: AppTheme.boardColumnWidth,
      dragDelay: PlatformUtils.isMobile ? 50 : 0,
      lists: lists,
    );
  }
}
