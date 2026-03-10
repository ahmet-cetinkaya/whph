import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:acore/acore.dart' show SortDirection;
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';
import 'package:whph/presentation/ui/shared/models/sort_option_with_translation_key.dart';

class GroupDialogButton<T> extends StatefulWidget {
  final Color? iconColor;
  final double iconSize;
  final String tooltip;
  final SortConfig<T> config;
  final Function(SortConfig<T>) onConfigChanged;
  final List<SortOptionWithTranslationKey<T>>? availableOptions;

  const GroupDialogButton({
    super.key,
    required this.tooltip,
    required this.config,
    required this.onConfigChanged,
    this.availableOptions,
    this.iconColor,
    this.iconSize = AppTheme.iconSizeMedium,
  });

  @override
  State<GroupDialogButton<T>> createState() => _GroupDialogButtonState<T>();
}

class _GroupDialogButtonState<T> extends State<GroupDialogButton<T>> {
  late final _translationService = container.resolve<ITranslationService>();

  Future<void> _showGroupDialog(BuildContext context) async {
    await ResponsiveDialogHelper.showResponsiveDialog(
        context: context,
        child: _GroupDialog<T>(
          config: widget.config,
          onConfigChanged: widget.onConfigChanged,
          translationService: _translationService,
          availableOptions: widget.availableOptions,
        ),
        size: DialogSize.xLarge,
        isScrollable: false);
  }

  @override
  Widget build(BuildContext context) {
    final Color effectiveColor = widget.iconColor ?? Theme.of(context).primaryColor;
    final bool isActive = widget.config.enableGrouping;

    return Material(
      type: MaterialType.transparency,
      child: Tooltip(
        message: widget.tooltip,
        child: InkWell(
          onTap: () => _showGroupDialog(context),
          customBorder: const CircleBorder(),
          hoverColor: AppTheme.surface1,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              isActive ? Icons.view_agenda : Icons.view_agenda_outlined,
              color: isActive ? effectiveColor : Colors.grey,
              size: widget.iconSize,
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupDialog<T> extends StatefulWidget {
  final SortConfig<T> config;
  final Function(SortConfig<T>) onConfigChanged;
  final ITranslationService translationService;
  final List<SortOptionWithTranslationKey<T>>? availableOptions;

  const _GroupDialog({
    required this.config,
    required this.onConfigChanged,
    required this.translationService,
    this.availableOptions,
  });

  @override
  State<_GroupDialog<T>> createState() => _GroupDialogState<T>();
}

class _GroupDialogState<T> extends State<_GroupDialog<T>> {
  late SortConfig<T> _currentConfig;

  @override
  void initState() {
    super.initState();
    _currentConfig = widget.config;
  }

  void _toggleGrouping(bool value) {
    SortOptionWithTranslationKey<T>? newGroupOption = _currentConfig.groupOption;

    if (value && newGroupOption == null) {
      if (_currentConfig.orderOptions.isNotEmpty) {
        newGroupOption = _currentConfig.orderOptions.first;
      } else if (widget.availableOptions?.isNotEmpty ?? false) {
        newGroupOption = widget.availableOptions!.first;
      }
    }

    setState(() {
      _currentConfig = _currentConfig.copyWith(
        enableGrouping: value,
        groupOption: newGroupOption,
      );
      widget.onConfigChanged(_currentConfig);
    });
  }

  void _toggleGroupDirection() {
    setState(() {
      final currentOption = _currentConfig.groupOption ??
          (widget.availableOptions?.isNotEmpty ?? false
              ? widget.availableOptions!.first
              : _currentConfig.orderOptions.first);

      final newOption = currentOption.withDirection(
        currentOption.direction == SortDirection.asc ? SortDirection.desc : SortDirection.asc,
      );

      _currentConfig = _currentConfig.copyWith(groupOption: newOption);
      widget.onConfigChanged(_currentConfig);
    });
  }

  void _changeGroupField(T newField) {
    if (widget.availableOptions == null) return;

    final newOptionTemplate = widget.availableOptions!.firstWhere((option) => option.field == newField);

    // Preserve current direction if possible, or default to asc
    final currentDirection = _currentConfig.groupOption?.direction ?? SortDirection.asc;

    final newOption = SortOptionWithTranslationKey(
        field: newOptionTemplate.field, translationKey: newOptionTemplate.translationKey, direction: currentDirection);

    setState(() {
      _currentConfig = _currentConfig.copyWith(groupOption: newOption);
      widget.onConfigChanged(_currentConfig);
    });
  }

  Widget _buildGroupOptionItem(BuildContext context, SortOptionWithTranslationKey<T> option) {
    final isSelected = _currentConfig.groupOption?.field == option.field ||
        (_currentConfig.groupOption == null &&
            _currentConfig.orderOptions.isNotEmpty &&
            _currentConfig.orderOptions.first.field == option.field);

    final currentOption = isSelected ? (_currentConfig.groupOption ?? option) : option;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium, vertical: 4),
        onTap: () => _changeGroupField(option.field),
        title: Text(
          widget.translationService.translate(option.translationKey),
          style: AppTheme.bodyMedium.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              IconButton(
                icon: Icon(
                  currentOption.direction == SortDirection.asc ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: _toggleGroupDirection,
                tooltip: widget.translationService.translate(
                  currentOption.direction == SortDirection.asc
                      ? SharedTranslationKeys.sortAscending
                      : SharedTranslationKeys.sortDescending,
                ),
              ),
            Radio<T>(
              value: option.field,
              groupValue: isSelected ? option.field : null,
              onChanged: (value) {
                if (value != null) {
                  _changeGroupField(value);
                }
              },
              activeColor: Theme.of(context).primaryColor,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header (mimicking AppBar)
        AppBar(
          title: Text(
            widget.translationService.translate(SharedTranslationKeys.sortEnableGrouping),
            style: AppTheme.headlineSmall,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: widget.translationService.translate(SharedTranslationKeys.backButton),
            onPressed: () {
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
                Navigator.of(context).pop();
              },
            ),
          ],
          elevation: 0,
        ),

        // Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.sizeLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 0,
                  color: AppTheme.surface1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius)),
                  child: SwitchListTile.adaptive(
                    value: _currentConfig.enableGrouping,
                    onChanged: _toggleGrouping,
                    title: Text(
                      widget.translationService.translate(SharedTranslationKeys.sortEnableGrouping),
                      style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      widget.translationService.translate(SharedTranslationKeys.sortEnableGroupingDescription),
                      style: AppTheme.bodySmall,
                    ),
                    secondary: StyledIcon(
                      Icons.view_agenda,
                      isActive: _currentConfig.enableGrouping,
                    ),
                  ),
                ),
                if (_currentConfig.enableGrouping &&
                    widget.availableOptions != null &&
                    widget.availableOptions!.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.sizeMedium),
                  Padding(
                    padding: const EdgeInsets.only(left: AppTheme.sizeSmall, bottom: AppTheme.sizeSmall),
                    child: Text(
                      widget.translationService.translate(SharedTranslationKeys.groupBy),
                      style: AppTheme.labelLarge,
                    ),
                  ),
                  ...widget.availableOptions!.map((option) => _buildGroupOptionItem(context, option)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
