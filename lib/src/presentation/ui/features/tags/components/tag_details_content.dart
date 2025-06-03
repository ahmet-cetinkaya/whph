import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/tags/commands/add_tag_tag_command.dart';
import 'package:whph/src/core/application/features/tags/commands/remove_tag_tag_command.dart';
import 'package:whph/src/core/application/features/tags/commands/save_tag_command.dart';
import 'package:whph/src/core/application/features/tags/queries/get_list_tag_tags_query.dart';
import 'package:whph/src/core/application/features/tags/queries/get_tag_query.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/src/presentation/ui/shared/components/detail_table.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/src/presentation/ui/shared/extensions/color_extensions.dart';
import 'package:whph/src/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/src/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/src/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/src/presentation/ui/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/components/color_field.dart';
import 'package:whph/src/presentation/ui/features/tags/services/tags_service.dart';

class TagDetailsContent extends StatefulWidget {
  final String tagId;
  final VoidCallback? onTagUpdated;
  final Function(String)? onNameUpdated;

  const TagDetailsContent({
    super.key,
    required this.tagId,
    this.onTagUpdated,
    this.onNameUpdated,
  });

  @override
  State<TagDetailsContent> createState() => _TagDetailsContentState();
}

class _TagDetailsContentState extends State<TagDetailsContent> {
  final Mediator _mediator = container.resolve<Mediator>();
  final TagsService _tagsService = container.resolve<TagsService>();
  final _translationService = container.resolve<ITranslationService>();
  final _nameController = TextEditingController();
  Timer? _debounce;
  GetTagQueryResponse? _tag;
  GetListTagTagsQueryResponse? _tagTags;

  // State for showing/hiding optional properties
  final Set<String> _visibleOptionalFields = {};

  // Define optional field keys
  static const String keyColor = 'color';
  static const String keyRelatedTags = 'relatedTags';
  static const String keyArchived = 'archived';

  @override
  void initState() {
    _getInitialData();
    super.initState();
  }

