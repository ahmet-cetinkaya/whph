import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_constants.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/ui/features/tasks/models/task_data.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';

/// Controller for QuickAddTaskDialog business logic.
/// Separates data management and operations from UI concerns.
class QuickAddTaskController extends ChangeNotifier {
  // Services
  final Mediator _mediator;
  final ITagRepository _tagRepository;
  final TasksService _tasksService;
  final ITranslationService _translationService;
  final IThemeService _themeService;

  // Initial values (stored for reset)
  final List<String>? _initialTagIds;
  final DateTime? _initialPlannedDate;
  final DateTime? _initialDeadlineDate;
  final EisenhowerPriority? _initialPriority;
  final int? _initialEstimatedTime;
  final String? _initialTitle;
  final String? _initialDescription;
  final bool? _initialCompleted;
  final String? _initialParentTaskId;

  // Task state
  EisenhowerPriority? _selectedPriority;
  int? _estimatedTime;
  DateTime? _plannedDate;
  DateTime? _deadlineDate;
  ReminderTime _plannedDateReminderTime = ReminderTime.none;
  int? _plannedDateReminderCustomOffset;
  ReminderTime _deadlineDateReminderTime = ReminderTime.none;
  int? _deadlineDateReminderCustomOffset;
  List<DropdownOption<String>> _selectedTags = [];
  bool _isEstimatedTimeExplicitlySet = false;
  bool _isReminderSetByUser = false;
  bool _isLoading = false;

  // Lock state
  bool _lockTags = false;
  bool _lockPriority = false;
  bool _lockEstimatedTime = false;
  bool _lockPlannedDate = false;
  bool _lockDeadlineDate = false;

  // UI visibility state
  bool _showEstimatedTimeSection = false;
  bool _showDescriptionSection = false;

  // Callbacks
  Function(String taskId, TaskData taskData)? onTaskCreated;

  // Getters
  EisenhowerPriority? get selectedPriority => _selectedPriority;
  int? get estimatedTime => _estimatedTime;
  DateTime? get plannedDate => _plannedDate;
  DateTime? get deadlineDate => _deadlineDate;
  ReminderTime get plannedDateReminderTime => _plannedDateReminderTime;
  int? get plannedDateReminderCustomOffset => _plannedDateReminderCustomOffset;
  ReminderTime get deadlineDateReminderTime => _deadlineDateReminderTime;
  int? get deadlineDateReminderCustomOffset => _deadlineDateReminderCustomOffset;
  List<DropdownOption<String>> get selectedTags => _selectedTags;
  bool get isEstimatedTimeExplicitlySet => _isEstimatedTimeExplicitlySet;
  bool get isLoading => _isLoading;
  bool get lockTags => _lockTags;
  bool get lockPriority => _lockPriority;
  bool get lockEstimatedTime => _lockEstimatedTime;
  bool get lockPlannedDate => _lockPlannedDate;
  bool get lockDeadlineDate => _lockDeadlineDate;
  bool get showEstimatedTimeSection => _showEstimatedTimeSection;
  bool get showDescriptionSection => _showDescriptionSection;
  String? get initialTitle => _initialTitle;
  String? get initialDescription => _initialDescription;
  bool? get initialCompleted => _initialCompleted;
  String? get initialParentTaskId => _initialParentTaskId;
  ITranslationService get translationService => _translationService;
  IThemeService get themeService => _themeService;

