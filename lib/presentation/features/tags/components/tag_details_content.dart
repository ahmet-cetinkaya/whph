import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/commands/add_tag_tag_command.dart';
import 'package:whph/application/features/tags/commands/remove_tag_tag_command.dart';
import 'package:whph/application/features/tags/queries/get_list_tag_tags_query.dart';
import 'package:whph/application/features/tags/queries/get_tag_query.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/tags/tag.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/components/detail_table.dart';
import 'package:whph/presentation/features/shared/models/dropdown_option.dart';
import 'package:whph/presentation/features/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';

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
            message: "Unexpected error occurred while getting tag.");
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

  @override
  Widget build(BuildContext context) {
    if (_tag == null || _tagTags == null) {
      return const SizedBox.shrink();
    }

    return DetailTable(rowData: [
      DetailTableRowData(
        label: "Tags",
        icon: Icons.tag,
        widget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: [
                TagSelectDropdown(
                  key: ValueKey(_tagTags!.items.length),
                  isMultiSelect: true,
                  onTagsSelected: _onTagsSelected,
                  initialSelectedTags: _tagTags!.items
                      .map(
                          (tag) => Tag(id: tag.secondaryTagId, name: tag.secondaryTagName, createdDate: DateTime.now()))
                      .toList(),
                  icon: Icons.add,
                  excludeTagIds: [_tag!.id],
                ),
                ..._tagTags!.items.map((tagTag) {
                  return Chip(
                    label: Text(
                      tagTag.secondaryTagName,
                      style: TextStyle(
                        color: tagTag.secondaryTagColor != null
                            ? Color(int.parse('FF${tagTag.secondaryTagColor}', radix: 16))
                            : null,
                      ),
                    ),
                    onDeleted: () {
                      _removeTag(tagTag.id);
                    },
                  );
                })
              ],
            ),
          ],
        ),
      ),
    ]);
  }
}
