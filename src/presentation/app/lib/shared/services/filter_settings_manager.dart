import 'dart:convert';

import 'package:mediatr/mediatr.dart';
import 'package:application/features/settings/commands/save_setting_command.dart';
import 'package:application/features/settings/queries/get_setting_query.dart';
import 'package:domain/features/settings/setting.dart';

/// Manager for handling filter and sort settings persistence
class FilterSettingsManager {
  final Mediator _mediator;

  FilterSettingsManager(this._mediator);

  /// Save filter settings to persistent storage
  Future<void> saveFilterSettings({
    required String settingKey,
    required Map<String, dynamic> filterSettings,
  }) async {
    final settingValue = jsonEncode(filterSettings);

    await _mediator.send(
      SaveSettingCommand(
        key: settingKey,
        value: settingValue,
        valueType: SettingValueType.json,
      ),
    );
  }

  /// Load filter settings from persistent storage
  /// Returns null if no settings are found
  Future<Map<String, dynamic>?> loadFilterSettings({
    required String settingKey,
  }) async {
    try {
      final response = await _mediator.send(
        GetSettingQuery(key: settingKey),
      ) as GetSettingQueryResponse?;

      if (response == null) return null;

      return jsonDecode(response.value) as Map<String, dynamic>;
    } catch (e) {
      // Return null if setting doesn't exist
      return null;
    }
  }

  /// Check if current filter settings differ from saved settings
  Future<bool> hasUnsavedChanges({
    required String settingKey,
    required Map<String, dynamic> currentSettings,
  }) async {
    try {
      final savedSettings = await loadFilterSettings(settingKey: settingKey);
      if (savedSettings == null) {
        // If no saved settings, check if current settings are not default
        final hasNonDefault = _hasNonDefaultValues(currentSettings);
        return hasNonDefault;
      }

      // Compare current settings with saved settings
      final areEqual = _areSettingsEqual(currentSettings, savedSettings);
      return !areEqual;
    } catch (e) {
      // Assume no changes if error occurs
      return false;
    }
  }

  // Helper method to check if settings are equal
  bool _areSettingsEqual(Map<String, dynamic> settings1, Map<String, dynamic> settings2) {
    if (settings1.length != settings2.length) {
      return false;
    }

    for (final key in settings1.keys) {
      if (!settings2.containsKey(key)) {
        return false;
      }

      final value1 = settings1[key];
      final value2 = settings2[key];

      // If both are Maps, recurse.
      if (key == 'search') {
        // Treat null and empty string as equivalent for search
        // An empty string search is functionally the same as no search (null)
        final String? search1 = (value1 == null || (value1 is String && value1.isEmpty)) ? null : value1 as String?;
        final String? search2 = (value2 == null || (value2 is String && value2.isEmpty)) ? null : value2 as String?;

        if (search1 != search2) {
          return false;
        }
      } else if (key == 'dateFilterSetting') {
        // Special handling for dateFilterSetting - handle null cases
        final map1 = value1 is Map ? value1 : null;
        final map2 = value2 is Map ? value2 : null;
        if (!_areDateFilterSettingsEqual(map1, map2)) {
          return false;
        }
      } else if (value1 is Map && value2 is Map) {
        // Regular map comparison for other keys
        // Ensure keys are strings for recursive call, though practically they should be.
        final map1 = value1.map((k, v) => MapEntry(k.toString(), v));
        final map2 = value2.map((k, v) => MapEntry(k.toString(), v));
        if (!_areSettingsEqual(map1, map2)) {
          return false;
        }
      } else if (value1 is List && value2 is List) {
        if (!_areListsEqual(value1, value2, key)) {
          return false;
        }
      } else if (value1?.runtimeType != value2?.runtimeType) {
        // This handles cases where one is null and the other isn't,
        // or types are fundamentally different (e.g., String vs int).
        return false;
      } else if (value1 != value2) {
        // This handles simple types and nulls (null == null is true).
        return false;
      }
    }

    return true;
  }

  // Helper method to compare two lists, handling nested structures
  bool _areListsEqual(List list1, List list2, String parentKey) {
    if (list1.length != list2.length) {
      return false;
    }

    for (int i = 0; i < list1.length; i++) {
      final item1 = list1[i];
      final item2 = list2[i];

      if (item1 is Map && item2 is Map) {
        final map1 = item1.map((k, v) => MapEntry(k.toString(), v));
        final map2 = item2.map((k, v) => MapEntry(k.toString(), v));
        if (!_areSettingsEqual(map1, map2)) {
          return false;
        }
      } else if (item1 is List && item2 is List) {
        if (!_areListsEqual(item1, item2, '$parentKey[$i]')) {
          return false;
        }
      } else if (item1?.runtimeType != item2?.runtimeType) {
        return false;
      } else if (item1 != item2) {
        return false;
      }
    }
    return true;
  }

  // Helper method to compare DateFilterSetting objects
  bool _areDateFilterSettingsEqual(Map<dynamic, dynamic>? value1, Map<dynamic, dynamic>? value2) {
    // If both are null, they're equal
    if (value1 == null && value2 == null) {
      return true;
    }

    // If one is null and the other isn't, they're not equal
    if (value1 == null || value2 == null) {
      return false;
    }
    final isQuickSelection1 = value1['isQuickSelection'] as bool? ?? false;
    final isQuickSelection2 = value2['isQuickSelection'] as bool? ?? false;
    final isAutoRefreshEnabled1 = value1['isAutoRefreshEnabled'] as bool? ?? false;
    final isAutoRefreshEnabled2 = value2['isAutoRefreshEnabled'] as bool? ?? false;

    // If both are quick selections with auto-refresh enabled,
    // compare only the essential properties, not the dynamic dates
    if (isQuickSelection1 && isQuickSelection2 && isAutoRefreshEnabled1 && isAutoRefreshEnabled2) {
      // For auto-refresh quick selections, only compare the key and refresh state
      return value1['quickSelectionKey'] == value2['quickSelectionKey'] &&
          value1['isQuickSelection'] == value2['isQuickSelection'] &&
          value1['isAutoRefreshEnabled'] == value2['isAutoRefreshEnabled'];
    }

    // For non-auto-refresh or manual selections, do full comparison
    final map1 = value1.map((k, v) => MapEntry(k.toString(), v));
    final map2 = value2.map((k, v) => MapEntry(k.toString(), v));
    return _areSettingsEqual(map1, map2);
  }

  // Helper method to check if settings have non-default values
  bool _hasNonDefaultValues(Map<String, dynamic> settings) {
    for (final entry in settings.entries) {
      final value = entry.value;
      // Check if any value in settings indicates a filter is active
      if (value is List && value.isNotEmpty) {
        return true;
      }
      // Check for true boolean values (indicating active filters)
      else if (value is bool && value) {
        return true;
      }
      // Check for non-null and non-empty string values
      // For the 'search' field, an empty string is considered default (same as null)
      else if (value is String && value.isNotEmpty) {
        return true;
      }
      // Check for nested maps with non-default values
      else if (value is Map && _hasNonDefaultValues(Map<String, dynamic>.from(value))) {
        return true;
      }
    }
    return false;
  }
}