  QuickAddTaskController({
    Mediator? mediator,
    ITagRepository? tagRepository,
    TasksService? tasksService,
    ITranslationService? translationService,
    IThemeService? themeService,
    List<String>? initialTagIds,
    DateTime? initialPlannedDate,
    DateTime? initialDeadlineDate,
    EisenhowerPriority? initialPriority,
    int? initialEstimatedTime,
    String? initialTitle,
    String? initialDescription,
    bool? initialCompleted,
    String? initialParentTaskId,
    this.onTaskCreated,
  })  : _mediator = mediator ?? container.resolve<Mediator>(),
        _tagRepository = tagRepository ?? container.resolve<ITagRepository>(),
        _tasksService = tasksService ?? container.resolve<TasksService>(),
        _translationService = translationService ?? container.resolve<ITranslationService>(),
        _themeService = themeService ?? container.resolve<IThemeService>(),
        _initialTagIds = initialTagIds,
        _initialPlannedDate = initialPlannedDate,
        _initialDeadlineDate = initialDeadlineDate,
        _initialPriority = initialPriority,
        _initialEstimatedTime = initialEstimatedTime,
        _initialTitle = initialTitle,
        _initialDescription = initialDescription,
        _initialCompleted = initialCompleted,
        _initialParentTaskId = initialParentTaskId {
    _plannedDate = initialPlannedDate;
    _deadlineDate = initialDeadlineDate;
    _selectedPriority = initialPriority;
    _estimatedTime = initialEstimatedTime;
    _isEstimatedTimeExplicitlySet = initialEstimatedTime != null;

    if (initialDescription != null && initialDescription.isNotEmpty) {
      _showDescriptionSection = true;
      _showEstimatedTimeSection = false;
    }
  }

  /// Initialize controller - load tags and default values
  Future<void> initialize() async {
    await _loadInitialTags();
    if (_estimatedTime == null) {
      await _loadDefaultEstimatedTime();
    }
    // Only load default reminder if no reminder is explicitly set yet
    if (!_isReminderSetByUser) {
      await _loadDefaultPlannedDateReminder();
    }
  }

  /// Load default estimated time from settings
  Future<void> _loadDefaultEstimatedTime() async {
    try {
      final setting = await _mediator.send<GetSettingQuery, Setting?>(
        GetSettingQuery(key: SettingKeys.taskDefaultEstimatedTime),
      );

      if (setting != null) {
        final value = setting.getValue<int?>();
        if (value != null && value > 0) {
          _estimatedTime = value;
          notifyListeners();
        }
      }
    } catch (_) {
      // Setting not found or error - silently use default
      _estimatedTime = TaskConstants.defaultEstimatedTime;
      notifyListeners();
    }
  }

  /// Load default planned date reminder from settings
  Future<void> _loadDefaultPlannedDateReminder() async {
    try {
      final setting = await _mediator.send<GetSettingQuery, Setting?>(
        GetSettingQuery(key: SettingKeys.taskDefaultPlannedDateReminder),
      );

      if (setting != null) {
        final value = setting.getValue<String>();
        _plannedDateReminderTime = ReminderTimeExtension.fromString(value);

        if (_plannedDateReminderTime == ReminderTime.custom) {
          final offsetSetting = await _mediator.send<GetSettingQuery, Setting?>(
            GetSettingQuery(key: SettingKeys.taskDefaultPlannedDateReminderCustomOffset),
          );
          if (offsetSetting != null) {
            _plannedDateReminderCustomOffset = offsetSetting.getValue<int?>();
          }
        }
      } else {
        _plannedDateReminderTime = TaskConstants.defaultReminderTime;
      }
      notifyListeners();
    } catch (_) {
      // Setting not found or error - silently use default
      _plannedDateReminderTime = TaskConstants.defaultReminderTime;
      notifyListeners();
    }
  }

  /// Load initial tags and get their names
  Future<void> _loadInitialTags() async {
    if (_initialTagIds == null || _initialTagIds.isEmpty) return;

    try {
      List<DropdownOption<String>> tagOptions = [];
      for (String tagId in _initialTagIds) {
        final tag = await _tagRepository.getById(tagId);
        if (tag != null) {
          tagOptions.add(DropdownOption(
            label: tag.name.isNotEmpty ? tag.name : _translationService.translate(SharedTranslationKeys.untitled),
            value: tagId,
          ));
        }
      }
      _selectedTags = tagOptions;
      notifyListeners();
    } catch (e) {
      _selectedTags = _initialTagIds.map((id) => DropdownOption(label: '', value: id)).toList();
      notifyListeners();
    }
  }

  // State setters
  void setSelectedPriority(EisenhowerPriority? priority) {
    _selectedPriority = priority;
    notifyListeners();
  }

  void setEstimatedTime(int? time, {bool isExplicit = true}) {
    _estimatedTime = time;
    _isEstimatedTimeExplicitlySet = isExplicit;
    notifyListeners();
  }

