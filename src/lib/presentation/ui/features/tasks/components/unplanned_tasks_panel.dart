import 'package:flutter/material.dart';
import 'package:whph/core/application/features/tasks/models/task_list_item.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_card.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class UnplannedTasksPanel extends StatelessWidget {
  final List<TaskListItem> tasks;
  final void Function(TaskListItem task) onArm;
  final void Function(TaskListItem task) onOpenDetails;
  final String? armedTaskId;
  final VoidCallback onClose;
  final String Function(TaskListItem task) groupLabelResolver;

  const UnplannedTasksPanel({
    super.key,
    required this.tasks,
    required this.onArm,
    required this.onOpenDetails,
    required this.armedTaskId,
    required this.onClose,
    required this.groupLabelResolver,
  });

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppTheme.sizeSmall, AppTheme.sizeSmall, AppTheme.sizeXSmall, AppTheme.sizeSmall),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  translationService.translate(TaskTranslationKeys.unplannedTasksPanelTitle),
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (tasks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: AppTheme.sizeXSmall),
                  child: _CountBadge(count: tasks.length),
                ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                iconSize: AppTheme.iconSizeSmall,
                visualDensity: VisualDensity.compact,
                tooltip: translationService.translate(TaskTranslationKeys.unplannedTasksPanelClose),
                onPressed: onClose,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: tasks.isEmpty
              ? _EmptyState(message: translationService.translate(TaskTranslationKeys.unplannedTasksPanelEmpty))
              : Builder(
                  builder: (context) {
                    final items = _buildItems();
                    return ListView.builder(
                      padding: const EdgeInsets.all(AppTheme.sizeSmall),
                      itemCount: items.length,
                      itemBuilder: (context, index) => items[index],
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<Widget> _buildItems() {
    final items = <Widget>[];
    String? currentGroup;

    for (final task in tasks) {
      final groupName = task.groupName;
      if (groupName != null && groupName != currentGroup) {
        currentGroup = groupName;
        items.add(_GroupHeader(label: groupLabelResolver(task)));
      }
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.sizeXSmall),
        child: _UnplannedTaskCard(
          task: task,
          isArmed: task.id == armedTaskId,
          onArm: () => onArm(task),
          onOpenDetails: () => onOpenDetails(task),
        ),
      ));
    }

    return items;
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;

  const _GroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.sizeSmall, bottom: AppTheme.sizeXSmall),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.secondaryTextColor,
              fontWeight: FontWeight.bold,
            ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _UnplannedTaskCard extends StatelessWidget {
  final TaskListItem task;
  final bool isArmed;
  final VoidCallback onArm;
  final VoidCallback onOpenDetails;

  const _UnplannedTaskCard({
    required this.task,
    required this.isArmed,
    required this.onArm,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
        border: Border.all(
          color: isArmed ? Theme.of(context).colorScheme.primary : Colors.transparent,
          width: 2,
        ),
        color: isArmed ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08) : Colors.transparent,
      ),
      child: TaskCard(
        taskItem: task,
        onOpenDetails: onOpenDetails,
        isDense: true,
        showScheduleButton: false,
        enableSwipeToComplete: false,
        trailingButtons: [
          IconButton(
            icon: Icon(isArmed ? Icons.event_available : Icons.event),
            color: isArmed ? Theme.of(context).colorScheme.primary : null,
            tooltip: translationService.translate(TaskTranslationKeys.unplannedTasksPanelArmButton),
            onPressed: onArm,
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeMedium),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.secondaryTextColor,
              ),
        ),
      ),
    );
  }
}