  @override
  void dispose() {
    // Notify parent about name changes before disposing
    if (widget.onNameUpdated != null && _nameController.text.isNotEmpty) {
      widget.onNameUpdated!(_nameController.text);
    }

    _nameController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Process field content and update UI after tag data is loaded
  void _processFieldVisibility() {
    if (_tag == null) return;

    setState(() {
      // Make fields with content automatically visible
      if (_hasFieldContent(keyColor)) _visibleOptionalFields.add(keyColor);
      if (_hasFieldContent(keyRelatedTags)) _visibleOptionalFields.add(keyRelatedTags);
      if (_hasFieldContent(keyArchived)) _visibleOptionalFields.add(keyArchived);
    });
  }

  // Check if the field should be displayed in the chips section
  bool _shouldShowAsChip(String fieldKey) {
    // Don't show chip if field is already visible OR if it has content
    return !_visibleOptionalFields.contains(fieldKey) && !_hasFieldContent(fieldKey);
  }

  // Method to determine if a field has content
  bool _hasFieldContent(String fieldKey) {
    if (_tag == null) return false;

    switch (fieldKey) {
      case keyColor:
        return _tag!.color != null && _tag!.color!.isNotEmpty;
      case keyRelatedTags:
        return _tagTags != null && _tagTags!.items.isNotEmpty;
      case keyArchived:
        return _tag!.isArchived;
      default:
        return false;
    }
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

  Future<void> _getInitialData() async {
    await Future.wait([_getTag(), _getTagTags()]);
  }

  Future<void> _getTag() async {
    await AsyncErrorHandler.execute(
      context: context,
      errorMessage: _translationService.translate(TagTranslationKeys.errorLoading),
      operation: () async {
        final query = GetTagQuery(id: widget.tagId);
        return await _mediator.send<GetTagQuery, GetTagQueryResponse>(query);
      },
      onSuccess: (response) {
        final nameSelection = _nameController.selection;

        setState(() {
          _tag = response;
          if (_nameController.text != response.name) {
            _nameController.text = response.name;
            widget.onNameUpdated?.call(response.name);
          } else if (nameSelection.isValid) {
            _nameController.selection = nameSelection;
          }
        });

        // Process field visibility after loading tag
        _processFieldVisibility();
      },
    );
  }

  Future<void> _getTagTags() async {
    int pageIndex = 0;
    const int pageSize = 50;

    // Clear existing data - to prevent duplicate tags
    if (mounted) {
      setState(() {
        if (_tagTags != null) {
          _tagTags!.items.clear();
        }
      });
    }

    while (true) {
      final query = GetListTagTagsQuery(primaryTagId: widget.tagId, pageIndex: pageIndex, pageSize: pageSize);

      final response = await AsyncErrorHandler.execute<GetListTagTagsQueryResponse>(
        context: context,
        errorMessage: _translationService.translate(TagTranslationKeys.errorLoading),
        operation: () async {
          return await _mediator.send<GetListTagTagsQuery, GetListTagTagsQueryResponse>(query);
        },
        onSuccess: (result) {
          setState(() {
            if (_tagTags == null) {
              _tagTags = result;
            } else {
              _tagTags!.items.addAll(result.items);
            }
          });
        },
      );

      // If call failed or no more items, exit the loop
      if (response == null || response.items.isEmpty || response.items.length < pageSize) {
        break;
      }

      pageIndex++;
    }

    // Update visibility status after loading tag data
    _processFieldVisibility();
  }

  // Process all tag changes in bulk
  void _onTagsSelected(List<DropdownOption<String>> tagOptions) {
    if (_tagTags == null) return;

    // Identify tag changes
    final tagIdsToAdd = tagOptions
        .where((tagOption) => !_tagTags!.items.any((tagTag) => tagTag.secondaryTagId == tagOption.value))
        .map((option) => option.value)
        .toList();

    final tagTagsToRemove =
        _tagTags!.items.where((tagTag) => !tagOptions.map((tag) => tag.value).contains(tagTag.secondaryTagId)).toList();

    // Only proceed if there are changes
    if (tagIdsToAdd.isEmpty && tagTagsToRemove.isEmpty) return;

    // Process all tag changes
    AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(TagTranslationKeys.errorSaving),
      operation: () async {
        // Add tags
        for (final tagId in tagIdsToAdd) {
          final command = AddTagTagCommand(primaryTagId: _tag!.id, secondaryTagId: tagId);
          await _mediator.send(command);
        }

        // Remove tags
        for (final tagTag in tagTagsToRemove) {
          final command = RemoveTagTagCommand(id: tagTag.id);
          await _mediator.send(command);
        }
      },
      onSuccess: () async {
        await _getTagTags(); // Refresh tag list
        _tagsService.notifyTagUpdated(widget.tagId);
        widget.onTagUpdated?.call();
      },
    );
  }

  // Helper methods for repeated patterns
  void _forceImmediateUpdate() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
  }

  SaveTagCommand _buildSaveCommand() {
    return SaveTagCommand(
      id: widget.tagId,
      name: _nameController.text,
      color: _tag!.color,
      isArchived: _tag!.isArchived,
    );
  }

  Future<void> _executeSaveCommand() async {
    await _mediator.send(_buildSaveCommand());
  }

  void _handleFieldChange<T>(T value, VoidCallback? onUpdate) {
    _forceImmediateUpdate();
    _saveTag();
    onUpdate?.call();
  }

  // Event handler methods
  void _onNameChanged(String value) {
    _handleFieldChange(value, () => widget.onNameUpdated?.call(value));
  }

