import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/commands/add_app_usage_tag_command.dart';
import 'package:whph/core/application/features/app_usages/commands/remove_tag_tag_command.dart';
import 'package:whph/core/application/features/app_usages/commands/update_app_usage_tags_order_command.dart';
import 'package:whph/core/application/features/app_usages/commands/save_app_usage_command.dart';
import 'package:whph/core/application/features/app_usages/queries/get_app_usage_query.dart';
import 'package:whph/core/application/features/app_usages/queries/get_list_app_usage_tags_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/app_usages/services/app_usages_service.dart';
import 'package:whph/presentation/ui/shared/components/color_picker/color_field.dart';
import 'package:whph/presentation/ui/shared/components/detail_table.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:acore/acore.dart' hide Container;
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/ui/features/app_usages/constants/app_usage_ui_constants.dart';
import 'package:whph/presentation/ui/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

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
  final FocusNode _nameFocusNode = FocusNode();
  Timer? _debounce;

  // Track active input fields to prevent text selection conflicts
  bool _isNameFieldActive = false;

  // Set to track which optional fields are visible
  final Set<String> _visibleOptionalFields = {};

  // Define optional field keys
  static const String keyTags = 'tags';
  static const String keyColor = 'color';

  @override
  void initState() {
    // Track focus state to prevent text selection conflicts
    _nameFocusNode.addListener(_handleNameFocusChange);

    _getAppUsage();
    _getAppUsageTags(clearExisting: true);
    _appUsagesService.onAppUsageUpdated.addListener(_handleAppUsageUpdate);
    super.initState();
  }

  @override
  void dispose() {
    _appUsagesService.onAppUsageUpdated.removeListener(_handleAppUsageUpdate);
    _nameFocusNode.removeListener(_handleNameFocusChange);

    // Notify parent about name changes before disposing
    if (widget.onNameUpdated != null && _nameController.text.isNotEmpty) {
      widget.onNameUpdated!(_nameController.text);
    }

    _nameController.dispose();
    _nameFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _handleAppUsageUpdate() {
    if (!mounted || _appUsagesService.onAppUsageUpdated.value != widget.id) return;

    // Skip refresh if name field is actively being edited to prevent input conflicts
    if (_isNameFieldActive) return;

    _getAppUsage();
    _getAppUsageTags(clearExisting: true); // Also refresh tags when app usage is updated
  }

  void _handleNameFocusChange() {
    if (!mounted) return;
    setState(() {
      _isNameFieldActive = _nameFocusNode.hasFocus;
    });
  }

  Future<void> _getAppUsage() async {
    final query = GetAppUsageQuery(id: widget.id);

    await AsyncErrorHandler.execute<GetAppUsageQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(AppUsageTranslationKeys.getUsageError),
      operation: () async {
        return await _mediator.send<GetAppUsageQuery, GetAppUsageQueryResponse>(query);
      },
      onSuccess: (response) {
        if (!mounted) return;

        setState(() {
          _appUsage = response;

          // Only update name if it's different
          if (_nameController.text != (response.displayName ?? response.name)) {
            _nameController.text = response.displayName ?? response.name;
            widget.onNameUpdated?.call(response.displayName ?? response.name);
          }
        });
      },
    );
  }

  // Helper methods for repeated patterns
  void _forceImmediateUpdate() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
  }

  SaveAppUsageCommand _buildSaveCommand() {
    return SaveAppUsageCommand(
      id: widget.id,
      name: _appUsage!.name,
      displayName: _nameController.text,
      color: _appUsage!.color,
      deviceName: _appUsage!.deviceName,
    );
  }

  Future<void> _executeSaveCommand() async {
    await _mediator.send<SaveAppUsageCommand, SaveAppUsageCommandResponse>(_buildSaveCommand());
  }

  void _handleFieldChange<T>(T value, VoidCallback? onUpdate) {
    _forceImmediateUpdate();
    _saveAppUsage();
    onUpdate?.call();
  }

  // Event handler methods
  void _onNameChanged(String value) {
    // Update active state to prevent data refresh conflicts during typing
    _isNameFieldActive = true;
    _handleFieldChange(value, () => widget.onNameUpdated?.call(value));
  }

  Future<void> _saveAppUsage() async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(SharedUiConstants.contentSaveDebounceTime, () async {
      if (!mounted) return;

      await AsyncErrorHandler.executeVoid(
        context: context,
        errorMessage: _translationService.translate(AppUsageTranslationKeys.saveUsageError),
        operation: _executeSaveCommand,
        onSuccess: () {
          _appUsagesService.notifyAppUsageUpdated(widget.id);
          widget.onAppUsageUpdated?.call();
        },
      );
    });
  }

  Future<void> _getAppUsageTags({bool clearExisting = false}) async {
    int pageIndex = 0;
    const int pageSize = 50;

    if (clearExisting) {
      setState(() {
        _appUsageTags = null;
      });
    }

    while (true) {
      final query = GetListAppUsageTagsQuery(appUsageId: widget.id, pageIndex: pageIndex, pageSize: pageSize);

      final result = await AsyncErrorHandler.execute<GetListAppUsageTagsQueryResponse>(
        context: context,
        errorMessage: _translationService.translate(AppUsageTranslationKeys.getTagsError),
        operation: () async {
          return await _mediator.send<GetListAppUsageTagsQuery, GetListAppUsageTagsQueryResponse>(query);
        },
        onSuccess: (result) {
          if (mounted) {
            setState(() {
              if (_appUsageTags == null || pageIndex == 0) {
                _appUsageTags = result;
              } else {
                _appUsageTags!.items.addAll(result.items);
              }
            });
            _processFieldVisibility();
          }
        },
      );

      if (result == null || result.items.isEmpty || result.items.length < pageSize) break;
      pageIndex++;
    }
  }

  void _onTagsSelected(List<DropdownOption<String>> tagOptions) {
    if (_appUsageTags == null) return;

    final tagOptionsToAdd = tagOptions
        .where((tagOption) => !_appUsageTags!.items.any((appUsageTag) => appUsageTag.tagId == tagOption.value))
        .toList();
    final appUsageTagsToRemove = _appUsageTags!.items
        .where((appUsageTag) => !tagOptions.map((tag) => tag.value).toList().contains(appUsageTag.tagId))
        .toList();

    // Process tag operations sequentially
    Future<void> processTags() async {
      bool hasChanges = false;

      try {
        // First remove tags to prevent conflicts
        for (final appUsageTag in appUsageTagsToRemove) {
          final success = await _removeTagFromAppUsage(appUsageTag.id);
          if (success) hasChanges = true;
        }

        // Then add new tags
        for (final tagOption in tagOptionsToAdd) {
          final success = await _addTagToAppUsage(tagOption.value);
          if (success) hasChanges = true;
        }

        // Update Order
        if (tagOptions.isNotEmpty) {
          final tagOrders = {for (int i = 0; i < tagOptions.length; i++) tagOptions[i].value: i};
          final orderCommand = UpdateAppUsageTagsOrderCommand(appUsageId: widget.id, tagOrders: tagOrders);
          await _mediator.send(orderCommand);
          hasChanges = true;
        }

        // Only notify once after all operations complete successfully
        if (hasChanges) {
          await _getAppUsageTags(clearExisting: true); // Refresh tags list
          _appUsagesService.notifyAppUsageUpdated(widget.id);
        }
      } catch (e) {
        // Silently refresh the tags list to ensure UI is in sync
        await _getAppUsageTags(clearExisting: true);
      }
    }

    // Execute the tag operations
    processTags();
  }

  void _onChangeColor(Color color) {
    if (mounted) {
      setState(() {
        // Remove the FF prefix from the hex string if it exists
        final hexString = color.toHexString();
        _appUsage!.color = hexString.startsWith('FF') ? hexString.substring(2) : hexString;
      });
    }

    // Save the app usage with the new color
    _saveAppUsage();
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
      final result = await _mediator.send(command);
      if (result != null) {
        return true;
      }
    } catch (_) {
      // Silently handle the error
    }
    return false;
  }

  // Add the method to handle removing a tag from an app usage
  Future<bool> _removeTagFromAppUsage(String id) async {
    try {
      final command = RemoveAppUsageTagCommand(id: id);
      final result = await _mediator.send(command);
      if (result != null) {
        return true;
      }
    } catch (_) {
      // Silently handle the error
    }
    return false;
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
            focusNode: _nameFocusNode,
            maxLines: null,
            onChanged: _onNameChanged,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppTheme.size2XSmall),

          // Details Table
          DetailTable(
            rowData: [
              // Device Label - Always visible as mandatory field
              DetailTableRowData(
                label: _translationService.translate(AppUsageTranslationKeys.deviceLabel),
                icon: AppUsageUiConstants.deviceIcon,
                widget: Padding(
                  padding: const EdgeInsets.only(left: AppTheme.sizeSmall),
                  child: Text(_appUsage!.deviceName ??
                      _translationService.translate(AppUsageTranslationKeys.unknownDeviceLabel)),
                ),
              ),

              // Tags - Optional field
              if (_isFieldVisible(keyTags))
                DetailTableRowData(
                  label: _translationService.translate(AppUsageTranslationKeys.tagsLabel),
                  icon: AppUsageUiConstants.tagsIcon,
                  widget: TagSelectDropdown(
                    key: ValueKey(_appUsageTags!.items.map((t) => '${t.tagId}_${t.tagOrder}').join(',')),
                    isMultiSelect: true,
                    onTagsSelected: (tagOptions, _) => _onTagsSelected(tagOptions),
                    showSelectedInDropdown: true,
                    initialSelectedTags: _appUsageTags!.items
                        .map((appUsage) => DropdownOption<String>(
                            value: appUsage.tagId,
                            label: appUsage.tagName.isNotEmpty
                                ? appUsage.tagName
                                : _translationService.translate(SharedTranslationKeys.untitled)))
                        .toList(),
                    icon: SharedUiConstants.addIcon,
                  ),
                ),

              // Color - Optional field
              if (_isFieldVisible(keyColor))
                DetailTableRowData(
                  label: _translationService.translate(AppUsageTranslationKeys.colorLabel),
                  icon: AppUsageUiConstants.colorIcon,
                  widget: ColorField(
                    initialColor: AppUsageUiConstants.getTagColor(_appUsage!.color),
                    onColorChanged: _onChangeColor,
                  ),
                ),
            ],
            isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
          ),

          // Optional field chips at the bottom
          if (availableChipFields.isNotEmpty) ...[
            const SizedBox(height: AppTheme.sizeSmall),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: availableChipFields.map((fieldKey) => _buildOptionalFieldChip(fieldKey, false)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
