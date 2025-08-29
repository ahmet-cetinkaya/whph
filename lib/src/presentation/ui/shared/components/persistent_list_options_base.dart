import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/shared/services/filter_settings_manager.dart';

/// Base class for list option widgets that need to save filter settings
abstract class PersistentListOptionsBase extends StatefulWidget {
  /// Whether to show the save button
  final bool showSaveButton;

  /// Whether current filter settings differ from saved/default settings
  final bool hasUnsavedChanges;

  /// Key for storing settings in persistent storage
  final String? settingKeyVariantSuffix;

  /// Callback when settings are loaded
  final VoidCallback? onSettingsLoaded;

  /// Callback when filter/sort settings are saved
  final Function()? onSaveSettings;

  const PersistentListOptionsBase({
    super.key,
    this.showSaveButton = true,
    this.hasUnsavedChanges = false,
    this.settingKeyVariantSuffix,
    this.onSettingsLoaded,
    this.onSaveSettings,
  });
}

/// Base state class for persistent list option widgets
abstract class PersistentListOptionsBaseState<T extends PersistentListOptionsBase> extends State<T> {
  /// Filter settings manager instance
  late final FilterSettingsManager filterSettingsManager;

  /// Flag indicating if settings have been loaded
  bool isSettingLoaded = false;

  /// Flag indicating if settings are currently being loaded
  bool isLoadingSettings = false;

  /// Timer for debouncing search input
  Timer? searchDebounce;

  /// Timer for showing saved message
  Timer? savedMessageTimer;

  /// Timer for checking search state
  Timer? searchStateCheckTimer;

  /// Flag indicating if there are unsaved changes
  bool hasUnsavedChanges = false;

  /// Flag indicating if saved message should be shown
  bool showSavedMessage = false;

  /// Last search query
  String? lastSearchQuery;

  /// Key used for storing settings
  late final String settingKey;

  /// Mediator instance for filter settings manager
  final _mediator = container.resolve<Mediator>();

  @override
  void initState() {
    super.initState();
    filterSettingsManager = FilterSettingsManager(_mediator);

    initSettingKey();
    loadSavedListOptionSettings();
  }

  @override
  void dispose() {
    searchDebounce?.cancel();
    savedMessageTimer?.cancel();
    searchStateCheckTimer?.cancel();
    super.dispose();
  }

  /// Initialize setting key based on the base key and suffix
  void initSettingKey();

  /// Load saved filter settings from persistent storage
  Future<void> loadSavedListOptionSettings();

  /// Save current filter settings to persistent storage
  Future<void> saveFilterSettings();

  /// Check if current filter settings differ from saved settings
  Future<void> checkForUnsavedChanges();

  /// Handle when filter changes
  void handleFilterChange() {
    checkForUnsavedChanges();
  }

  /// Show saved message for a period of time
  void showSavedMessageTemporarily() {
    if (!mounted) return;

    setState(() {
      showSavedMessage = true;
    });

    // Auto-hide the saved message after 2 seconds
    savedMessageTimer?.cancel();
    savedMessageTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          showSavedMessage = false;
        });
      }
    });
  }
}
