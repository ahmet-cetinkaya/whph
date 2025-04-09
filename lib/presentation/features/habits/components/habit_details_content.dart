import 'dart:async';

import 'package:flutter/material.dart';
import 'package:markdown_editor_plus/markdown_editor_plus.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/commands/add_habit_record_command.dart';
import 'package:whph/application/features/habits/commands/delete_habit_record_command.dart';
import 'package:whph/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/application/features/habits/commands/add_habit_tag_command.dart';
import 'package:whph/application/features/habits/commands/remove_habit_tag_command.dart';
import 'package:whph/application/features/habits/queries/get_list_habit_tags_query.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/services/habits_service.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/shared/components/detail_table.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/habits/components/habit_calendar_view.dart';
import 'package:whph/presentation/features/habits/components/habit_statistics_view.dart';
import 'package:whph/presentation/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/habits/constants/habit_translation_keys.dart';

class HabitDetailsContent extends StatefulWidget {
  final Mediator _mediator = container.resolve<Mediator>();
  final HabitsService _habitsService = container.resolve<HabitsService>();

  final String habitId;
  final VoidCallback? onHabitUpdated;
  final Function(String)? onNameUpdated;

  HabitDetailsContent({
    super.key,
    required this.habitId,
    this.onHabitUpdated,
    this.onNameUpdated,
  });

  @override
  State<HabitDetailsContent> createState() => _HabitDetailsContentState();
}

class _HabitDetailsContentState extends State<HabitDetailsContent> {
  GetHabitQueryResponse? _habit;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  Timer? _debounce;

  GetListHabitRecordsQueryResponse? _habitRecords;
  GetListHabitTagsQueryResponse? _habitTags;

  DateTime currentMonth = DateTime.now();
  final _translationService = container.resolve<ITranslationService>();

  // Set to track which optional fields are visible
  final Set<String> _visibleOptionalFields = {};

  // Define optional field keys
  static const String keyTags = 'tags';
  static const String keyEstimatedTime = 'estimatedTime';
  static const String keyDescription = 'description';

  @override
  void initState() {
    _getHabit();
    _getHabitRecordsForMonth(currentMonth);
    _getHabitTags();
    widget._habitsService.onHabitSaved.addListener(_getHabit);

    super.initState();
  }

  @override
  void dispose() {
    widget._habitsService.onHabitSaved.removeListener(_getHabit);
    _nameController.dispose();
    _descriptionController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _getHabit() async {
    try {
      final query = GetHabitQuery(id: widget.habitId);
      final result = await widget._mediator.send<GetHabitQuery, GetHabitQueryResponse>(query);

      if (mounted) {
        setState(() {
          _habit = result;
          if (_nameController.text != result.name) {
            _nameController.text = result.name;
            widget.onNameUpdated?.call(result.name);
          }
          _descriptionController.text = _habit!.description;
        });
        _processFieldVisibility();
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: _translationService.translate(HabitTranslationKeys.loadingDetailsError));
      }
    }
  }

