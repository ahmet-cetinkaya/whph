import 'dart:async';
import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/models/date_filter_setting.dart';
import 'package:whph/presentation/ui/shared/components/date_range_filter/helpers/quick_date_range_helper.dart';
import 'package:acore/acore.dart' show QuickDateRange;

/// Controller for managing DateRangeFilter state and auto-refresh logic.
class DateRangeFilterController extends ChangeNotifier {
  final QuickDateRangeHelper _quickRangeHelper;

  List<QuickDateRange>? _additionalQuickRanges;

  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  DateFilterSetting? _dateFilterSetting;
  String? _activeQuickSelectionKey;
  Timer? _autoRefreshTimer;
  DateFilterSetting? _preservedQuickSelectionSetting;
  bool _isRefreshToggleEnabled = false;
  bool _justCleared = false;
  bool _includeNullDates = false;

  // Getters
  DateTime? get selectedStartDate => _selectedStartDate;
  DateTime? get selectedEndDate => _selectedEndDate;
  DateFilterSetting? get dateFilterSetting => _dateFilterSetting;
  String? get activeQuickSelectionKey => _activeQuickSelectionKey;
  bool get isRefreshToggleEnabled => _isRefreshToggleEnabled;
  bool get includeNullDates => _includeNullDates;
  bool get hasDateFilter => _selectedStartDate != null && _selectedEndDate != null;

  set additionalQuickRanges(List<QuickDateRange>? value) {
    _additionalQuickRanges = value;
    notifyListeners();
  }

  DateRangeFilterController({required QuickDateRangeHelper quickRangeHelper}) : _quickRangeHelper = quickRangeHelper;

  /// Initialize state from widget properties
  void initializeFromSettings({
    DateFilterSetting? dateFilterSetting,
    DateTime? selectedStartDate,
    DateTime? selectedEndDate,
  }) {
    _dateFilterSetting = dateFilterSetting;

    if (_dateFilterSetting != null) {
      _activeQuickSelectionKey = _dateFilterSetting!.quickSelectionKey;
      _isRefreshToggleEnabled = _dateFilterSetting!.isAutoRefreshEnabled;
      _includeNullDates = _dateFilterSetting!.includeNullDates;

      if (_dateFilterSetting!.isQuickSelection) {
        final currentRange = _dateFilterSetting!.calculateCurrentDateRange();
        _selectedStartDate = currentRange.startDate;
        _selectedEndDate = currentRange.endDate;
        _preservedQuickSelectionSetting = _dateFilterSetting;
      } else {
        _selectedStartDate = _dateFilterSetting!.startDate;
        _selectedEndDate = _dateFilterSetting!.endDate;
      }
    } else {
      _selectedStartDate = selectedStartDate;
      _selectedEndDate = selectedEndDate;
      _activeQuickSelectionKey = null;
      _isRefreshToggleEnabled = false;
      _includeNullDates = false;

      if (_selectedStartDate != null && _selectedEndDate != null) {
        _tryDetectQuickSelectionFromDates();
      }
    }

    setupAutoRefresh();
    notifyListeners();
  }

  /// Update from widget's dateFilterSetting property
  void updateFromSettings(DateFilterSetting? dateFilterSetting) {
    _dateFilterSetting = dateFilterSetting;

    if (_dateFilterSetting != null) {
      _activeQuickSelectionKey = _dateFilterSetting!.quickSelectionKey;
      _isRefreshToggleEnabled = _dateFilterSetting!.isAutoRefreshEnabled;
      _includeNullDates = _dateFilterSetting!.includeNullDates;

      if (_dateFilterSetting!.isQuickSelection) {
        final currentRange = _dateFilterSetting!.calculateCurrentDateRange();
        _selectedStartDate = currentRange.startDate;
        _selectedEndDate = currentRange.endDate;
        _preservedQuickSelectionSetting = _dateFilterSetting;
      } else {
        _selectedStartDate = _dateFilterSetting!.startDate;
        _selectedEndDate = _dateFilterSetting!.endDate;
        _preservedQuickSelectionSetting = null;
      }
    } else {
      _selectedStartDate = null;
      _selectedEndDate = null;
      _activeQuickSelectionKey = null;
      _isRefreshToggleEnabled = false;
      _includeNullDates = false;
      _preservedQuickSelectionSetting = null;
    }

    setupAutoRefresh();
    notifyListeners();
  }

  /// Update from legacy date properties
  void updateFromLegacyDates(DateTime? startDate, DateTime? endDate) {
    _selectedStartDate = startDate;
    _selectedEndDate = endDate;

    if (_selectedStartDate != null && _selectedEndDate != null && !_justCleared) {
      _tryDetectQuickSelectionFromDates();
    } else {
      _activeQuickSelectionKey = null;
      _isRefreshToggleEnabled = false;
      _preservedQuickSelectionSetting = null;
    }

    _justCleared = false;
    setupAutoRefresh();
    notifyListeners();
  }