  Future<void> _saveTag() async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Increase debounce time to give user more time to type
    _debounce = Timer(SharedUiConstants.contentSaveDebounceTime, () async {
      if (!mounted) return;

      await AsyncErrorHandler.executeVoid(
        context: context,
        errorMessage: _translationService.translate(TagTranslationKeys.errorSaving),
        operation: _executeSaveCommand,
        onSuccess: () {
          widget.onTagUpdated?.call();
          _tagsService.notifyTagUpdated(widget.tagId);
        },
      );
    });
  }

  void _onChangeColor(Color color) {
    if (mounted) {
      setState(() {
        // Remove the FF prefix from the hex string if it exists
        final hexString = color.toHexString();
        _tag!.color = hexString.startsWith('FF') ? hexString.substring(2) : hexString;
      });
    }
    _saveTag();
  }

  @override
  Widget build(BuildContext context) {
    if (_tag == null || _tagTags == null) {
      return const SizedBox.shrink();
    }

    // Don't show fields with content in the chips section
    final List<String> availableChipFields = [
      keyColor,
      // Only show related tags chip if there are no related tags and it's not already visible
      if (_tagTags != null && _tagTags!.items.isEmpty && !_visibleOptionalFields.contains(keyRelatedTags))
        keyRelatedTags,
    ].where((field) => _shouldShowAsChip(field)).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag Name (always visible - mandatory field)
          TextFormField(
            controller: _nameController,
            maxLines: null,
            onChanged: _onNameChanged,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffixIcon: Tooltip(
                message: _translationService.translate(TagTranslationKeys.editNameTooltip),
                child: Icon(Icons.edit, size: AppTheme.iconSizeSmall),
              ),
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),

          // Optional properties when visible
          if (_visibleOptionalFields.isNotEmpty ||
              _tag!.isArchived ||
              (_tagTags != null && _tagTags!.items.isNotEmpty)) ...[
            const SizedBox(height: AppTheme.size2XSmall),
            DetailTable(
              rowData: [
                if (_visibleOptionalFields.contains(keyColor))
                  DetailTableRowData(
                    label: _translationService.translate(TagTranslationKeys.colorLabel),
                    icon: TagUiConstants.colorIcon,
                    widget: ColorField(
                      initialColor: _tag!.color != null && _tag!.color!.isNotEmpty
                          ? Color(int.parse("FF${_tag!.color}", radix: 16))
                          : Colors.blue,
                      onColorChanged: _onChangeColor,
                    ),
                  ),
                if (_tagTags != null && (_tagTags!.items.isNotEmpty || _visibleOptionalFields.contains(keyRelatedTags)))
                  DetailTableRowData(
                    label: _translationService.translate(TagTranslationKeys.detailsRelatedTags),
                    icon: TagUiConstants.tagIcon,
                    hintText: _translationService.translate(TagTranslationKeys.selectTooltip),
                    widget: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: TagSelectDropdown(
                        key: ValueKey('${_tagTags!.items.length}_${_visibleOptionalFields.contains(keyRelatedTags)}'),
                        isMultiSelect: true,
                        onTagsSelected: (tagOptions, _) => _onTagsSelected(tagOptions),
                        showSelectedInDropdown: true,
                        initialSelectedTags: _tagTags!.items
                            .map((tag) => DropdownOption<String>(
                                  value: tag.secondaryTagId,
                                  label: tag.secondaryTagName,
                                ))
                            .toList(),
                        excludeTagIds: [_tag!.id],
                        icon: SharedUiConstants.addIcon,
                      ),
                    ),
                  ),
                if (_tag!.isArchived)
                  DetailTableRowData(
                    label: _translationService.translate(TagTranslationKeys.detailsArchived),
                    icon: Icons.archive,
                    widget: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        _translationService.translate(TagTranslationKeys.detailsArchived),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
              ],
              isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
            ),
            const SizedBox(height: AppTheme.size2XSmall),
          ],

          // Only show chip section if we have available fields to add
          if (availableChipFields.isNotEmpty) ...[
            const SizedBox(height: AppTheme.size2XSmall),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: availableChipFields.map((field) => _buildOptionalFieldChip(field)).toList(),
            ),
          ],

          const SizedBox(height: AppTheme.sizeSmall),
        ],
      ),
    );
  }

  // Widget to build optional field chips
  Widget _buildOptionalFieldChip(String fieldKey) {
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
      selected: _visibleOptionalFields.contains(fieldKey),
      onSelected: (_) => _toggleOptionalField(fieldKey),
      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }

  // Get descriptive label for field chips
  String _getFieldLabel(String fieldKey) {
    switch (fieldKey) {
      case keyColor:
        return _translationService.translate(TagTranslationKeys.colorLabel);
      case keyRelatedTags:
        return _translationService.translate(TagTranslationKeys.detailsRelatedTags);
      case keyArchived:
        return _translationService.translate(TagTranslationKeys.detailsArchived);
      default:
        return '';
    }
  }

  // Get icon for field chips
  IconData _getFieldIcon(String fieldKey) {
    switch (fieldKey) {
      case keyColor:
        return TagUiConstants.colorIcon;
      case keyRelatedTags:
        return TagUiConstants.tagIcon;
      case keyArchived:
        return Icons.archive;
      default:
        return Icons.add;
    }
  }
}
