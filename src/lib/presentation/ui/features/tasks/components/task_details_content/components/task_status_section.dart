import 'dart:async';

import 'package:flutter/material.dart';
import 'package:acore/acore.dart' as acore;
import 'package:acore/utils/dialog_size.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_task_statuses_query.dart';
import 'package:whph/core/domain/features/tasks/task_status_constants.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/components/dialogs/status_selection_dialog.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/utils/task_status_display.dart';
import 'package:whph/presentation/ui/shared/components/detail_table.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Builds the status section for task details.
class TaskStatusSection {
  final ITranslationService translationService;
  final String? statusId;
  final void Function(String?) onStatusChanged;

  const TaskStatusSection({
    required this.translationService,
    required this.statusId,
    required this.onStatusChanged,
  });

  DetailTableRowData build() => DetailTableRowData(
        label: translationService.translate(TaskTranslationKeys.statusLabel),
        icon: Icons.check_circle_outline,
        widget: Padding(
          padding: const EdgeInsets.only(top: AppTheme.sizeSmall, bottom: AppTheme.sizeSmall, left: AppTheme.sizeSmall),
          child: StatusChip(
            statusId: statusId,
            onStatusChanged: onStatusChanged,
          ),
        ),
      );
}

/// A chip displaying the current status name. Tapping opens a selection dialog.
class StatusChip extends StatefulWidget {
  final String? statusId;
  final void Function(String?) onStatusChanged;

  const StatusChip({super.key, required this.statusId, required this.onStatusChanged});

  @override
  State<StatusChip> createState() => _StatusChipState();
}

class _StatusChipState extends State<StatusChip> {
  List<TaskStatusListItem>? _statuses;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    final mediator = container.resolve<Mediator>();
    final response = await mediator.send<GetListTaskStatusesQuery, GetListTaskStatusesQueryResponse>(
      const GetListTaskStatusesQuery(),
    );
    if (mounted) {
      setState(() => _statuses = response.items);
    }
  }

  Future<void> _showStatusSelection(BuildContext context) async {
    final translationService = container.resolve<ITranslationService>();

    String? tempSelectedStatusId = widget.statusId;

    await acore.ResponsiveDialogHelper.showResponsiveDialog<void>(
      context: context,
      size: DialogSize.xLarge,
      child: StatefulBuilder(
        builder: (context, setState) {
          return StatusSelectionDialog(
            selectedStatusId: tempSelectedStatusId,
            onStatusSelected: (statusId) {
              setState(() {
                tempSelectedStatusId = statusId;
              });
              widget.onStatusChanged(statusId);
              Navigator.of(context).pop();
            },
            translationService: translationService,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    final String label;
    final Color color;

    final statusId = widget.statusId;

    // Synchronously resolve built-in statuses to avoid async race on rebuild
    if (statusId == null || statusId.isEmpty || statusId == TaskStatusConstants.todoId) {
      label = translationService.translate(TaskTranslationKeys.statusBuiltInTodo);
      color = Color(int.parse('FF${TaskStatusConstants.todoColor}', radix: 16));
    } else if (statusId == TaskStatusConstants.doneId) {
      label = translationService.translate(TaskTranslationKeys.statusBuiltInDone);
      color = Color(int.parse('FF${TaskStatusConstants.doneColor}', radix: 16));
    } else {
      // Custom status — resolve from the async-loaded list
      final match = _statuses?.where((s) => s.id == statusId).toList();
      if (match != null && match.isNotEmpty) {
        final resolved = match.first;
        label = TaskStatusDisplay.resolveName(
          translationService,
          id: resolved.id,
          name: resolved.name,
          isDoneStatus: resolved.isDoneStatus,
        );
        Color? parsedColor;
        if (resolved.color != null) {
          try {
            String cleanHex = resolved.color!.replaceAll('#', '').replaceFirst('0x', '');
            if (cleanHex.length == 6) {
              cleanHex = 'FF$cleanHex';
            }
            parsedColor = Color(int.parse(cleanHex, radix: 16));
          } catch (_) {}
        }
        color = parsedColor ?? Colors.grey;
      } else {
        // Still loading or status deleted — show a placeholder
        label = '…';
        color = Colors.grey;
      }
    }

    return InkWell(
      onTap: () => _showStatusSelection(context),
      borderRadius: BorderRadius.circular(8),
      child: Chip(
        avatar: Icon(Icons.circle, color: color, size: 12),
        label: Text(label),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}