  void _tryDetectQuickSelectionFromDates() {
    if (_selectedStartDate == null || _selectedEndDate == null) return;

    final detected = _quickRangeHelper.tryDetectQuickSelectionFromDates(_selectedStartDate!, _selectedEndDate!);

    if (detected != null) {
      _activeQuickSelectionKey = detected.quickSelectionKey;
      _isRefreshToggleEnabled = false;
      _dateFilterSetting = detected;
      _preservedQuickSelectionSetting = null;
    }
  }

  /// Setup auto-refresh timer for quick selections
  void setupAutoRefresh() {
    _autoRefreshTimer?.cancel();

    if (_dateFilterSetting?.isQuickSelection == true && _isRefreshToggleEnabled) {
      _preservedQuickSelectionSetting = _dateFilterSetting;

      Duration refreshInterval;
      switch (_activeQuickSelectionKey) {
        case 'today':
          refreshInterval = const Duration(minutes: 15);
          break;
        case 'this_week':
          refreshInterval = const Duration(hours: 1);
          break;
        case 'this_month':
        case 'this_3_months':
          refreshInterval = const Duration(hours: 4);
          break;
        default:
          refreshInterval = const Duration(minutes: 30);
      }

      _autoRefreshTimer = Timer.periodic(refreshInterval, (timer) {
        _refreshQuickSelection();
      });
    }
  }

  void _refreshQuickSelection() {
    final activeQuickSetting = _preservedQuickSelectionSetting ?? _dateFilterSetting;

    if (activeQuickSetting?.isQuickSelection != true) return;

    final currentRange = activeQuickSetting!.calculateCurrentDateRange();
    final hasChanged = currentRange.startDate != _selectedStartDate || currentRange.endDate != _selectedEndDate;

    if (hasChanged) {
      _selectedStartDate = currentRange.startDate;
      _selectedEndDate = currentRange.endDate;
      _dateFilterSetting = activeQuickSetting;
      _activeQuickSelectionKey = activeQuickSetting.quickSelectionKey;
      notifyListeners();
    }
  }

  /// Check if auto-refresh is currently active
  bool isAutoRefreshActive() {
    return _isRefreshToggleEnabled && _activeQuickSelectionKey != null && _autoRefreshTimer?.isActive == true;
  }

  /// Check if new setting matches current quick selection
  bool isSameQuickSelection(DateFilterSetting? newSetting) {
    return newSetting?.quickSelectionKey == _activeQuickSelectionKey && newSetting?.isAutoRefreshEnabled == true;
  }

  /// Apply date picker result
  void applyDatePickerResult({
    DateTime? startDate,
    DateTime? endDate,
    bool refreshEnabled = false,
    String? quickSelectionKey,
    bool includeNullDates = false,
  }) {
    _selectedStartDate = startDate;
    _selectedEndDate = endDate;
    _includeNullDates = includeNullDates;

    if (quickSelectionKey != null && startDate != null && endDate != null) {
      _activeQuickSelectionKey = quickSelectionKey;
      _isRefreshToggleEnabled = refreshEnabled;
      _dateFilterSetting = DateFilterSetting.quickSelection(
        key: quickSelectionKey,
        startDate: startDate,
        endDate: endDate,
        isAutoRefreshEnabled: refreshEnabled,
        includeNullDates: includeNullDates,
      );
      if (refreshEnabled) {
        _preservedQuickSelectionSetting = _dateFilterSetting;
      }
    } else if (startDate != null || endDate != null) {
      _activeQuickSelectionKey = null;
      _isRefreshToggleEnabled = false;
      _preservedQuickSelectionSetting = null;
      _dateFilterSetting = DateFilterSetting.manual(
        startDate: startDate,
        endDate: endDate,
        includeNullDates: includeNullDates,
      );
    } else {
      _activeQuickSelectionKey = null;
      _isRefreshToggleEnabled = false;
      _preservedQuickSelectionSetting = null;
      _dateFilterSetting = null;
    }

    setupAutoRefresh();
    notifyListeners();
  }

  /// Clear the date filter
  void clear() {
    _selectedStartDate = null;
    _selectedEndDate = null;
    _dateFilterSetting = null;
    _activeQuickSelectionKey = null;
    _isRefreshToggleEnabled = false;
    _includeNullDates = false;
    _justCleared = true;
    _autoRefreshTimer?.cancel();
    _preservedQuickSelectionSetting = null;
    notifyListeners();
  }

  /// Get date range text for display
  String getDateRangeText() {
    if (_selectedStartDate == null || _selectedEndDate == null) return '';

    if (_activeQuickSelectionKey != null) {
      // First check defaults
      final label = _quickRangeHelper.getLabelForKey(_activeQuickSelectionKey!);
      if (label != null) return label;

      // Then check additional ranges
      if (_additionalQuickRanges != null) {
        try {
          final range = _additionalQuickRanges!.firstWhere((r) => r.key == _activeQuickSelectionKey);
          return range.label;
        } catch (_) {}
      }
    }

    return '${_selectedStartDate!.day}/${_selectedStartDate!.month} - ${_selectedEndDate!.day}/${_selectedEndDate!.month}';
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _preservedQuickSelectionSetting = null;
    super.dispose();
  }
}
