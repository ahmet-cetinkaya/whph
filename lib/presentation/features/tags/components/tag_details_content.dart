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

  Future<void> _getInitialData() async {
    await Future.wait([_getTag(), _getTagTags()]);
  }

  Future<void> _getTag() async {
    try {
      final query = GetTagQuery(id: widget.tagId);
      final response = await widget._mediator.send<GetTagQuery, GetTagQueryResponse>(query);
      if (mounted) {
        setState(() {
          _tag = response;
          if (_nameController.text != response.name) {
            _nameController.text = response.name;
            widget.onNameUpdated?.call(response.name);
          }
        });
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
    final currentSelection = _nameController.selection;

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final command = SaveTagCommand(
        id: widget.tagId,
        name: _nameController.text,
        color: _tag!.color,
        isArchived: _tag!.isArchived,
      );
      try {
        await widget._mediator.send(command);
        widget.onTagUpdated?.call();

        // Restore cursor position after save
        if (mounted) {
          _nameController.selection = currentSelection;
        }
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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag Name
          TextFormField(
            controller: _nameController,
            maxLines: null,
            onChanged: (value) async {
              await _saveTag();
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
          const SizedBox(height: AppTheme.sizeMedium),

          // Tag Details
          DetailTable(rowData: [
            // Color
            DetailTableRowData(
              label: _translationService.translate(TagTranslationKeys.colorLabel),
              icon: TagUiConstants.colorIcon,
              hintText: _translationService.translate(TagTranslationKeys.colorTooltip),
              widget: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ColorPreview(color: Color(int.parse("FF${_tag!.color ?? 'FFFFFF'}", radix: 16))),
                  IconButton(
                    onPressed: _onChangeColorOpen,
                    icon: Icon(TagUiConstants.editIcon, size: AppTheme.iconSizeSmall),
                  )
                ],
              ),
            ),

            // Tags
            DetailTableRowData(
              label: _translationService.translate(TagTranslationKeys.tagsLabel),
              icon: TagUiConstants.tagIcon,
              hintText: _translationService.translate(TagTranslationKeys.selectTooltip),
              widget: TagSelectDropdown(
                key: ValueKey(_tagTags!.items.length),
                isMultiSelect: true,
                onTagsSelected: _onTagsSelected,
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
          ]),
        ],
      ),
    );
  }
}
