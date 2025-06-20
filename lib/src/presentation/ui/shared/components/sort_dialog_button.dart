import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whph/corePackages/acore/repository/models/sort_direction.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/src/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/src/presentation/ui/shared/models/sort_option_with_translation_key.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/responsive_dialog_helper.dart';

class SortDialogButton<T> extends StatefulWidget {
  final Color? iconColor;
  final double iconSize;
  final bool isActive;
  final String tooltip;
  final List<SortOptionWithTranslationKey<T>> availableOptions;
  final SortConfig<T> config;
  final SortConfig<T> defaultConfig;
  final Function(SortConfig<T>) onConfigChanged;
  final double? dialogMaxHeightRatio;
  final double? dialogMaxWidthRatio;
  final bool showCustomOrderOption;
  final VoidCallback? onDialogClose;

  const SortDialogButton({
    super.key,
    required this.tooltip,
    required this.availableOptions,
    required this.config,
    required this.defaultConfig,
    required this.onConfigChanged,
    this.iconColor,
    this.iconSize = AppTheme.iconSizeMedium,
    this.isActive = false,
    this.dialogMaxHeightRatio = 0.4,
    this.dialogMaxWidthRatio = 0.6,
    this.showCustomOrderOption = false,
    this.onDialogClose,
  });

  @override
  State<SortDialogButton<T>> createState() => _SortDialogButtonState<T>();
}

class _SortDialogButtonState<T> extends State<SortDialogButton<T>> {
  late final _translationService = container.resolve<ITranslationService>();

  Future<void> _showOrderDialog(BuildContext context) async {
    await ResponsiveDialogHelper.showResponsiveDialog(
        context: context,
        child: _SortDialog<T>(
          availableOptions: widget.availableOptions,
          config: widget.config,
          defaultConfig: widget.defaultConfig,
          onConfigChanged: widget.onConfigChanged,
          showCustomOrderOption: widget.showCustomOrderOption,
          translationService: _translationService,
          onClose: widget.onDialogClose,
        ),
        size: DialogSize.medium);
  }

  @override
  Widget build(BuildContext context) {
    final Color effectiveColor = widget.iconColor ?? Theme.of(context).primaryColor;

    return IconButton(
      icon: Icon(
        Icons.sort,
        color: widget.isActive ? effectiveColor : Colors.grey,
      ),
      iconSize: widget.iconSize,
      tooltip: widget.tooltip,
      onPressed: () => _showOrderDialog(context),
    );
  }
}

class _SortDialog<T> extends StatefulWidget {
  final List<SortOptionWithTranslationKey<T>> availableOptions;
  final SortConfig<T> config;
  final SortConfig<T> defaultConfig;
  final Function(SortConfig<T>) onConfigChanged;
  final bool showCustomOrderOption;
  final ITranslationService translationService;
  final VoidCallback? onClose;

  const _SortDialog({
    required this.availableOptions,
    required this.config,
    required this.defaultConfig,
    required this.onConfigChanged,
    required this.translationService,
    this.showCustomOrderOption = false,
    this.onClose,
  });

  @override
  State<_SortDialog<T>> createState() => _SortDialogState<T>();
}

class _SortDialogState<T> extends State<_SortDialog<T>> {
  late SortConfig<T> _currentConfig;

  @override
  void initState() {
    super.initState();
    _currentConfig = widget.config;
  }

  bool _canAddMoreCriteria() {
    final availableOptions = widget.availableOptions.where(
      (option) => !_currentConfig.orderOptions.any((existing) => existing.field == option.field),
    );
    return availableOptions.isNotEmpty;
  }

  void _addCriteria() {
    final availableOptions = widget.availableOptions
        .where(
          (option) => !_currentConfig.orderOptions.any((existing) => existing.field == option.field),
        )
        .toList();

    if (availableOptions.isEmpty) return;

    setState(() {
      _currentConfig = _currentConfig.copyWith(
        orderOptions: [..._currentConfig.orderOptions, availableOptions.first],
      );
      widget.onConfigChanged(_currentConfig);
    });
  }

  void _removeCriteria(int index) {
    setState(() {
      final newOptions = List<SortOptionWithTranslationKey<T>>.from(_currentConfig.orderOptions)..removeAt(index);
      _currentConfig = _currentConfig.copyWith(orderOptions: newOptions);
      widget.onConfigChanged(_currentConfig);
    });
  }

  void _toggleDirection(int index) {
    setState(() {
      final newOptions = List<SortOptionWithTranslationKey<T>>.from(_currentConfig.orderOptions);
      final option = newOptions[index];
      newOptions[index] = option.withDirection(
        option.direction == SortDirection.asc ? SortDirection.desc : SortDirection.asc,
      );
      _currentConfig = _currentConfig.copyWith(orderOptions: newOptions);
      widget.onConfigChanged(_currentConfig);
    });
  }

  void _changeField(int index, T newField) {
    final newOption = widget.availableOptions.firstWhere((option) => option.field == newField);
    setState(() {
      final newOptions = List<SortOptionWithTranslationKey<T>>.from(_currentConfig.orderOptions);
      newOptions[index] = SortOptionWithTranslationKey(
        field: newOption.field,
        translationKey: newOption.translationKey,
        direction: _currentConfig.orderOptions[index].direction,
      );
      _currentConfig = _currentConfig.copyWith(orderOptions: newOptions);
      widget.onConfigChanged(_currentConfig);
    });
  }

  void _reorderCriteria(int oldIndex, int newIndex) {
    setState(() {
      final newOptions = List<SortOptionWithTranslationKey<T>>.from(_currentConfig.orderOptions);

      // Adjust newIndex for ReorderableListView behavior
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      // Safety check: newIndex must be within valid range
      newIndex = newIndex.clamp(0, newOptions.length - 1);

      final option = newOptions.removeAt(oldIndex);
      newOptions.insert(newIndex, option);
      _currentConfig = _currentConfig.copyWith(orderOptions: newOptions);
      widget.onConfigChanged(_currentConfig);
    });
  }

