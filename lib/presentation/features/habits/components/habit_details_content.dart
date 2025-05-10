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
  final String habitId;
  final VoidCallback? onHabitUpdated;
  final Function(String)? onNameUpdated;

  const HabitDetailsContent({
    super.key,
    required this.habitId,
    this.onHabitUpdated,
    this.onNameUpdated,
  });

  @override
  State<HabitDetailsContent> createState() => _HabitDetailsContentState();
}

class _HabitDetailsContentState extends State<HabitDetailsContent> {
  final _mediator = container.resolve<Mediator>();
  final _habitsService = container.resolve<HabitsService>();
  final _translationService = container.resolve<ITranslationService>();

  GetHabitQueryResponse? _habit;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  Timer? _debounce;

  GetListHabitRecordsQueryResponse? _habitRecords;
  GetListHabitTagsQueryResponse? _habitTags;

  DateTime currentMonth = DateTime.now();

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

    // Add event listeners
    _habitsService.onHabitUpdated.addListener(_handleHabitUpdated);
    _habitsService.onHabitRecordAdded.addListener(_handleHabitRecordChanged);
    _habitsService.onHabitRecordRemoved.addListener(_handleHabitRecordChanged);

    super.initState();
  }

  @override
  void dispose() {
    _habitsService.onHabitUpdated.removeListener(_handleHabitUpdated);
    _habitsService.onHabitRecordAdded.removeListener(_handleHabitRecordChanged);
    _habitsService.onHabitRecordRemoved.removeListener(_handleHabitRecordChanged);

    _nameController.dispose();
    _descriptionController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _handleHabitUpdated() {
    if (!mounted || _habitsService.onHabitUpdated.value != widget.habitId) return;
    _getHabit();
    _getHabitTags(); // Also refresh tags when habit is updated
  }

  void _handleHabitRecordChanged() {
    if (!mounted || _habitsService.onHabitRecordAdded.value != widget.habitId) return;
    _getHabitRecordsForMonth(currentMonth);
    _getHabit(); // Refresh statistics
  }

  Future<void> _getHabit() async {
    try {
      final query = GetHabitQuery(id: widget.habitId);
      final result = await _mediator.send<GetHabitQuery, GetHabitQueryResponse>(query);

      if (mounted) {
        // Store current selections before updating
        final nameSelection = _nameController.selection;
        final descriptionSelection = _descriptionController.selection;

        setState(() {
          _habit = result;

          // Only update name if it's different
          if (_nameController.text != result.name) {
            _nameController.text = result.name;
            widget.onNameUpdated?.call(result.name);
            // Don't restore selection for name if it changed
          } else if (nameSelection.isValid) {
            // Restore selection if name didn't change
            _nameController.selection = nameSelection;
          }

          // Only update description if it's different
          if (_descriptionController.text != _habit!.description) {
            _descriptionController.text = _habit!.description;
            // Don't restore selection if text changed
          } else if (descriptionSelection.isValid) {
            // Restore selection if text didn't change
            _descriptionController.selection = descriptionSelection;
          }
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
      final result = await _mediator.send<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse>(query);
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
      await _mediator.send<AddHabitRecordCommand, AddHabitRecordCommandResponse>(command);
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
      await _mediator.send<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse>(command);
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

    // Clear existing tags first to avoid duplications
    if (mounted) {
      setState(() {
        if (_habitTags != null) {
          _habitTags!.items.clear();
        }
      });
    }

    while (true) {
      final query = GetListHabitTagsQuery(habitId: widget.habitId, pageIndex: pageIndex, pageSize: pageSize);
      try {
        final response = await _mediator.send<GetListHabitTagsQuery, GetListHabitTagsQueryResponse>(query);

        if (mounted) {
          setState(() {
            if (_habitTags == null) {
              _habitTags = response;
            } else {
              _habitTags!.items.addAll(response.items);
            }
          });

          // Process field visibility again after tags are loaded
          _processFieldVisibility();
        }

        // Break out of the loop if we've fetched all tags or received an empty page
        if (response.items.isEmpty || response.items.length < pageSize) {
          break;
        }

        pageIndex++;
      } catch (e, stackTrace) {
        if (mounted) {
          // Create a proper Exception object if the error isn't one already
          final exception = e is Exception ? e : Exception(e.toString());

          ErrorHelper.showUnexpectedError(
            context,
            exception,
            stackTrace,
            message: _translationService.translate(HabitTranslationKeys.loadingTagsError),
          );
          break;
        }
      }
    }
  }

  // Remove redundant _addTag and _removeTag methods since we already have _addTagToHabit and _removeTagFromHabit
  void _onTagsSelected(List<DropdownOption<String>> tagOptions) {
    if (_habitTags == null) return;

    final tagsToAdd = tagOptions
        .where((tagOption) => !_habitTags!.items.any((habitTag) => habitTag.tagId == tagOption.value))
        .map((option) => option.value)
        .toList();

    final tagsToRemove =
        _habitTags!.items.where((habitTag) => !tagOptions.map((tag) => tag.value).contains(habitTag.tagId)).toList();

    // Batch process all tag operations
    Future<void> processTags() async {
      // Add all tags
      for (final tagId in tagsToAdd) {
        await _addTagToHabit(tagId);
      }

      // Remove all tags
      for (final habitTag in tagsToRemove) {
        await _removeTagFromHabit(habitTag.id);
      }

      // Notify only once after all tag operations are complete
      if (tagsToAdd.isNotEmpty || tagsToRemove.isNotEmpty) {
        _habitsService.notifyHabitUpdated(widget.habitId);
      }
    }

    // Execute the tag operations
    processTags();
  }

  Future<void> _saveHabit() async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 1000), () async {
      if (!mounted) return;

      final command = SaveHabitCommand(
        id: widget.habitId,
        name: _nameController.text,
        description: _descriptionController.text,
        estimatedTime: _habit!.estimatedTime,
      );
      try {
        await _mediator.send<SaveHabitCommand, SaveHabitCommandResponse>(command);

        // Notify that habit was updated
        _habitsService.notifyHabitUpdated(widget.habitId);
        widget.onHabitUpdated?.call();
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
    // Don't show chip if field is already visible OR if it has content
    return !_visibleOptionalFields.contains(fieldKey) && !_hasFieldContent(fieldKey);
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
        return _habit!.description.isNotEmpty;
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
      backgroundColor: hasContent ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1) : null,
      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
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
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nameController,
                  maxLines: null,
                  onChanged: (value) {
                    _saveHabit();
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
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                ),
                child: IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () => _createHabitRecord(widget.habitId, DateTime.now()),
                  tooltip: _translationService.translate(HabitTranslationKeys.createRecordTooltip),
                ),
              ),
            ],
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
            child: HabitStatisticsView(
              statistics: _habit!.statistics,
              habitId: widget.habitId,
            ),
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
                onTagsSelected: (List<DropdownOption<String>> tagOptions, bool _) => _onTagsSelected(tagOptions),
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
    // Handle empty whitespace
    if (value.trim().isEmpty) {
      _descriptionController.clear();

      // Set cursor at beginning after clearing
      if (mounted) {
        _descriptionController.selection = const TextSelection.collapsed(offset: 0);
      }
    }

    // Simply trigger the update
    _saveHabit();
  }

  // Add methods to handle tag operations
  Future<bool> _addTagToHabit(String tagId) async {
    try {
      final command = AddHabitTagCommand(habitId: widget.habitId, tagId: tagId);
      await _mediator.send(command);
      await _getHabitTags();
      return true;
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(HabitTranslationKeys.addingTagError),
        );
      }
      return false;
    }
  }

  Future<bool> _removeTagFromHabit(String id) async {
    try {
      final command = RemoveHabitTagCommand(id: id);
      await _mediator.send(command);
      await _getHabitTags();
      return true;
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(HabitTranslationKeys.removingTagError),
        );
      }
      return false;
    }
  }
}
