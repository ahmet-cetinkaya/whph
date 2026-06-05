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

  /// Mutable shadow of the grouped task data driven by [BoardView] callbacks.
  /// Kept in sync so drag indices always map to the right items.
  late List<List<TaskListItem>> _columnData;

  /// Ordered list of group keys, mirroring [_columnData] by index.
  late List<String> _groupKeys;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(TaskBoardView old) {
    super.didUpdateWidget(old);
    _syncFromWidget();
  }

  void _syncFromWidget() {
    _groupKeys = widget.groupedTasks.keys.toList();
    _columnData = _groupKeys.map((k) => List<TaskListItem>.from(widget.groupedTasks[k]!)).toList();
  }

  void _onDropItem(int? listIndex, int? itemIndex, int? oldListIndex, int? oldItemIndex, BoardItemState state) {
    final fromList = oldListIndex!;
    final fromItem = oldItemIndex!;
    final toList = listIndex!;
    final toItem = itemIndex!;

    final task = _columnData[fromList][fromItem];

    if (fromList == toList) {
      // Within-column reorder
      final tasks = _columnData[fromList];
      tasks.removeAt(fromItem);
      tasks.insert(toItem, task);
      widget.onReorderWithinColumn?.call(fromItem, toItem, tasks);
    } else {
      // Cross-column move
      if (!widget.canMoveAcrossColumns) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_translationService.translate(TaskTranslationKeys.boardCrossColumnMoveNotSupported)),
          duration: const Duration(seconds: 2),
        ));
        return;
      }

      _columnData[fromList].removeAt(fromItem);
      _columnData[toList].insert(toItem, task);

      widget.onCardMovedAcrossColumns?.call(task, _groupKeys[fromList], _groupKeys[toList]);
    }
  }

  String _columnTitle(String groupKey) {
    if (groupKey.isEmpty) return '';
    final isTranslatable = widget.groupTranslatable[groupKey] ?? false;
    return isTranslatable ? _translationService.translate(groupKey) : groupKey;
  }

  @override
  Widget build(BuildContext context) {
    if (_columnData.isEmpty) return const SizedBox.shrink();

    final lists = List.generate(_columnData.length, (li) {
      final groupKey = _groupKeys[li];
      final tasks = _columnData[li];
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
                      icon: const Icon(Icons.add, size: 18),
                      iconSize: 18,
                      onPressed: () => widget.onAddToGroup!(groupKey),
                      tooltip: _translationService.translate(TaskTranslationKeys.addTaskButtonTooltip),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ),
              ],
        items: items,
        backgroundColor: Colors.transparent,
        headerBackgroundColor: Colors.transparent,
      );
    });

    return BoardView(
      width: 280,
      dragDelay: PlatformUtils.isMobile ? 50 : 0,
      lists: lists,
    );
  }
}
