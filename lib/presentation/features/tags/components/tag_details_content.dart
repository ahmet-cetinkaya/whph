import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/commands/add_tag_tag_command.dart';
import 'package:whph/application/features/tags/commands/remove_tag_tag_command.dart';
import 'package:whph/application/features/tags/commands/save_tag_command.dart';
import 'package:whph/application/features/tags/queries/get_list_tag_tags_query.dart';
import 'package:whph/application/features/tags/queries/get_tag_query.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/shared/components/detail_table.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/shared/components/color_picker.dart' as color_picker;
import 'package:whph/presentation/shared/components/color_preview.dart';

class TagDetailsContent extends StatefulWidget {
  final Mediator _mediator = container.resolve<Mediator>();

  final String tagId;
  final VoidCallback? onTagUpdated;
  final Function(String)? onNameUpdated;

  TagDetailsContent({
    super.key,
    required this.tagId,
    this.onTagUpdated,
    this.onNameUpdated,
  });

  @override
  State<TagDetailsContent> createState() => _TagDetailsContentState();
}

class _TagDetailsContentState extends State<TagDetailsContent> {
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
    return !_visibleOptionalFields.contains(fieldKey);
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
    try {
      final query = GetTagQuery(id: widget.tagId);
      final response = await widget._mediator.send<GetTagQuery, GetTagQueryResponse>(query);
      if (mounted) {
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
      }
    } on BusinessException catch (e) {
      if (mounted) ErrorHelper.showError(context, e);
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: _translationService.translate(TagTranslationKeys.errorLoading));
      }
    }
  }

  Future<void> _getTagTags() async {
    int pageIndex = 0;
    const int pageSize = 50;

    while (true) {
      final query = GetListTagTagsQuery(primaryTagId: widget.tagId, pageIndex: pageIndex, pageSize: pageSize);
      try {
        final response = await widget._mediator.send<GetListTagTagsQuery, GetListTagTagsQueryResponse>(query);

        if (mounted) {
          setState(() {
            if (_tagTags == null) {
              _tagTags = response;
            } else {
              _tagTags!.items.addAll(response.items);
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
            message: _translationService.translate(TagTranslationKeys.errorLoading),
          );
          break;
        }
      }
    }
  }

  Future<void> _addTag(String tagId) async {
    final command = AddTagTagCommand(primaryTagId: _tag!.id, secondaryTagId: tagId);
    await widget._mediator.send(command);
    await _getTagTags();
  }

  Future<void> _removeTag(String id) async {
    final command = RemoveTagTagCommand(id: id);
    await widget._mediator.send(command);
    await _getTagTags();
  }

  void _onTagsSelected(List<DropdownOption<String>> tagOptions) {
    final tagOptionsToAdd = tagOptions
        .where((tagOption) => !_tagTags!.items.any((tagTag) => tagTag.secondaryTagId == tagOption.value))
        .toList();
    final tagTagsToRemove =
        _tagTags!.items.where((tagTag) => !tagOptions.map((tag) => tag.value).contains(tagTag.secondaryTagId)).toList();

    for (final tagOption in tagOptionsToAdd) {
      _addTag(tagOption.value);
    }
    for (final tagTag in tagTagsToRemove) {
      _removeTag(tagTag.id);
    }
  }

  Future<void> _saveTag() async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Increase debounce time to give user more time to type
    _debounce = Timer(const Duration(milliseconds: 1000), () async {
      // Only proceed if the widget is still mounted
      if (!mounted) return;

      final command = SaveTagCommand(
        id: widget.tagId,
        name: _nameController.text,
        color: _tag!.color,
        isArchived: _tag!.isArchived,
      );
      try {
        // Send the command but don't update UI with the result
        await widget._mediator.send(command);
        widget.onTagUpdated?.call();

        // Don't update any text fields or selections - let them remain as they are
      } on BusinessException catch (e) {
        if (mounted) ErrorHelper.showError(context, e);
      } catch (e, stackTrace) {
        if (mounted) {
          ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
              message: _translationService.translate(TagTranslationKeys.errorSaving));
        }
      }
    });
  }

  void _onChangeColor(Color color) {
    if (mounted) {
      setState(() {
        _tag!.color = color.toHexString();
      });
    }
    _saveTag();
  }

  void _onChangeColorOpen() {
    showModalBottomSheet(
        context: context,
        builder: (context) => color_picker.ColorPicker(
            pickerColor: Color(int.parse("FF${_tag!.color ?? 'FFFFFF'}", radix: 16)), onChangeColor: _onChangeColor));
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
            onChanged: (value) {
              _saveTag();
              widget.onNameUpdated?.call(value);
            },
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
            const SizedBox(height: AppTheme.sizeSmall),
            DetailTable(
              rowData: [
                if (_visibleOptionalFields.contains(keyColor))
                  DetailTableRowData(
                    label: _translationService.translate(TagTranslationKeys.colorLabel),
                    icon: TagUiConstants.colorIcon,
                    widget: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ColorPreview(color: Color(int.parse("FF${_tag!.color ?? 'FFFFFF'}", radix: 16))),
                          IconButton(
                            onPressed: _onChangeColorOpen,
                            icon: Icon(TagUiConstants.editIcon, size: AppTheme.iconSizeSmall),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          )
                        ],
                      ),
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
            ),
          ],

          // Only show chip section if we have available fields to add
          if (availableChipFields.isNotEmpty) ...[
            const SizedBox(height: AppTheme.sizeSmall),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
