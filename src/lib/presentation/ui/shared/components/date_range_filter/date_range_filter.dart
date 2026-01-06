import 'dart:async';
import 'package:flutter/material.dart' hide DatePickerDialog;
import 'package:acore/acore.dart'
    show
        DatePickerConfig,
        DateSelectionMode,
        DatePickerDialog,
        DateTimePickerTranslationKey,
        DialogSize,
        QuickDateRange,
        DatePickerFooterAction;
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/components/filter_icon_button.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/models/date_filter_setting.dart';
import 'package:whph/presentation/ui/shared/components/date_range_filter/controllers/date_range_filter_controller.dart';
import 'package:whph/presentation/ui/shared/components/date_range_filter/helpers/quick_date_range_helper.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';

class DateRangeFilter extends StatefulWidget {
  final DateTime? selectedStartDate;
  final DateTime? selectedEndDate;
  final DateFilterSetting? dateFilterSetting;
  final Function(DateTime?, DateTime?) onDateFilterChange;
  final Function(DateFilterSetting?)? onDateFilterSettingChange;
  final Function(DateTime?, DateTime?, DateFilterSetting?)? onAutoRefresh;
  final double iconSize;
  final Color? iconColor;
  final List<QuickDateRange>? additionalQuickRanges;
  final List<DatePickerFooterAction>? footerActions;

  const DateRangeFilter({
    super.key,
    this.selectedStartDate,
    this.selectedEndDate,
    this.dateFilterSetting,
    required this.onDateFilterChange,
    this.onDateFilterSettingChange,
    this.onAutoRefresh,
    this.iconSize = AppTheme.iconSizeMedium,
    this.iconColor,
    this.additionalQuickRanges,
    this.footerActions,
  });

  @override
  State<DateRangeFilter> createState() => _DateRangeFilterState();
}

class _DateRangeFilterState extends State<DateRangeFilter> {
  late final ITranslationService _translationService;
  late final QuickDateRangeHelper _quickRangeHelper;
  late final DateRangeFilterController _controller;
  StreamSubscription? _autoRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _translationService = container.resolve<ITranslationService>();
    _quickRangeHelper = QuickDateRangeHelper(translationService: _translationService);
    _controller = DateRangeFilterController(quickRangeHelper: _quickRangeHelper);
    _controller.additionalQuickRanges = widget.additionalQuickRanges;

    _controller.addListener(_onControllerChanged);
    _controller.initializeFromSettings(
      dateFilterSetting: widget.dateFilterSetting,
      selectedStartDate: widget.selectedStartDate,
      selectedEndDate: widget.selectedEndDate,
    );
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
      // Notify parent of auto-refresh changes
      if (_controller.isAutoRefreshActive()) {
        widget.onAutoRefresh?.call(
          _controller.selectedStartDate,
          _controller.selectedEndDate,
          _controller.dateFilterSetting,
        );
      }
    }
  }

  @override
  void didUpdateWidget(DateRangeFilter oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.additionalQuickRanges != oldWidget.additionalQuickRanges) {
      _controller.additionalQuickRanges = widget.additionalQuickRanges;
    }

    if (widget.dateFilterSetting != oldWidget.dateFilterSetting) {
      if (_controller.isAutoRefreshActive() && _controller.isSameQuickSelection(widget.dateFilterSetting)) {
        return;
      }
      _controller.updateFromSettings(widget.dateFilterSetting);
    } else if (widget.selectedStartDate != oldWidget.selectedStartDate ||
        widget.selectedEndDate != oldWidget.selectedEndDate) {
      _controller.updateFromLegacyDates(widget.selectedStartDate, widget.selectedEndDate);
    }
  }

  @override
  void dispose() {
    _autoRefreshSubscription?.cancel();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final translations = <DateTimePickerTranslationKey, String>{
      for (final key in DateTimePickerTranslationKey.values)
        key: _translationService.translate(SharedTranslationKeys.mapDateTimePickerKey(key)),
    };

    final quickRanges = [
      if (widget.additionalQuickRanges != null) ...widget.additionalQuickRanges!,
      ..._quickRangeHelper.getQuickRanges(),
    ];

    final config = DatePickerConfig(
      selectionMode: DateSelectionMode.range,
      initialStartDate: _controller.selectedStartDate,
      initialEndDate: _controller.selectedEndDate,
      minDate: TaskUiConstants.minFilterDate,
      maxDate: TaskUiConstants.maxFilterDate,
      showQuickRanges: true,
      quickRanges: quickRanges,
      enableManualInput: true,
      translations: translations,
      showRefreshToggle: true,
      initialRefreshEnabled: _controller.isRefreshToggleEnabled,
      onRefreshToggleChanged: (bool enabled) {},
      actionButtonRadius: AppTheme.containerBorderRadius,
      allowNullConfirm: true,
      dialogSize: DialogSize.xLarge,
      footerActions: widget.footerActions,
    );

    final result = await DatePickerDialog.showResponsive(
      context: context,
      config: config,
    );

    if (result != null) {
      final startDate = result.startDate;
      final endDate = result.endDate;
      final refreshEnabled = result.isRefreshEnabled;

      // Detect quick selection
      String? quickSelectionKey = result.quickSelectionKey;
      if (quickSelectionKey == null && startDate != null && endDate != null) {
        quickSelectionKey = _quickRangeHelper.detectQuickSelectionKey(startDate, endDate);
      }

      // Check if only refresh toggle changed
      final hasOnlyRefreshChanged = startDate == _controller.selectedStartDate &&
          endDate == _controller.selectedEndDate &&
          _controller.activeQuickSelectionKey != null &&
          refreshEnabled != _controller.isRefreshToggleEnabled;

      if (hasOnlyRefreshChanged) {
        quickSelectionKey = _controller.activeQuickSelectionKey;
      }

      _controller.applyDatePickerResult(
        startDate: startDate,
        endDate: endDate,
        refreshEnabled: refreshEnabled,
        quickSelectionKey: quickSelectionKey,
        includeNullDates: widget.dateFilterSetting?.includeNullDates ?? false,
      );

      widget.onDateFilterChange(startDate, endDate);
      widget.onDateFilterSettingChange?.call(_controller.dateFilterSetting);
    }
  }

  void _onClearDate() {
    _controller.clear();
    widget.onDateFilterChange(null, null);
    widget.onDateFilterSettingChange?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final hasDateFilter = _controller.hasDateFilter;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilterIconButton(
          icon: Icons.calendar_month,
          iconSize: widget.iconSize,
          color: hasDateFilter ? primaryColor : widget.iconColor,
          tooltip: _translationService.translate(SharedTranslationKeys.dateFilterTooltip),
          onPressed: () => _showDatePicker(context),
        ),
        if (hasDateFilter) ...[
          const SizedBox(width: AppTheme.size2XSmall),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_controller.isRefreshToggleEnabled && _controller.activeQuickSelectionKey != null) ...[
                Icon(
                  Icons.autorenew,
                  size: AppTheme.iconSizeSmall,
                  color: primaryColor,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                _controller.getDateRangeText(),
                style: AppTheme.bodySmall.copyWith(
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppTheme.size2XSmall),
          FilterIconButton(
            icon: Icons.close,
            iconSize: AppTheme.iconSizeSmall,
            onPressed: _onClearDate,
            tooltip: _translationService.translate(SharedTranslationKeys.clearDateFilterTooltip),
          ),
        ],
      ],
    );
  }
}
