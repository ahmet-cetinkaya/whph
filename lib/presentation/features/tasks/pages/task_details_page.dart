import 'package:flutter/material.dart';
import 'package:markdown_editor_plus/widgets/markdown_auto_preview.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/acore/components/date_time_picker_field.dart';
import 'package:whph/core/acore/components/numeric_input.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/models/dropdown_option.dart';
import 'package:whph/presentation/features/tasks/components/pomodoro_timer.dart';
import 'package:whph/presentation/features/tasks/components/task_complete_button.dart';

class TaskDetailsPage extends StatefulWidget {
  final int taskId;

  const TaskDetailsPage({super.key, required this.taskId});

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  final Mediator _mediator = container.resolve<Mediator>();

  GetTaskQueryResponse? task;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _plannedDateController = TextEditingController();
  final TextEditingController _deadlineDateController = TextEditingController();

  final List<DropdownOption<EisenhowerPriority>> _priorityOptions = [
    DropdownOption(label: 'None', value: EisenhowerPriority.none),
    DropdownOption(label: 'Urgent & Important', value: EisenhowerPriority.urgentImportant),
    DropdownOption(label: 'Not Urgent & Important', value: EisenhowerPriority.notUrgentImportant),
    DropdownOption(label: 'Urgent & Not Important', value: EisenhowerPriority.urgentNotImportant),
    DropdownOption(label: 'Not Urgent & Not Important', value: EisenhowerPriority.notUrgentNotImportant),
  ];
  final List<DropdownOption<int?>> _topicOptions = [
    DropdownOption(label: 'None', value: null),
  ];

  @override
  void initState() {
    _fetchTask();
    // _fetchTopics();
    super.initState();
  }

  Future<void> _fetchTask() async {
    var query = GetTaskQuery(id: widget.taskId);
    var response = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(query);
    setState(() {
      task = response;
      _titleController.text = task?.title ?? '';
      _descriptionController.text = task?.description ?? '';
      _plannedDateController.text = task?.plannedDate?.toString() ?? '';
      _deadlineDateController.text = task?.deadlineDate?.toString() ?? '';
    });
  }

  // Future<void> _fetchTopics() async {
  //   var query = GetListTopicsQuery(pageIndex: 0, pageSize: 25);
  //   var response = await _mediator.send<GetListTopicsQuery, GetListTopicsQueryResponse>(query);
  //   setState(() {
  //     _topicOptions.addAll(response.items.map((topic) {
  //       return DropdownOption<int>(label: topic.name, value: topic.id);
  //     }));
  //   });
  // }

  void _updateTask() {
    var saveCommand = SaveTaskCommand(
      id: task!.id,
      title: _titleController.text,
      description: _descriptionController.text,
      priority: task!.priority,
      plannedDate: DateTime.tryParse(_plannedDateController.text),
      deadlineDate: DateTime.tryParse(_deadlineDateController.text),
      estimatedTime: task!.estimatedTime,
      elapsedTime: task!.elapsedTime,
      isCompleted: task!.isCompleted,
    );
    _mediator.send(saveCommand);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: task == null
            ? const Text('')
            : Row(
                children: [
                  if (task != null)
                    TaskCompleteButton(
                      taskId: task!.id,
                      isCompleted: task!.isCompleted,
                      onToggleCompleted: _fetchTask,
                    ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: TextField(
                      controller: _titleController,
                      onChanged: (value) {
                        _updateTask(); // Save changes on input
                      },
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Enter task title',
                      ),
                    ),
                  ),
                ],
              ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: task == null || _topicOptions.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PRIORITY
                  const Text(
                    'Priority:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  DropdownButton<DropdownOption<EisenhowerPriority>>(
                    value: _priorityOptions.firstWhere((priority) =>
                        priority.value ==
                        EisenhowerPriority.values.firstWhere(
                          (e) => e.toString() == task?.priority?.toString(),
                          orElse: () => EisenhowerPriority.none,
                        )),
                    onChanged: (DropdownOption<EisenhowerPriority>? newValue) {
                      setState(() {
                        task!.priority = newValue?.value;
                      });
                      _updateTask();
                    },
                    items: _priorityOptions.map<DropdownMenuItem<DropdownOption<EisenhowerPriority>>>(
                        (DropdownOption<EisenhowerPriority> priority) {
                      return DropdownMenuItem<DropdownOption<EisenhowerPriority>>(
                        value: priority,
                        child: Text(priority.label),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16.0),

                  // // TOPIC
                  // const Text(
                  //   'Topic:',
                  //   style: TextStyle(fontWeight: FontWeight.bold),
                  // ),
                  // DropdownButton<DropdownOption<int?>>(
                  //   value: _topicOptions.firstWhere((topicOption) => topicOption.value == task!.topicId,
                  //       orElse: () => _topicOptions.first),
                  //   onChanged: (DropdownOption<int?>? newValue) {
                  //     setState(() {
                  //       // task!.topicId = newValue?.value;
                  //     });
                  //     _updateTask();
                  //   },
                  //   items:
                  //       _topicOptions.map<DropdownMenuItem<DropdownOption<int?>>>((DropdownOption<int?> topicOption) {
                  //     return DropdownMenuItem<DropdownOption<int?>>(
                  //       value: topicOption,
                  //       child: Text(topicOption.label),
                  //     );
                  //   }).toList(),
                  // ),
                  // const SizedBox(height: 16.0),

                  // PLANNED DATE
                  const Text(
                    'Planned Date:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  DateTimePickerField(
                    controller: _plannedDateController,
                    hintText: '',
                    onConfirm: (value) {
                      setState(() {
                        task?.plannedDate = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16.0),

                  // DEADLINE DATE
                  const Text(
                    'Deadline Date:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  DateTimePickerField(
                      controller: _deadlineDateController,
                      hintText: "",
                      onConfirm: (value) {
                        setState(() {
                          task?.deadlineDate = value;
                        });
                        _updateTask();
                      }),
                  const SizedBox(height: 16.0),

                  // ESTIMATED TIME
                  const Text(
                    'Estimated Time:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  NumericInput(
                    initialValue: task!.estimatedTime ?? 0,
                    minValue: 0,
                    maxValue: 1000,
                    incrementValue: 5,
                    decrementValue: 5,
                    onValueChanged: (value) {
                      setState(() {
                        task!.estimatedTime = value;
                      });
                      _updateTask();
                    },
                  ),

                  // ELAPSED TIME
                  Text(
                    'Elapsed Time: ${task!.elapsedTime != null ? (task!.elapsedTime! / 60.0).roundToDouble() : '0'} min',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  PomodoroTimer(onTimeUpdate: (duration) {
                    setState(() {
                      task!.elapsedTime = (task!.elapsedTime ?? 0) + 1;
                      _updateTask();
                    });
                  }),
                  const SizedBox(height: 16.0),

                  // DESCRIPTION
                  const Text(
                    'Description:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  MarkdownAutoPreview(
                    controller: _descriptionController,
                    emojiConvert: true,
                    onChanged: (value) {
                      _updateTask();
                    },
                  ),
                  const SizedBox(height: 15.0),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _plannedDateController.dispose();
    _deadlineDateController.dispose();
    super.dispose();
  }
}