  void setPlannedDate(DateTime? date, ReminderTime reminderTime, [int? customOffset]) {
    _plannedDate = date;
    _plannedDateReminderTime = reminderTime;
    _plannedDateReminderCustomOffset = customOffset;
    _isReminderSetByUser = true;
    notifyListeners();
  }

  void setDeadlineDate(DateTime? date, ReminderTime reminderTime, [int? customOffset]) {
    _deadlineDate = date;
    _deadlineDateReminderTime = reminderTime;
    _deadlineDateReminderCustomOffset = customOffset;
    notifyListeners();
  }

  void setSelectedTags(List<DropdownOption<String>> tags) {
    _selectedTags = tags;
    notifyListeners();
  }

  void toggleEstimatedTimeSection() {
    _showEstimatedTimeSection = !_showEstimatedTimeSection;
    _showDescriptionSection = false;
    notifyListeners();
  }

  void setShowEstimatedTimeSection(bool value) {
    _showEstimatedTimeSection = value;
    notifyListeners();
  }

  void toggleDescriptionSection() {
    _showDescriptionSection = !_showDescriptionSection;
    _showEstimatedTimeSection = false;
    notifyListeners();
  }

  void setShowDescriptionSection(bool value) {
    _showDescriptionSection = value;
    notifyListeners();
  }

  void toggleTagsLock() {
    _lockTags = !_lockTags;
    notifyListeners();
  }

  void togglePriorityLock() {
    _lockPriority = !_lockPriority;
    notifyListeners();
  }

  void toggleEstimatedTimeLock() {
    _lockEstimatedTime = !_lockEstimatedTime;
    notifyListeners();
  }

  void togglePlannedDateLock() {
    _lockPlannedDate = !_lockPlannedDate;
    notifyListeners();
  }

  void toggleDeadlineDateLock() {
    _lockDeadlineDate = !_lockDeadlineDate;
    notifyListeners();
  }

  /// Clear all fields respecting lock state
  Future<void> clearAllFields({
    required TextEditingController titleController,
    required TextEditingController descriptionController,
    required TextEditingController plannedDateController,
    required TextEditingController deadlineDateController,
    required BuildContext context,
  }) async {
    // Reset title
    if (_initialTitle != null) {
      titleController.text = _initialTitle;
    } else {
      titleController.clear();
    }

    // Clear description
    descriptionController.clear();

    // Reset unlocked values
    if (!_lockPriority) {
      _selectedPriority = _initialPriority;
    }

    if (!_lockEstimatedTime) {
      _estimatedTime = _initialEstimatedTime;
      if (_estimatedTime == null) {
        await _loadDefaultEstimatedTime();
      }
      _isEstimatedTimeExplicitlySet = _initialEstimatedTime != null && _initialEstimatedTime > 0;
      _showEstimatedTimeSection = _initialEstimatedTime != null && _initialEstimatedTime > 0;
      if (_showEstimatedTimeSection && descriptionController.text.isEmpty) {
        _showDescriptionSection = false;
      }
    }

    if (!_lockPlannedDate) {
      _plannedDate = _initialPlannedDate;
      plannedDateController.clear();
    }

    if (!_lockDeadlineDate) {
      _deadlineDate = _initialDeadlineDate;
      deadlineDateController.clear();
    }

    if (!_lockTags) {
      _selectedTags = [];
      await _loadInitialTags();
    }

    notifyListeners();
  }

