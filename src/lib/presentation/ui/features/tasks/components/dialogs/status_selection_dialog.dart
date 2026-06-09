import 'package:flutter/material.dart';
import 'package:whph/core/domain/features/tasks/task_status_constants.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/tasks/utils/task_status_display.dart';
import 'package:whph/presentation/ui/features/tasks/utils/status_loader_mixin.dart';

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

class _StatusSelectionDialogState extends State<StatusSelectionDialog> with StatusLoaderMixin {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // StatusLoaderMixin.initState() calls _loadStatuses()
    // Update loading state once statuses are loaded
    if (statuses != null) {
      _isLoading = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure loading state is updated after mixin initialization
    if (statuses != null && _isLoading) {
      setState(() => _isLoading = false);
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
                if (statuses != null && statuses!.any((s) => !s.isBuiltIn))
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
                        final status = statuses!.where((s) => !s.isBuiltIn).toList()[index];
                        final parsedColor = TaskStatusDisplay.parseColor(status.color);
                        return _buildStatusTile(
                          context: context,
                          statusId: status.id,
                          name: TaskStatusDisplay.resolveName(
                            widget.translationService,
                            id: status.id,
                            name: status.name,
                            isDoneStatus: status.isDoneStatus,
                          ),
                          color: parsedColor,
                          isSelected: widget.selectedStatusId == status.id,
                        );
                      },
                      childCount: statuses?.where((s) => !s.isBuiltIn).length ?? 0,
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
