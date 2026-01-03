import 'package:flutter/material.dart';
import 'package:acore/acore.dart' show SortDirection;
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/models/sort_option_with_translation_key.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';

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
  final bool showGroupingOption;
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
    this.showGroupingOption = true,
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
          showGroupingOption: widget.showGroupingOption,
          translationService: _translationService,
          onClose: widget.onDialogClose,
        ),
        size: DialogSize.xLarge);
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
  final bool showGroupingOption;
  final ITranslationService translationService;
  final VoidCallback? onClose;

  const _SortDialog({
    required this.availableOptions,
    required this.config,
    required this.defaultConfig,
    required this.onConfigChanged,
    required this.translationService,
    this.showCustomOrderOption = false,
    this.showGroupingOption = true,
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

  void _toggleGrouping(bool value) {
    setState(() {
      _currentConfig = _currentConfig.copyWith(enableGrouping: value);
      widget.onConfigChanged(_currentConfig);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = _currentConfig.useCustomOrder;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.translationService.translate(SharedTranslationKeys.sortAndGroup),
          style: AppTheme.headlineSmall,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: widget.translationService.translate(SharedTranslationKeys.backButton),
          onPressed: () {
            widget.onClose?.call();
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            child: Text(
              widget.translationService.translate(SharedTranslationKeys.doneButton),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              widget.onClose?.call();
              Navigator.of(context).pop();
            },
          ),
        ],
        elevation: 0,
      ),
      body: SafeArea(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.all(AppTheme.sizeLarge),
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showCustomOrderOption) ...[
                Card(
                  elevation: 0,
                  color: AppTheme.surface1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius)),
                  child: SwitchListTile.adaptive(
                    value: _currentConfig.useCustomOrder,
                    onChanged: _toggleCustomOrder,
                    title: Text(
                      widget.translationService.translate(SharedTranslationKeys.sortCustomTitle),
                      style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      widget.translationService.translate(SharedTranslationKeys.sortCustomDescription),
                      style: AppTheme.bodySmall,
                    ),
                    secondary: StyledIcon(
                      Icons.low_priority,
                      isActive: _currentConfig.useCustomOrder,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.sizeSmall),
              ],
              if (widget.showGroupingOption) ...[
                Card(
                  elevation: 0,
                  color: AppTheme.surface1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius)),
                  child: SwitchListTile.adaptive(
                    value: _currentConfig.enableGrouping,
                    onChanged: isDisabled ? null : _toggleGrouping,
                    title: Text(
                      widget.translationService.translate(SharedTranslationKeys.sortEnableGrouping),
                      style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      widget.translationService.translate(SharedTranslationKeys.sortEnableGroupingDescription),
                      style: AppTheme.bodySmall,
                    ),
                    secondary: StyledIcon(
                      Icons.view_list,
                      isActive: _currentConfig.enableGrouping && !isDisabled,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.sizeSmall),
              ],
              if (!isDisabled)
                Padding(
                  padding: const EdgeInsets.only(left: AppTheme.sizeSmall, bottom: AppTheme.sizeSmall),
                  child: Text(
                    widget.translationService.translate(SharedTranslationKeys.sortCriteria),
                    style: AppTheme.labelLarge,
                  ),
                ),
            ],
          ),
          itemCount: isDisabled ? 0 : _currentConfig.orderOptions.length,
          itemBuilder: (context, index) {
            return _buildCriteriaRow(index);
          },
          onReorder: _reorderCriteria,
          buildDefaultDragHandles: false,
          proxyDecorator: (child, index, animation) {
            return Material(
              elevation: 2,
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
              child: child,
            );
          },
          footer: isDisabled
              ? null
              : Column(
                  children: [
                    const SizedBox(height: AppTheme.sizeMedium),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _canAddMoreCriteria() ? _addCriteria : null,
                            borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: AppTheme.sizeMedium),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _canAddMoreCriteria()
                                      ? Theme.of(context).primaryColor.withValues(alpha: 0.5)
                                      : Theme.of(context).disabledColor.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                                color: _canAddMoreCriteria()
                                    ? Theme.of(context).primaryColor.withValues(alpha: 0.05)
                                    : Colors.transparent,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add,
                                    size: 20,
                                    color: _canAddMoreCriteria()
                                        ? Theme.of(context).primaryColor
                                        : Theme.of(context).disabledColor,
                                  ),
                                  const SizedBox(width: AppTheme.sizeSmall),
                                  Text(
                                    widget.translationService.translate(SharedTranslationKeys.addButton),
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: _canAddMoreCriteria()
                                          ? Theme.of(context).primaryColor
                                          : Theme.of(context).disabledColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.sizeMedium),
                        Tooltip(
                          message: widget.translationService.translate(SharedTranslationKeys.resetTooltip),
                          child: InkWell(
                            onTap: _resetToDefault,
                            borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                            child: Container(
                              padding: const EdgeInsets.all(AppTheme.sizeMedium),
                              decoration: BoxDecoration(
                                color: AppTheme.surface1,
                                borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                              ),
                              child: const Icon(Icons.refresh),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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

    return Container(
      key: ValueKey(option.field),
      margin: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium, vertical: 4),
        leading: StyledIcon(
          Icons.sort,
          isActive: true,
          size: 20,
        ),
        title: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: option.field,
            isExpanded: true,
            isDense: true,
            icon: const Icon(Icons.arrow_drop_down),
            onChanged: (newValue) {
              if (newValue != null) {
                _changeField(index, newValue);
              }
            },
            items: availableFields
                .map((o) => DropdownMenuItem<T>(
                      value: o.field,
                      child: Text(
                        widget.translationService.translate(o.translationKey),
                        style: AppTheme.bodyMedium,
                      ),
                    ))
                .toList(),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => _toggleDirection(index),
              borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  option.direction == SortDirection.asc ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            if (_currentConfig.orderOptions.length > 1)
              InkWell(
                onTap: () => _removeCriteria(index),
                borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(Icons.close, size: 20, color: AppTheme.textColor.withValues(alpha: 0.5)),
                ),
              ),
            // Drag handle for reordering
            ReorderableDragStartListener(
              index: index,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.drag_handle,
                    size: 20,
                    color: AppTheme.textColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
