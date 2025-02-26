import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/commands/add_app_usage_tag_command.dart';
import 'package:whph/application/features/app_usages/commands/remove_tag_tag_command.dart';
import 'package:whph/application/features/app_usages/commands/save_app_usage_command.dart';
import 'package:whph/application/features/app_usages/queries/get_app_usage_query.dart';
import 'package:whph/application/features/app_usages/queries/get_list_app_usage_tags_query.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/app_usages/services/app_usages_service.dart';
import 'package:whph/presentation/shared/components/color_picker.dart' as color_picker;
import 'package:whph/presentation/shared/components/color_preview.dart';
import 'package:whph/presentation/shared/components/detail_table.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_ui_constants.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

class AppUsageDetailsContent extends StatefulWidget {
  final Mediator _mediator = container.resolve<Mediator>();
  final AppUsagesService _appUsagesService = container.resolve<AppUsagesService>();

  final String id;
  final VoidCallback? onAppUsageUpdated;
  final Function(String)? onNameUpdated;

  AppUsageDetailsContent({
    super.key,
    required this.id,
    this.onAppUsageUpdated,
    this.onNameUpdated,
  });

  @override
  State<AppUsageDetailsContent> createState() => _AppUsageDetailsContentState();
}

class _AppUsageDetailsContentState extends State<AppUsageDetailsContent> {
  GetAppUsageQueryResponse? _appUsage;
  GetListAppUsageTagsQueryResponse? _appUsageTags;
  final _translationService = container.resolve<ITranslationService>();
  final _nameController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    _getInitialData();
    widget._appUsagesService.onAppUsageSaved.addListener(_getAppUsage);
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _debounce?.cancel();
    widget._appUsagesService.onAppUsageSaved.removeListener(_getAppUsage);
    super.dispose();
  }

  Future<void> _getInitialData() async {
    await Future.wait([_getAppUsage(), _getAppUsageTags()]);
  }

  Future<void> _getAppUsage() async {
    final query = GetAppUsageQuery(id: widget.id);
    try {
      final response = await widget._mediator.send<GetAppUsageQuery, GetAppUsageQueryResponse>(query);
      if (mounted) {
        setState(() {
          _appUsage = response;
          if (_nameController.text != response.displayName) {
            // Check displayName instead of name
            _nameController.text = response.displayName ?? response.name;
            widget.onNameUpdated?.call(response.displayName ?? response.name);
          }
        });
      }
    } on BusinessException catch (e) {
      if (mounted) ErrorHelper.showError(context, e);
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(AppUsageTranslationKeys.getUsageError),
        );
      }
    }
  }

  Future<void> _saveAppUsage() async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final currentSelection = _nameController.selection;

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final command = SaveAppUsageCommand(
        id: widget.id,
        name: _appUsage!.name,
        displayName: _nameController.text,
        color: _appUsage!.color,
        deviceName: _appUsage!.deviceName,
      );
      try {
        final result = await widget._mediator.send<SaveAppUsageCommand, SaveAppUsageCommandResponse>(command);

        widget._appUsagesService.onAppUsageSaved.value = result;
        widget.onAppUsageUpdated?.call();

        if (mounted) {
          _nameController.selection = currentSelection;
        }
      } on BusinessException catch (e) {
        if (mounted) ErrorHelper.showError(context, e);
      } catch (e, stackTrace) {
        if (mounted) {
          ErrorHelper.showUnexpectedError(
            context,
            e as Exception,
            stackTrace,
            message: _translationService.translate(AppUsageTranslationKeys.saveUsageError),
          );
        }
      }
    });
  }

  Future<void> _getAppUsageTags() async {
    int pageIndex = 0;
    const int pageSize = 50;

    while (true) {
      final query = GetListAppUsageTagsQuery(appUsageId: widget.id, pageIndex: pageIndex, pageSize: pageSize);
      try {
        final result = await widget._mediator.send<GetListAppUsageTagsQuery, GetListAppUsageTagsQueryResponse>(query);

        if (mounted) {
          setState(() {
            if (_appUsageTags == null) {
              _appUsageTags = result;
            } else {
              _appUsageTags!.items.addAll(result.items);
            }
          });
        }
        pageIndex++;
      } on BusinessException catch (e) {
        if (mounted) {
          ErrorHelper.showError(context, e);
          break;
        }
      } catch (e, stackTrace) {
        if (mounted) {
          ErrorHelper.showUnexpectedError(
            context,
            e as Exception,
            stackTrace,
            message: _translationService.translate(AppUsageTranslationKeys.getTagsError),
          );
          break;
        }
      }
    }
  }

  Future<void> _addTag(String appUsageId) async {
    final command = AddAppUsageTagCommand(appUsageId: widget.id, tagId: appUsageId);
    try {
      await widget._mediator.send(command);
    } on BusinessException catch (e) {
      if (mounted) ErrorHelper.showError(context, e);
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(AppUsageTranslationKeys.addTagError),
        );
      }
    }

    await _getAppUsageTags();
  }

  Future<void> _removeTag(String id) async {
    final command = RemoveAppUsageTagCommand(id: id);
    try {
      await widget._mediator.send(command);
    } on BusinessException catch (e) {
      if (mounted) ErrorHelper.showError(context, e);
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(AppUsageTranslationKeys.removeTagError),
        );
      }
    }

    await _getAppUsageTags();
  }

  void _onTagsSelected(List<DropdownOption<String>> tagOptions) {
    final tagOptionsToAdd = tagOptions
        .where(
            (tagOption) => !_appUsageTags!.items.any((appUsageAppUsage) => appUsageAppUsage.tagId == tagOption.value))
        .toList();
    final appUsageTagsToRemove = _appUsageTags!.items
        .where((appUsageTag) => !tagOptions.map((tag) => tag.value).toList().contains(appUsageTag.tagId))
        .toList();

    for (final tagOption in tagOptionsToAdd) {
      _addTag(tagOption.value);
    }
    for (final appUsageAppUsage in appUsageTagsToRemove) {
      _removeTag(appUsageAppUsage.id);
    }
  }

  void _onChangeColor(Color color) {
    if (mounted) {
      setState(() {
        _appUsage!.color = color.toHexString();
      });
    }
    _saveAppUsage();
  }

  void _onChangeColorOpen() {
    showModalBottomSheet(
        context: context,
        builder: (context) => color_picker.ColorPicker(
            pickerColor: Color(int.parse("FF${_appUsage!.color!}", radix: 16)), onChangeColor: _onChangeColor));
  }

  @override
  Widget build(BuildContext context) {
    if (_appUsage == null || _appUsageTags == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      padding: AppUsageUiConstants.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameController,
            maxLines: null,
            onChanged: (value) async {
              await _saveAppUsage();
              widget.onNameUpdated?.call(value);
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffixIcon: Tooltip(
                message: _translationService.translate(AppUsageTranslationKeys.editNameTooltip),
                child: Icon(Icons.edit, size: AppTheme.iconSizeSmall),
              ),
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppTheme.sizeMedium),
          DetailTable(rowData: [
            // Device Label
            DetailTableRowData(
              label: _translationService.translate(AppUsageTranslationKeys.deviceLabel),
              icon: AppUsageUiConstants.deviceIcon,
              widget: Text(
                  _appUsage!.deviceName ?? _translationService.translate(AppUsageTranslationKeys.unknownDeviceLabel)),
            ),

            // Tags
            DetailTableRowData(
              label: _translationService.translate(AppUsageTranslationKeys.tagsLabel),
              icon: AppUsageUiConstants.tagsIcon,
              hintText: _translationService.translate(AppUsageTranslationKeys.tagsHint),
              widget: TagSelectDropdown(
                key: ValueKey(_appUsageTags!.items.length),
                isMultiSelect: true,
                onTagsSelected: _onTagsSelected,
                showSelectedInDropdown: true,
                initialSelectedTags: _appUsageTags!.items
                    .map((appUsage) => DropdownOption<String>(value: appUsage.tagId, label: appUsage.tagName))
                    .toList(),
                icon: SharedUiConstants.addIcon,
              ),
            ),

            // Color
            DetailTableRowData(
              label: _translationService.translate(AppUsageTranslationKeys.colorLabel),
              icon: AppUsageUiConstants.colorIcon,
              hintText: _translationService.translate(AppUsageTranslationKeys.colorHint),
              widget: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ColorPreview(color: AppUsageUiConstants.getTagColor(_appUsage!.color)),
                  IconButton(
                    onPressed: _onChangeColorOpen,
                    icon: Icon(AppUsageUiConstants.editIcon, size: AppTheme.iconSizeSmall),
                  )
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
