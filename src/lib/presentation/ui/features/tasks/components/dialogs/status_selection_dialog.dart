import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_task_statuses_query.dart';
import 'package:whph/core/domain/features/tasks/task_status_constants.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/tasks/utils/task_status_display.dart';

/// Dialog component for selecting a task status.
class StatusSelectionDialog extends StatefulWidget {
  final String? selectedStatusId;
  final ValueChanged<String?> onStatusSelected;
  final ITranslationService translationService;

  const StatusSelectionDialog({
    super.key,
    required this.selectedStatusId,
    required this.onStatusSelected,
    required this.translationService,
  });

  @override
  State<StatusSelectionDialog> createState() => _StatusSelectionDialogState();
}

class _StatusSelectionDialogState extends State<StatusSelectionDialog> {
  final _mediator = container.resolve<Mediator>();
  List<TaskStatusListItem>? _statuses;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    try {
      final response = await _mediator.send<GetListTaskStatusesQuery, GetListTaskStatusesQueryResponse>(
        const GetListTaskStatusesQuery(),
      );
      if (mounted) {
        setState(() {
          _statuses = response.items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.translationService.translate(TaskTranslationKeys.statusLabel)),
        automaticallyImplyLeading: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(widget.translationService.translate(SharedTranslationKeys.doneButton)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Built-in shortcuts
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.translationService.translate(TaskTranslationKeys.statusBuiltInSection),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: AppTheme.sizeSmall),
                        _buildStatusTile(
                          context: context,
                          statusId: TaskStatusConstants.todoId,
                          name: widget.translationService.translate(TaskTranslationKeys.statusBuiltInTodo),
                          color: Colors.grey,
                          isSelected: widget.selectedStatusId == TaskStatusConstants.todoId,
                        ),
                        const SizedBox(height: AppTheme.sizeSmall),
                        _buildStatusTile(
                          context: context,
                          statusId: TaskStatusConstants.doneId,
                          name: widget.translationService.translate(TaskTranslationKeys.statusBuiltInDone),
                          color: Colors.green,
                          isSelected: widget.selectedStatusId == TaskStatusConstants.doneId,
                        ),
                      ],
                    ),
                  ),
                ),
                // Custom statuses
                if (_statuses != null && _statuses!.any((s) => !s.isBuiltIn))
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        widget.translationService.translate(TaskTranslationKeys.statusCustomSection),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final status = _statuses!.where((s) => !s.isBuiltIn).toList()[index];
                        return _buildStatusTile(
                          context: context,
                          statusId: status.id,
                          name: TaskStatusDisplay.resolveName(
                            widget.translationService,
                            id: status.id,
                            name: status.name,
                            isDoneStatus: status.isDoneStatus,
                          ),
                          color: status.color != null ? Color(int.parse('FF${status.color!}', radix: 16)) : null,
                          isSelected: widget.selectedStatusId == status.id,
                        );
                      },
                      childCount: _statuses?.where((s) => !s.isBuiltIn).length ?? 0,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusTile({
    required BuildContext context,
    required String statusId,
    required String name,
    Color? color,
    required bool isSelected,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.circle,
          color: color ?? Colors.grey,
          size: 20,
        ),
        title: Text(name),
        trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
        onTap: () => widget.onStatusSelected(statusId),
      ),
    );
  }
}
