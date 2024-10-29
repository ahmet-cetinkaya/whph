import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/commands/add_app_usage_tag_command.dart';
import 'package:whph/application/features/app_usages/commands/remove_tag_tag_command.dart';
import 'package:whph/application/features/app_usages/commands/save_app_usage_command.dart';
import 'package:whph/application/features/app_usages/queries/get_app_usage_query.dart';
import 'package:whph/application/features/app_usages/queries/get_list_app_usage_tags_query.dart';
import 'package:whph/domain/features/tags/tag.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/components/color_picker.dart';
import 'package:whph/presentation/features/shared/components/color_preview.dart';
import 'package:whph/presentation/features/shared/components/detail_table.dart';
import 'package:whph/presentation/features/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';

class AppUsageDetailsContent extends StatefulWidget {
  final String id;

  const AppUsageDetailsContent({
    super.key,
    required this.id,
  });

  @override
  State<AppUsageDetailsContent> createState() => _AppUsageDetailsContentState();
}

class _AppUsageDetailsContentState extends State<AppUsageDetailsContent> {
  final Mediator _mediator = container.resolve<Mediator>();

  GetAppUsageQueryResponse? _appUsage;
  GetListAppUsageTagsQueryResponse? _appUsageTags;

  @override
  void initState() {
    _getInitialData();

    super.initState();
  }

  Future<void> _getInitialData() async {
    await Future.wait([_getAppUsage(), _getAppUsageAppUsages()]);
  }

  Future<void> _getAppUsage() async {
    var query = GetAppUsageQuery(id: widget.id);
    try {
      var response = await _mediator.send<GetAppUsageQuery, GetAppUsageQueryResponse>(query);
      setState(() {
        _appUsage = response;
      });
    } catch (e) {
      if (context.mounted) {
        ErrorHelper.showError(context, e);
      }
    }
  }

  Future<void> _saveAppUsage() async {
    var command = SaveAppUsageCommand(
      id: widget.id,
      displayName: _appUsage!.displayName,
      name: _appUsage!.name,
      color: _appUsage!.color,
    );
    try {
      await _mediator.send<SaveAppUsageCommand, SaveAppUsageCommandResponse>(command);
    } catch (e) {
      if (context.mounted) {
        ErrorHelper.showError(context, e);
      }
    }
  }

  Future<void> _getAppUsageAppUsages() async {
    var query = GetListAppUsageTagsQuery(appUsageId: widget.id, pageIndex: 0, pageSize: 999);
    try {
      var result = await _mediator.send<GetListAppUsageTagsQuery, GetListAppUsageTagsQueryResponse>(query);
      setState(() {
        _appUsageTags = result;
      });
    } catch (e) {
      if (context.mounted) {
        ErrorHelper.showError(context, e);
      }
    }
  }

  Future<void> _addTag(String appUsageId) async {
    var command = AddAppUsageTagCommand(appUsageId: widget.id, tagId: appUsageId);
    try {
      await _mediator.send(command);
    } catch (e) {
      if (context.mounted) {
        ErrorHelper.showError(context, e);
      }
    }

    await _getAppUsageAppUsages();
  }

  Future<void> _removeTag(String id) async {
    var command = RemoveAppUsageTagCommand(id: id);
    try {
      await _mediator.send(command);
    } catch (e) {
      if (context.mounted) {
        ErrorHelper.showError(context, e);
      }
    }

    await _getAppUsageAppUsages();
  }

  void _onTagsSelected(List<String> tagIds) {
    var tagIdsToAdd = tagIds
        .where((tagId) => !_appUsageTags!.items.any((appUsageAppUsage) => appUsageAppUsage.tagId == tagId))
        .toList();
    var tagIdsToRemove = _appUsageTags!.items.where((appUsageTag) => !tagIds.contains(appUsageTag.tagId)).toList();

    for (var appUsageId in tagIdsToAdd) {
      _addTag(appUsageId);
    }
    for (var appUsageAppUsage in tagIdsToRemove) {
      _removeTag(appUsageAppUsage.id);
    }
  }

  void _onChangeColor(Color color) {
    setState(() {
      _appUsage!.color = color.value.toRadixString(16).substring(2);
    });
    _saveAppUsage();
  }

  void _onChangeColorOpen() {
    showModalBottomSheet(
        context: context,
        builder: (context) => ColorPicker(
            pickerColor: Color(int.parse("FF${_appUsage!.color!}", radix: 16)), onChangeColor: _onChangeColor));
  }

  @override
  Widget build(BuildContext context) {
    if (_appUsage == null || _appUsageTags == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return DetailTable(rowData: [
      // AppUsage Tags
      DetailTableRowData(
          label: "Tags",
          icon: Icons.label,
          widget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: [
                  // Select
                  TagSelectDropdown(
                    key: ValueKey(_appUsageTags!.items.length),
                    isMultiSelect: true,
                    onTagsSelected: _onTagsSelected,
                    initialSelectedTags: _appUsageTags!.items
                        .map((appUsage) => Tag(id: appUsage.tagId, name: appUsage.tagName, createdDate: DateTime.now()))
                        .toList(),
                    icon: Icons.add,
                  ),

                  // List
                  ..._appUsageTags!.items.map((tag) {
                    return Chip(
                      label: Text(tag.tagName),
                      onDeleted: () {
                        _removeTag(tag.id);
                      },
                    );
                  })
                ],
              ),
            ],
          )),

      // Color
      DetailTableRowData(
          label: "Color",
          icon: Icons.color_lens,
          widget: Row(
            children: [
              ColorPreview(color: Color(int.parse("FF${_appUsage!.color!}", radix: 16))),
              IconButton(onPressed: _onChangeColorOpen, icon: Icon(Icons.edit))
              // ColorPicker(
              //   key: ValueKey(_appUsage!.color),
              //   pickerColor: Color(int.parse(_appUsage!.color!, radix: 16)),
              //   changeColor: _onChangeColor,
              // ),
            ],
          )),
    ]);
  }
}