  /// Create a new task
  Future<void> createTask({
    required BuildContext context,
    required String title,
    required String description,
    required FocusNode focusNode,
    required VoidCallback onClearFields,
    required bool isMobile,
    Function(String taskId)? onSuccess,
  }) async {
    if (_isLoading || title.isEmpty) return;

    _isLoading = true;
    notifyListeners();

    await AsyncErrorHandler.execute<SaveTaskCommandResponse>(
      context: context,
      errorMessage: _translationService.translate(TaskTranslationKeys.saveTaskError),
      errorPosition: isMobile ? NotificationPosition.top : NotificationPosition.bottom,
      operation: () async {
        final command = SaveTaskCommand(
          title: title,
          description: description.trim(),
          tagIdsToAdd: _selectedTags.map((t) => t.value).toList(),
          priority: _selectedPriority,
          estimatedTime: _estimatedTime,
          plannedDate: _plannedDate,
          deadlineDate: _deadlineDate,
          plannedDateReminderTime: _plannedDateReminderTime,
          plannedDateReminderCustomOffset: _plannedDateReminderCustomOffset,
          deadlineDateReminderTime: _deadlineDateReminderTime,
          deadlineDateReminderCustomOffset: _deadlineDateReminderCustomOffset,
          completedAt: (_initialCompleted ?? false) ? DateTime.now().toUtc() : null,
          parentTaskId: _initialParentTaskId,
        );
        return await _mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(command);
      },
      onSuccess: (response) {
        _tasksService.notifyTaskCreated(response.id);

        OverlayNotificationHelper.showSuccess(
          context: context,
          message: _translationService.translate(
            TaskTranslationKeys.taskAddedSuccessfully,
            namedArgs: {'title': title},
          ),
          position: isMobile ? NotificationPosition.top : NotificationPosition.bottom,
        );

        if (onTaskCreated != null) {
          final taskData = TaskData(
            title: title,
            priority: _selectedPriority,
            estimatedTime: _estimatedTime,
            plannedDate: _plannedDate?.toUtc(),
            deadlineDate: _deadlineDate?.toUtc(),
            tags: _selectedTags.map((t) => TaskDataTag(id: t.value, name: t.label)).toList(),
            isCompleted: false,
            parentTaskId: _initialParentTaskId,
            order: 0.0,
            createdDate: DateTime.now().toUtc(),
          );
          onTaskCreated!(response.id, taskData);
        }

        if (onSuccess != null) {
          onSuccess(response.id);
        }

        onClearFields();

        if (onSuccess == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            focusNode.requestFocus();
          });
        }
      },
      finallyAction: () {
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Tooltip generators
  String getEstimatedTimeTooltip() {
    if (_estimatedTime == null || _estimatedTime == 0) {
      return _translationService.translate(TaskTranslationKeys.quickTaskEstimatedTimeNotSet);
    }

    if (_isEstimatedTimeExplicitlySet) {
      return _translationService.translate(
        TaskTranslationKeys.quickTaskEstimatedTime,
        namedArgs: {'time': SharedUiConstants.formatMinutes(_estimatedTime)},
      );
    } else {
      final formattedTime = SharedUiConstants.formatMinutes(_estimatedTime);
      final defaultText = _translationService.translate(TaskTranslationKeys.quickTaskEstimatedTimeDefault);
      return _translationService.translate(
        TaskTranslationKeys.quickTaskEstimatedTime,
        namedArgs: {'time': '$formattedTime $defaultText'},
      );
    }
  }

  String getDateTooltip(bool isDeadline) {
    final date = isDeadline ? _deadlineDate : _plannedDate;

    if (date == null) {
      return _translationService.translate(
        isDeadline ? TaskTranslationKeys.quickTaskDeadlineDateNotSet : TaskTranslationKeys.quickTaskPlannedDateNotSet,
      );
    }

    final formattedDate = _formatDate(date);
    return _translationService.translate(
      isDeadline ? TaskTranslationKeys.quickTaskDeadlineDate : TaskTranslationKeys.quickTaskPlannedDate,
      namedArgs: {'date': formattedDate},
    );
  }

  String getTagsTooltip() {
    if (_selectedTags.isEmpty) {
      return _translationService.translate(TaskTranslationKeys.tagsLabel);
    }

    final tagNames = _selectedTags.map((tag) => tag.label).where((name) => name.isNotEmpty).toList();
    if (tagNames.isEmpty) {
      return _translationService.translate(TaskTranslationKeys.tagsLabel);
    }

    return tagNames.join(', ');
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color getTagColor() => TaskUiConstants.getTagColor(_themeService);

  Color? getPriorityColor() => TaskUiConstants.getPriorityColor(_selectedPriority);

  String getPriorityTooltip() => TaskUiConstants.getPriorityTooltip(_selectedPriority, _translationService);
}