  void _resetToDefault() {
    setState(() {
      _currentConfig = widget.defaultConfig;
      widget.onConfigChanged(_currentConfig);
    });
  }

  void _toggleCustomOrder(bool value) {
    setState(() {
      _currentConfig = _currentConfig.copyWith(useCustomOrder: value);
      widget.onConfigChanged(_currentConfig);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = _currentConfig.useCustomOrder;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.translationService.translate(SharedTranslationKeys.sort)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: widget.translationService.translate(SharedTranslationKeys.closeButton),
          onPressed: () {
            widget.onClose?.call();
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            child: Text(widget.translationService.translate(SharedTranslationKeys.doneButton)),
            onPressed: () {
              widget.onClose?.call();
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: AppTheme.sizeSmall),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium, vertical: AppTheme.sizeSmall),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showCustomOrderOption) ...[
              SwitchListTile(
                title: Text(
                  widget.translationService.translate(SharedTranslationKeys.sortCustomTitle),
                  style: AppTheme.bodyMedium,
                ),
                subtitle: Text(
                  widget.translationService.translate(SharedTranslationKeys.sortCustomDescription),
                  style: AppTheme.bodySmall,
                ),
                value: _currentConfig.useCustomOrder,
                onChanged: _toggleCustomOrder,
              ),
              const Divider(),
            ],
            Flexible(
              fit: FlexFit.loose,
              child: isDisabled
                  ? ListView.builder(
                      shrinkWrap: true,
                      itemCount: _currentConfig.orderOptions.length,
                      itemBuilder: (context, index) {
                        return _buildCriteriaRow(index);
                      },
                    )
                  : ReorderableListView.builder(
                      shrinkWrap: true,
                      itemCount: _currentConfig.orderOptions.length,
                      onReorder: _reorderCriteria,
                      itemBuilder: (context, index) {
                        return _buildCriteriaRow(index);
                      },
                    ),
            ),
            if (!isDisabled) ...[
              const SizedBox(height: AppTheme.sizeSmall),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: Icon(
                      Icons.add,
                      color: _canAddMoreCriteria() ? Theme.of(context).primaryColor : Theme.of(context).disabledColor,
                    ),
                    label: Text(
                      widget.translationService.translate(SharedTranslationKeys.addButton),
                      style: AppTheme.bodyMedium.copyWith(
                        color: _canAddMoreCriteria() ? Theme.of(context).primaryColor : Theme.of(context).disabledColor,
                      ),
                    ),
                    onPressed: _canAddMoreCriteria() ? _addCriteria : null,
                  ),
                  Tooltip(
                    message: widget.translationService.translate(SharedTranslationKeys.refreshTooltip),
                    child: TextButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        widget.translationService.translate(SharedTranslationKeys.sortResetToDefault),
                        style: AppTheme.bodyMedium,
                      ),
                      onPressed: _resetToDefault,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCriteriaRow(int index) {
    final option = _currentConfig.orderOptions[index];
    final availableFields = widget.availableOptions
        .where((availableOption) =>
            availableOption.field == option.field ||
            !_currentConfig.orderOptions.any((existing) => existing.field == availableOption.field))
        .toList();
    final bool isDisabled = _currentConfig.useCustomOrder;

    return ListTile(
      key: Key('criteria_$index'),
      dense: true,
      title: AbsorbPointer(
        absorbing: isDisabled,
        child: DropdownButton<T>(
          value: option.field,
          isExpanded: true,
          isDense: true,
          underline: Container(),
          onChanged: isDisabled
              ? null
              : (newValue) {
                  if (newValue != null) {
                    _changeField(index, newValue);
                  }
                },
          items: availableFields
              .map((o) => DropdownMenuItem<T>(
                    value: o.field,
                    child: Text(
                      widget.translationService.translate(o.translationKey),
                      style: AppTheme.bodyMedium.copyWith(
                        color: isDisabled
                            ? Theme.of(context).disabledColor
                            : Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              option.direction == SortDirection.asc ? Icons.arrow_upward : Icons.arrow_downward,
              size: 20,
              color: isDisabled ? Theme.of(context).disabledColor : null,
            ),
            tooltip: widget.translationService.translate(
              option.direction == SortDirection.asc
                  ? SharedTranslationKeys.sortAscending
                  : SharedTranslationKeys.sortDescending,
            ),
            onPressed: isDisabled ? null : () => _toggleDirection(index),
            padding: const EdgeInsets.all(AppTheme.sizeSmall),
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
          ),
          if (_currentConfig.orderOptions.length > 1)
            IconButton(
              icon: Icon(Icons.close, size: 20, color: isDisabled ? Theme.of(context).disabledColor : null),
              tooltip: widget.translationService.translate(SharedTranslationKeys.sortRemoveCriteria),
              onPressed: isDisabled ? null : () => _removeCriteria(index),
              padding: const EdgeInsets.all(AppTheme.sizeSmall),
              constraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
            ),
          // Drag handle for reordering
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
            const SizedBox(width: AppTheme.sizeMedium), // Spacer for better alignment
          if (_currentConfig.orderOptions.length > 1 && Platform.isAndroid) ...[
            ReorderableDragStartListener(
              index: index,
              child: IconButton(
                  icon: Icon(Icons.drag_handle, size: 20, color: isDisabled ? Theme.of(context).disabledColor : null),
                  tooltip: widget.translationService.translate(SharedTranslationKeys.sort),
                  onPressed: isDisabled ? null : () {}),
            ),
          ],
        ],
      ),
    );
  }
}
