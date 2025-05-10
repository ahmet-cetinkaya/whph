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
  final String id;
  final VoidCallback? onAppUsageUpdated;
  final Function(String)? onNameUpdated;

  const AppUsageDetailsContent({
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

  final _mediator = container.resolve<Mediator>();
  final _appUsagesService = container.resolve<AppUsagesService>();
  final _translationService = container.resolve<ITranslationService>();

  final _nameController = TextEditingController();
  Timer? _debounce;

  // Set to track which optional fields are visible
  final Set<String> _visibleOptionalFields = {};

  // Define optional field keys
  static const String keyTags = 'tags';
  static const String keyColor = 'color';

  @override
  void initState() {
    _getAppUsage();
    _getAppUsageTags();
    _appUsagesService.onAppUsageUpdated.addListener(_handleAppUsageUpdate);
    super.initState();
  }

  @override
  void dispose() {
    _appUsagesService.onAppUsageUpdated.removeListener(_handleAppUsageUpdate);
    _nameController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _handleAppUsageUpdate() {
    if (!mounted || _appUsagesService.onAppUsageUpdated.value != widget.id) return;
    _getAppUsage();
    _getAppUsageTags(); // Also refresh tags when app usage is updated
  }

  Future<void> _getAppUsage() async {
    final query = GetAppUsageQuery(id: widget.id);
    try {
      final response = await _mediator.send<GetAppUsageQuery, GetAppUsageQueryResponse>(query);
      if (mounted) {
        // Store current selection before updating
        final nameSelection = _nameController.selection;

        setState(() {
          _appUsage = response;

          // Only update name if it's different
          if (_nameController.text != (response.displayName ?? response.name)) {
            // Check displayName instead of name
            _nameController.text = response.displayName ?? response.name;
            widget.onNameUpdated?.call(response.displayName ?? response.name);
            // Don't restore selection for name if it changed
          } else if (nameSelection.isValid) {
            // Restore selection if name didn't change
            _nameController.selection = nameSelection;
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

    // Increase debounce time to give user more time to type
    _debounce = Timer(const Duration(milliseconds: 1000), () async {
      // Only proceed if the widget is still mounted
      if (!mounted) return;

      final command = SaveAppUsageCommand(
        id: widget.id,
        name: _appUsage!.name,
        displayName: _nameController.text,
        color: _appUsage!.color,
        deviceName: _appUsage!.deviceName,
      );
      try {
        // Send the command and get the result
        await _mediator.send<SaveAppUsageCommand, SaveAppUsageCommandResponse>(command);

        // Notify that app usage was updated
        _appUsagesService.notifyAppUsageUpdated(widget.id);
        widget.onAppUsageUpdated?.call();
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
        final result = await _mediator.send<GetListAppUsageTagsQuery, GetListAppUsageTagsQueryResponse>(query);

        if (mounted) {
          setState(() {
            if (_appUsageTags == null) {
              _appUsageTags = result;
            } else {
              _appUsageTags!.items.addAll(result.items);
            }
          });

          // Process field visibility after tags are loaded to ensure tag fields show correctly
          _processFieldVisibility();
        }

        // Break out of the loop if we've fetched all tags or received an empty page
        if (result.items.isEmpty || result.items.length < pageSize) {
          break;
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

  void _onTagsSelected(List<DropdownOption<String>> tagOptions) {
    final tagOptionsToAdd = tagOptions
        .where(
            (tagOption) => !_appUsageTags!.items.any((appUsageAppUsage) => appUsageAppUsage.tagId == tagOption.value))
        .toList();
    final appUsageTagsToRemove = _appUsageTags!.items
        .where((appUsageTag) => !tagOptions.map((tag) => tag.value).toList().contains(appUsageTag.tagId))
        .toList();

    // Batch process all tag operations
    Future<void> processTags() async {
      // Add all tags
      for (final tagOption in tagOptionsToAdd) {
        await _addTagToAppUsage(tagOption.value);
      }

      // Remove all tags
      for (final appUsageTag in appUsageTagsToRemove) {
        await _removeTagFromAppUsage(appUsageTag.id);
      }

      // Notify only once after all tag operations are complete
      if (tagOptionsToAdd.isNotEmpty || appUsageTagsToRemove.isNotEmpty) {
        _appUsagesService.notifyAppUsageUpdated(widget.id);
      }
    }

    // Execute the tag operations
    processTags();
  }

  void _onChangeColor(Color color) {
    if (mounted) {
      setState(() {
        _appUsage!.color = color.toHexString();
      });
    }

    // Save the app usage with the new color
    _saveAppUsage();

    // Notify that app usage has been updated with the color change
    _appUsagesService.notifyAppUsageUpdated(widget.id);
  }

  void _onChangeColorOpen() {
    showModalBottomSheet(
        context: context,
        builder: (context) => color_picker.ColorPicker(
            pickerColor: Color(int.parse("FF${_appUsage!.color!}", radix: 16)), onChangeColor: _onChangeColor));
  }

  // Process field content and update UI after app usage data is loaded
  void _processFieldVisibility() {
    if (_appUsage == null) return;

    setState(() {
      // Make fields with content automatically visible
      if (_hasFieldContent(keyTags)) _visibleOptionalFields.add(keyTags);
      if (_hasFieldContent(keyColor)) _visibleOptionalFields.add(keyColor);
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
    if (_appUsage == null) return false;

    switch (fieldKey) {
      case keyTags:
        return _appUsageTags != null && _appUsageTags!.items.isNotEmpty;
      case keyColor:
        return _appUsage!.color != null && _appUsage!.color != 'FFFFFF';
      default:
        return false;
    }
  }

  // Get descriptive label for field chips
  String _getFieldLabel(String fieldKey) {
    switch (fieldKey) {
      case keyTags:
        return _translationService.translate(AppUsageTranslationKeys.tagsLabel);
      case keyColor:
        return _translationService.translate(AppUsageTranslationKeys.colorLabel);
      default:
        return '';
    }
  }

  // Get icon for field chips
  IconData _getFieldIcon(String fieldKey) {
    switch (fieldKey) {
      case keyTags:
        return AppUsageUiConstants.tagsIcon;
      case keyColor:
        return AppUsageUiConstants.colorIcon;
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

  // Add the method to handle adding a tag to an app usage
  Future<bool> _addTagToAppUsage(String tagId) async {
    try {
      final command = AddAppUsageTagCommand(appUsageId: widget.id, tagId: tagId);
      await _mediator.send(command);
      await _getAppUsageTags();
      return true;
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(AppUsageTranslationKeys.addTagError),
        );
      }
      return false;
    }
  }

  // Add the method to handle removing a tag from an app usage
  Future<bool> _removeTagFromAppUsage(String id) async {
    try {
      final command = RemoveAppUsageTagCommand(id: id);
      await _mediator.send(command);
      await _getAppUsageTags();
      return true;
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(AppUsageTranslationKeys.removeTagError),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_appUsage == null || _appUsageTags == null) {
      return const SizedBox.shrink();
    }

    // Don't show fields with content in the chips section
    final List<String> availableChipFields = [
      keyTags,
      keyColor,
    ].where((field) => _shouldShowAsChip(field)).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Usage Name
          TextFormField(
            controller: _nameController,
            maxLines: null,
            onChanged: (value) {
              // Simply trigger the update and notify listeners
              _saveAppUsage();
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
          const SizedBox(height: AppTheme.sizeSmall),

          // Details Table
          DetailTable(rowData: [
            // Device Label - Always visible as mandatory field
            DetailTableRowData(
              label: _translationService.translate(AppUsageTranslationKeys.deviceLabel),
              icon: AppUsageUiConstants.deviceIcon,
              widget: Text(
                  _appUsage!.deviceName ?? _translationService.translate(AppUsageTranslationKeys.unknownDeviceLabel)),
            ),

            // Tags - Optional field
            if (_isFieldVisible(keyTags))
              DetailTableRowData(
                label: _translationService.translate(AppUsageTranslationKeys.tagsLabel),
                icon: AppUsageUiConstants.tagsIcon,
                hintText: _translationService.translate(AppUsageTranslationKeys.tagsHint),
                widget: TagSelectDropdown(
                  key: ValueKey(_appUsageTags!.items.length),
                  isMultiSelect: true,
                  onTagsSelected: (tagOptions, _) => _onTagsSelected(tagOptions),
                  showSelectedInDropdown: true,
                  initialSelectedTags: _appUsageTags!.items
                      .map((appUsage) => DropdownOption<String>(value: appUsage.tagId, label: appUsage.tagName))
                      .toList(),
                  icon: SharedUiConstants.addIcon,
                ),
              ),

            // Color - Optional field
            if (_isFieldVisible(keyColor))
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

          // Optional field chips at the bottom
          if (availableChipFields.isNotEmpty) ...[
            const SizedBox(height: AppTheme.sizeSmall),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableChipFields.map((fieldKey) => _buildOptionalFieldChip(fieldKey, false)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
