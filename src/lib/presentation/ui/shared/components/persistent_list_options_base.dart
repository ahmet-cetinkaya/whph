import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/services/filter_settings_manager.dart';

abstract class PersistentListOptionsBase extends StatefulWidget {
  final bool showSaveButton;
  final bool hasUnsavedChanges;
  final String? settingKeyVariantSuffix;
  final VoidCallback? onSettingsLoaded;
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

abstract class PersistentListOptionsBaseState<T extends PersistentListOptionsBase> extends State<T> {
  late final FilterSettingsManager filterSettingsManager;
  bool isSettingLoaded = false;
  bool isLoadingSettings = false;
  Timer? searchDebounce;
  Timer? savedMessageTimer;
  Timer? searchStateCheckTimer;
  bool hasUnsavedChanges = false;
  bool showSavedMessage = false;
  String? lastSearchQuery;
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
