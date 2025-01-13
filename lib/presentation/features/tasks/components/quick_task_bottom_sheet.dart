import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/utils/error_helper.dart';
import 'package:intl/intl.dart';

class QuickTaskBottomSheet extends StatefulWidget {
  final List<String>? initialTagIds;
  final Function(String taskId)? onTaskCreated;

  const QuickTaskBottomSheet({
    super.key,
    this.initialTagIds,
    this.onTaskCreated,
  });

  @override
  State<QuickTaskBottomSheet> createState() => _QuickTaskBottomSheetState();
}

class _QuickTaskBottomSheetState extends State<QuickTaskBottomSheet> {
  final _titleController = TextEditingController();
  final _mediator = container.resolve<Mediator>();
  final _focusNode = FocusNode();
  bool _isLoading = false;

  // Quick action state variables
  EisenhowerPriority? _selectedPriority;
  int? _estimatedTime;
  DateTime? _plannedDate;
  DateTime? _deadlineDate;

  @override
  void dispose() {
    _focusNode.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _resetState() {
    _selectedPriority = null;
    _estimatedTime = null;
    _plannedDate = null;
    _deadlineDate = null;
  }

  Future<void> _createTask() async {
    if (_isLoading || _titleController.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      var command = SaveTaskCommand(
        title: _titleController.text,
        description: "# Steps\n - [ ] Step 1\n - [ ] Step 2\n# Notes\n",
        tagIds: widget.initialTagIds,
        priority: _selectedPriority,
        estimatedTime: _estimatedTime,
        plannedDate: _plannedDate,
        deadlineDate: _deadlineDate,
      );
      var response = await _mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(command);

      if (widget.onTaskCreated != null) {
        widget.onTaskCreated!(response.id);
      }

      if (mounted) {
        setState(() {
          _titleController.clear();
          _resetState();
        });
        _focusNode.requestFocus();
      }
    } on BusinessException catch (e) {
      if (mounted) ErrorHelper.showError(context, e);
    } catch (e) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e, message: 'Error creating task');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(bool isDeadline) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && mounted) {
      setState(() {
        if (isDeadline) {
          _deadlineDate = picked;
        } else {
          _plannedDate = picked;
        }
      });
    }
  }

  String? _getFormattedDate(DateTime? date) {
    if (date == null) return null;
    return DateFormat('dd.MM.yy').format(date);
  }

  void _togglePriority() {
    setState(() {
      switch (_selectedPriority) {
        case null:
          _selectedPriority = EisenhowerPriority.urgentImportant;
          break;
        case EisenhowerPriority.none:
          _selectedPriority = EisenhowerPriority.urgentImportant;
          break;
        case EisenhowerPriority.urgentImportant:
          _selectedPriority = EisenhowerPriority.notUrgentImportant;
          break;
        case EisenhowerPriority.notUrgentImportant:
          _selectedPriority = EisenhowerPriority.urgentNotImportant;
          break;
        case EisenhowerPriority.urgentNotImportant:
          _selectedPriority = EisenhowerPriority.notUrgentNotImportant;
          break;
        case EisenhowerPriority.notUrgentNotImportant:
          _selectedPriority = EisenhowerPriority.none;
          break;
      }
    });
  }

  Color? _getPriorityColor() {
    switch (_selectedPriority) {
      case EisenhowerPriority.urgentImportant:
        return Colors.red;
      case EisenhowerPriority.notUrgentImportant:
        return Colors.green;
      case EisenhowerPriority.urgentNotImportant:
        return Colors.blue;
      case EisenhowerPriority.notUrgentNotImportant:
        return Colors.grey;
      case EisenhowerPriority.none:
      case null:
        return Colors.white;
    }
  }

  String _getPriorityTooltip() {
    switch (_selectedPriority) {
      case EisenhowerPriority.urgentImportant:
        return 'Urgent & Important';
      case EisenhowerPriority.notUrgentImportant:
        return 'Not Urgent & Important';
      case EisenhowerPriority.urgentNotImportant:
        return 'Urgent & Not Important';
      case EisenhowerPriority.notUrgentNotImportant:
        return 'Not Urgent & Not Important';
      case EisenhowerPriority.none:
      case null:
        return 'No Priority';
    }
  }

  void _toggleEstimatedTime() {
    setState(() {
      switch (_estimatedTime) {
        case null:
          _estimatedTime = 10;
          break;
        case 10:
          _estimatedTime = 30;
          break;
        case 30:
          _estimatedTime = 50;
          break;
        case 50:
          _estimatedTime = 90;
          break;
        case 90:
          _estimatedTime = 120;
          break;
        case 120:
          _estimatedTime = null;
          break;
        default:
          _estimatedTime = null;
      }
    });
  }

  String? _getEstimatedTimeText() {
    if (_estimatedTime == null) return null;
    return '${_estimatedTime}m';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {}, // Prevent tap from propagating
            child: DraggableScrollableSheet(
              initialChildSize: 0.15,
              minChildSize: 0.15,
              maxChildSize: 0.9,
              builder: (context, controller) {
                return Container(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      TextField(
                        controller: _titleController,
                        focusNode: _focusNode,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Task title',
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _selectedPriority == null || _selectedPriority == EisenhowerPriority.none
                                      ? Icons.flag_outlined
                                      : Icons.flag,
                                  color: _getPriorityColor(),
                                ),
                                onPressed: _togglePriority,
                                tooltip: _getPriorityTooltip(),
                              ),
                              IconButton(
                                icon: _estimatedTime == null
                                    ? const Icon(Icons.timer_outlined)
                                    : Text(
                                        _getEstimatedTimeText()!,
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                onPressed: _toggleEstimatedTime,
                                tooltip: 'Estimated Time: ${_getEstimatedTimeText() ?? 'Not set'}',
                              ),
                              IconButton(
                                icon: Icon(
                                  _plannedDate == null ? Icons.event_outlined : Icons.event,
                                  color: _plannedDate == null ? null : Colors.green,
                                ),
                                onPressed: () => _selectDate(false),
                                tooltip: 'Planned: ${_getFormattedDate(_plannedDate) ?? 'Not set'}',
                              ),
                              IconButton(
                                icon: Icon(
                                  _deadlineDate == null ? Icons.alarm_outlined : Icons.alarm,
                                  color: _deadlineDate == null ? null : Colors.orange,
                                ),
                                onPressed: () => _selectDate(true),
                                tooltip: 'Deadline: ${_getFormattedDate(_deadlineDate) ?? 'Not set'}',
                              ),
                              IconButton(
                                icon: Icon(_isLoading ? Icons.hourglass_empty : Icons.send),
                                onPressed: _createTask,
                              ),
                            ],
                          ),
                        ),
                        onSubmitted: (_) => _createTask(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
