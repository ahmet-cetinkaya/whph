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
import 'package:whph/presentation/shared/components/detail_table.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/components/color_picker.dart' as color_picker;
import 'package:whph/presentation/shared/components/color_preview.dart';

class TagDetailsContent extends StatefulWidget {
  final Mediator _mediator = container.resolve<Mediator>();

  final String tagId;

  TagDetailsContent({
    super.key,
    required this.tagId,
  });

  @override
  State<TagDetailsContent> createState() => _TagDetailsContentState();
}

class _TagDetailsContentState extends State<TagDetailsContent> {
  GetTagQueryResponse? _tag;
  GetListTagTagsQueryResponse? _tagTags;

  @override
  void initState() {
    super.initState();
    _getInitialData();
  }

  Future<void> _getInitialData() async {
    await Future.wait([_getTag(), _getTagTags()]);
  }

  Future<void> _getTag() async {
    try {
      var query = GetTagQuery(id: widget.tagId);
      var response = await widget._mediator.send<GetTagQuery, GetTagQueryResponse>(query);
      if (mounted) {
        setState(() {
          _tag = response;
        });
      }
    } on BusinessException catch (e) {
      if (mounted) ErrorHelper.showError(context, e);
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: TagUiConstants.errorLoadingTagName);
      }
    }
  }

  Future<void> _getTagTags() async {
    try {
      var query = GetListTagTagsQuery(primaryTagId: widget.tagId, pageIndex: 0, pageSize: 100);
      var response = await widget._mediator.send<GetListTagTagsQuery, GetListTagTagsQueryResponse>(query);
      if (mounted) {
        setState(() {
          _tagTags = response;
        });
      }
    } on BusinessException catch (e) {
      if (mounted) ErrorHelper.showError(context, e);
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: "Unexpected error occurred while getting tag tags.");
      }
    }
  }

  Future<void> _addTag(String tagId) async {
    var command = AddTagTagCommand(primaryTagId: _tag!.id, secondaryTagId: tagId);
    await widget._mediator.send(command);
    await _getTagTags();
  }

  Future<void> _removeTag(String id) async {
    var command = RemoveTagTagCommand(id: id);
    await widget._mediator.send(command);
    await _getTagTags();
  }

  void _onTagsSelected(List<DropdownOption<String>> tagOptions) {
    var tagOptionsToAdd = tagOptions
        .where((tagOption) => !_tagTags!.items.any((tagTag) => tagTag.secondaryTagId == tagOption.value))
        .toList();
    var tagTagsToRemove =
        _tagTags!.items.where((tagTag) => !tagOptions.map((tag) => tag.value).contains(tagTag.secondaryTagId)).toList();

    for (var tagOption in tagOptionsToAdd) {
      _addTag(tagOption.value);
    }
    for (var tagTag in tagTagsToRemove) {
      _removeTag(tagTag.id);
    }
  }

  Future<void> _saveTag() async {
    var command = SaveTagCommand(
      id: widget.tagId,
      name: _tag!.name,
      color: _tag!.color,
    );
    try {
      await widget._mediator.send(command);
      await _getTag();
    } on BusinessException catch (e) {
      if (mounted) ErrorHelper.showError(context, e);
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: "Unexpected error occurred while saving tag.");
      }
    }
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
          DetailTable(rowData: [
            DetailTableRowData(
              label: TagUiConstants.colorLabel,
              icon: TagUiConstants.colorIcon,
              hintText: TagUiConstants.clickToChangeColorHint,
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
            DetailTableRowData(
              label: TagUiConstants.tagsLabel,
              icon: TagUiConstants.tagIcon,
              hintText: TagUiConstants.selectTagsHint,
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