  Future<void> _getHabitRecordsForMonth(DateTime month) async {
    try {
      final firstDayOfMonth = DateTime(month.year, month.month - 1, 23);
      final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

      final query = GetListHabitRecordsQuery(
        pageIndex: 0,
        pageSize: 37,
        habitId: widget.habitId,
        startDate: firstDayOfMonth,
        endDate: lastDayOfMonth,
      );
      final result = await widget._mediator.send<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse>(query);
      _habitRecords = result;
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: _translationService.translate(HabitTranslationKeys.loadingRecordsError));
      }
    }
  }

  Future<void> _createHabitRecord(String habitId, DateTime date) async {
    try {
      final command = AddHabitRecordCommand(habitId: habitId, date: date);
      await widget._mediator.send<AddHabitRecordCommand, AddHabitRecordCommandResponse>(command);
      if (mounted) {
        setState(() {
          _getHabitRecordsForMonth(currentMonth);
          _getHabit();
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: _translationService.translate(HabitTranslationKeys.creatingRecordError));
      }
    }
  }

  Future<void> _deleteHabitRecord(String id) async {
    try {
      final command = DeleteHabitRecordCommand(id: id);
      await widget._mediator.send<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse>(command);
      if (mounted) {
        setState(() {
          _getHabitRecordsForMonth(currentMonth);
          _getHabit();
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: _translationService.translate(HabitTranslationKeys.deletingRecordError));
      }
    }
  }

  Future<void> _getHabitTags() async {
    int pageIndex = 0;
    const int pageSize = 50;

    while (true) {
      final query = GetListHabitTagsQuery(habitId: widget.habitId, pageIndex: pageIndex, pageSize: pageSize);
      try {
        final response = await widget._mediator.send<GetListHabitTagsQuery, GetListHabitTagsQueryResponse>(query);

        if (mounted) {
          setState(() {
            if (_habitTags == null) {
              _habitTags = response;
            } else {
              _habitTags!.items.addAll(response.items);
            }
          });
        }
        pageIndex++;
      } catch (e, stackTrace) {
        if (mounted) {
          ErrorHelper.showUnexpectedError(
            context,
            e as Exception,
            stackTrace,
            message: _translationService.translate(HabitTranslationKeys.loadingTagsError),
          );
          break;
        }
      }
    }
  }

  Future<void> _addTag(String tagId) async {
    try {
      final command = AddHabitTagCommand(habitId: widget.habitId, tagId: tagId);
      await widget._mediator.send(command);
      await _getHabitTags();
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: _translationService.translate(HabitTranslationKeys.addingTagError));
      }
    }
  }

  Future<void> _removeTag(String id) async {
    try {
      final command = RemoveHabitTagCommand(id: id);
      await widget._mediator.send(command);
      await _getHabitTags();
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: _translationService.translate(HabitTranslationKeys.removingTagError));
      }
    }
  }

  void _onTagsSelected(List<DropdownOption<String>> tagOptions) {
    if (_habitTags == null) return;

    final tagsToAdd = tagOptions
        .where((tagOption) => !_habitTags!.items.any((habitTag) => habitTag.tagId == tagOption.value))
        .map((option) => option.value)
        .toList();

    final tagsToRemove =
        _habitTags!.items.where((habitTag) => !tagOptions.map((tag) => tag.value).contains(habitTag.tagId)).toList();

    for (final tagId in tagsToAdd) {
      _addTag(tagId);
    }
    for (final habitTag in tagsToRemove) {
      _removeTag(habitTag.id);
    }
  }

  Future<void> _saveHabit() async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final currentSelection = _nameController.selection;

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final command = SaveHabitCommand(
        id: widget.habitId,
        name: _nameController.text,
        description: _descriptionController.text,
        estimatedTime: _habit!.estimatedTime,
      );
      try {
        final result = await widget._mediator.send<SaveHabitCommand, SaveHabitCommandResponse>(command);

        widget._habitsService.onHabitSaved.value = result;
        widget.onHabitUpdated?.call();

        if (mounted) {
          _nameController.selection = currentSelection;
        }
      } on BusinessException catch (e) {
        if (mounted) {
          ErrorHelper.showError(context, e);
        }
      } catch (e, stackTrace) {
        if (mounted) {
          ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
              message: _translationService.translate(HabitTranslationKeys.savingDetailsError));
        }
      }
    });
  }

  void _previousMonth() {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month - 1, 1);
      _getHabitRecordsForMonth(currentMonth);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);

    if (nextMonth.isAfter(now)) return; // Don't allow navigation to future months

    setState(() {
      currentMonth = nextMonth;
      _getHabitRecordsForMonth(currentMonth);
    });
  }

  // Process field content and update UI after habit data is loaded
  void _processFieldVisibility() {
    if (_habit == null) return;

    setState(() {
      // Make fields with content automatically visible
      if (_hasFieldContent(keyTags)) _visibleOptionalFields.add(keyTags);
      if (_hasFieldContent(keyEstimatedTime)) _visibleOptionalFields.add(keyEstimatedTime);
      if (_hasFieldContent(keyDescription)) _visibleOptionalFields.add(keyDescription);
    });
  }

  // Toggles visibility of an optional field
  void _toggleOptionalField(String fieldKey) {
    setState(() {
      if (_visibleOptionalFields.contains(fieldKey)) {
        _visibleOptionalFields.remove(fieldKey);
      } else {
        _visibleOptionalFields.add(fieldKey);
      }
    });
  }

  // Checks if field should be shown in the content
  bool _isFieldVisible(String fieldKey) {
    return _visibleOptionalFields.contains(fieldKey);
  }

  // Check if the field should be displayed in the chips section
  bool _shouldShowAsChip(String fieldKey) {
    return !_visibleOptionalFields.contains(fieldKey);
  }

  // Method to determine if a field has content
  bool _hasFieldContent(String fieldKey) {
    if (_habit == null) return false;

    switch (fieldKey) {
      case keyTags:
        return _habitTags != null && _habitTags!.items.isNotEmpty;
      case keyEstimatedTime:
        return _habit!.estimatedTime != null && _habit!.estimatedTime! > 0;
      case keyDescription:
        return _habit!.description != null && _habit!.description!.isNotEmpty;
      default:
        return false;
    }
  }

  // Get descriptive label for field chips
  String _getFieldLabel(String fieldKey) {
    switch (fieldKey) {
      case keyTags:
        return _translationService.translate(HabitTranslationKeys.tagsLabel);
      case keyEstimatedTime:
        return _translationService.translate(HabitTranslationKeys.estimatedTimeLabel);
      case keyDescription:
        return _translationService.translate(HabitTranslationKeys.descriptionLabel);
      default:
        return '';
    }
  }

  // Get icon for field chips
  IconData _getFieldIcon(String fieldKey) {
    switch (fieldKey) {
      case keyTags:
        return HabitUiConstants.tagsIcon;
      case keyEstimatedTime:
        return HabitUiConstants.estimatedTimeIcon;
      case keyDescription:
        return HabitUiConstants.descriptionIcon;
      default:
        return Icons.add;
    }
  }

  // Widget to build optional field chips
  Widget _buildOptionalFieldChip(String fieldKey, bool hasContent) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_getFieldLabel(fieldKey)),
          const SizedBox(width: 4),
          Icon(Icons.add, size: AppTheme.iconSizeSmall),
        ],
      ),
      avatar: Icon(
        _getFieldIcon(fieldKey),
        size: AppTheme.iconSizeSmall,
      ),
      selected: _isFieldVisible(fieldKey),
      onSelected: (_) => _toggleOptionalField(fieldKey),
      backgroundColor: hasContent ? Theme.of(context).colorScheme.secondary.withOpacity(0.1) : null,
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_habit == null) {
      return const SizedBox.shrink();
    }

    // Don't show fields with content in the chips section
    final List<String> availableChipFields = [
      keyTags,
      keyEstimatedTime,
      keyDescription,
    ].where((field) => _shouldShowAsChip(field)).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameController,
            maxLines: null,
            onChanged: (value) async {
              await _saveHabit();
              widget.onNameUpdated?.call(value);
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffixIcon: Tooltip(
                message: _translationService.translate(HabitTranslationKeys.editNameTooltip),
                child: Icon(Icons.edit, size: AppTheme.iconSizeSmall),
              ),
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppTheme.sizeSmall),

          // Tags and Estimated Time Table
          if (_isFieldVisible(keyTags) || _isFieldVisible(keyEstimatedTime))
            DetailTable(rowData: [
              if (_isFieldVisible(keyTags)) _buildTagsSection(),
              if (_isFieldVisible(keyEstimatedTime)) _buildEstimatedTimeSection(),
            ]),

          // Description Table
          if (_isFieldVisible(keyDescription))
            DetailTable(
              forceVertical: true,
              rowData: [
                DetailTableRowData(
                  label: _translationService.translate(HabitTranslationKeys.descriptionLabel),
                  icon: HabitUiConstants.descriptionIcon,
                  hintText: SharedUiConstants.markdownEditorHint,
                  widget: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: MarkdownAutoPreview(
                      controller: _descriptionController,
                      onChanged: _onDescriptionChanged,
                      hintText: SharedUiConstants.addDescriptionHint,
                      toolbarBackground: AppTheme.surface1,
                      style: AppTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 16),

          // Optional field chips moved to just above Records header
          if (availableChipFields.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableChipFields.map((fieldKey) => _buildOptionalFieldChip(fieldKey, false)).toList(),
            ),
            const SizedBox(height: AppTheme.sizeSmall),
          ],

          // Records and Statistics Section
          _buildRecordsHeader(),
          if (_habitRecords != null)
            HabitCalendarView(
              currentMonth: currentMonth,
              records: _habitRecords!.items,
              onDeleteRecord: _deleteHabitRecord,
              onCreateRecord: _createHabitRecord,
              onPreviousMonth: _previousMonth,
              onNextMonth: _nextMonth,
              habitId: widget.habitId,
            ),

          // Statistics
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: HabitStatisticsView(statistics: _habit!.statistics),
          ),
        ],
      ),
    );
  }

  DetailTableRowData _buildTagsSection() => DetailTableRowData(
        label: _translationService.translate(HabitTranslationKeys.tagsLabel),
        icon: HabitUiConstants.tagsIcon,
        hintText: _translationService.translate(HabitTranslationKeys.tagsHint),
        widget: _habitTags != null
            ? TagSelectDropdown(
                key: ValueKey(_habitTags!.items.length),
                isMultiSelect: true,
                onTagsSelected: _onTagsSelected,
                showSelectedInDropdown: true,
                initialSelectedTags: _habitTags!.items
                    .map((tag) => DropdownOption<String>(value: tag.tagId, label: tag.tagName))
                    .toList(),
                icon: SharedUiConstants.addIcon,
              )
            : Container(),
      );

  DetailTableRowData _buildEstimatedTimeSection() => DetailTableRowData(
        label: _translationService.translate(HabitTranslationKeys.estimatedTimeLabel),
        icon: HabitUiConstants.estimatedTimeIcon,
        widget: Row(
          children: [
            IconButton(
              onPressed: () => _adjustEstimatedTime(-1),
              icon: const Icon(Icons.remove),
            ),
            Text(
              _habit!.estimatedTime == null
                  ? _translationService.translate(HabitTranslationKeys.estimatedTimeNotSet)
                  : SharedUiConstants.formatMinutes(_habit!.estimatedTime!),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: () => _adjustEstimatedTime(1),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      );

  void _adjustEstimatedTime(int adjustment) {
    if (!mounted) return;
    setState(() {
      final currentIndex = HabitUiConstants.defaultEstimatedTimeOptions.indexOf(_habit!.estimatedTime ?? 0);
      if (currentIndex == -1) {
        _habit!.estimatedTime = HabitUiConstants.defaultEstimatedTimeOptions.first;
      } else {
        final newIndex = (currentIndex + adjustment).clamp(
          0,
          HabitUiConstants.defaultEstimatedTimeOptions.length - 1,
        );
        _habit!.estimatedTime = HabitUiConstants.defaultEstimatedTimeOptions[newIndex];
      }
      _saveHabit();
    });
  }

  Widget _buildRecordsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: _buildSectionHeader(
          HabitUiConstants.recordIcon, _translationService.translate(HabitTranslationKeys.recordsLabel)),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Icon(icon),
        ),
        Text(title, style: AppTheme.bodyLarge),
      ],
    );
  }

  void _onDescriptionChanged(String value) {
    if (value.trim().isEmpty) {
      _descriptionController.clear();
    }
    _saveHabit();
  }
}
