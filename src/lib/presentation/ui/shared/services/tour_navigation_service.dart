import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/app_usages/pages/app_usage_view_page.dart';
import 'package:whph/presentation/ui/features/calendar/pages/today_page.dart';
import 'package:whph/presentation/ui/features/habits/pages/habits_page.dart';
import 'package:whph/presentation/ui/features/notes/pages/notes_page.dart';
import 'package:whph/presentation/ui/features/tags/pages/tags_page.dart';
import 'package:whph/presentation/ui/features/tasks/pages/tasks_page.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/features/about/components/tour_completion_dialog.dart';

/// Service for managing multi-page tour navigation
class TourNavigationService {
  static const List<String> _tourPageOrder = [
    TasksPage.route, // 0: Tasks page
    HabitsPage.route, // 1: Habits page
    TodayPage.route, // 2: Today page (time tracking overview)
    TagsPage.route, // 3: Tags page
    AppUsageViewPage.route, // 4: App usage page
    NotesPage.route, // 5: Notes page
  ];

  static int _currentTourIndex = 0;
  static bool _isMultiPageTourActive = false;
  static final Mediator _mediator = container.resolve<Mediator>();

  /// Check if the tour has been completed or skipped
  static Future<bool> isTourCompletedOrSkipped() async {
    try {
      final completedSetting = await _mediator.send(
        GetSettingQuery(key: SettingKeys.tourCompleted),
      ) as GetSettingQueryResponse?;
      if (completedSetting?.value == 'true') return true;

      final skippedSetting = await _mediator.send(
        GetSettingQuery(key: SettingKeys.tourSkipped),
      ) as GetSettingQueryResponse?;
      return skippedSetting?.value == 'true';
    } catch (e) {
      return false;
    }
  }

  /// Start the multi-page tour from the beginning
  static Future<void> startMultiPageTour(BuildContext context, {bool force = false}) async {
    if (!force) {
      final isAlreadyDone = await isTourCompletedOrSkipped();
      if (isAlreadyDone) {
        return;
      }
    }

    _currentTourIndex = 0;
    _isMultiPageTourActive = true;
    // Delay navigation to ensure dialog is fully closed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToNextTourPage(context);
    });
  }

  /// Called when a page tour completes to continue to the next page
  static Future<void> onPageTourCompleted(BuildContext context) async {
    if (!_isMultiPageTourActive) return;

    _currentTourIndex++;
    if (_currentTourIndex < _tourPageOrder.length) {
      // Delay navigation to ensure tour dialog is fully closed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToNextTourPage(context);
      });
    } else {
      // Tour completed for all pages - mark as completed
      await _markTourCompleted();
      _isMultiPageTourActive = false;
      _currentTourIndex = 0;

      // Navigate to Today page after tour completion
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          TodayPage.route,
          (route) => false,
        );

        // Show completion dialog on TodayPage
        final context = navigatorKey.currentContext;
        if (context != null) {
          ResponsiveDialogHelper.showResponsiveDialog(
            context: context,
            child: const TourCompletionDialog(),
            size: DialogSize.min,
          );
        }
      });
    }
  }

  /// Navigate back to the previous page in the tour sequence
  static void navigateBackInTour(BuildContext context) {
    if (!_isMultiPageTourActive || _currentTourIndex <= 0) return;

    _currentTourIndex--;
    // Delay navigation to ensure any dialogs are closed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToCurrentTourPage(context);
    });
  }

  /// Check if we can navigate back in the tour
  static bool get canNavigateBack => _isMultiPageTourActive && _currentTourIndex > 0;

  /// Skip the multi-page tour and persist the skip state
  static Future<void> skipMultiPageTour() async {
    await _markTourSkipped();
    _isMultiPageTourActive = false;
    _currentTourIndex = 0;
  }

  /// Mark the tour as completed in persistent storage
  static Future<void> _markTourCompleted() async {
    try {
      await _mediator.send(SaveSettingCommand(
        key: SettingKeys.tourCompleted,
        value: 'true',
        valueType: SettingValueType.bool,
      ));
    } catch (e) {
      // Silently fail to not interrupt user experience
    }
  }

  /// Mark the tour as skipped in persistent storage
  static Future<void> _markTourSkipped() async {
    try {
      await _mediator.send(SaveSettingCommand(
        key: SettingKeys.tourSkipped,
        value: 'true',
        valueType: SettingValueType.bool,
      ));
    } catch (e) {
      // Silently fail to not interrupt user experience
    }
  }

  /// Check if multi-page tour is currently active
  static bool get isMultiPageTourActive => _isMultiPageTourActive;

  /// Navigate to the next page in the tour sequence
  static void _navigateToNextTourPage(BuildContext context) {
    if (_currentTourIndex >= _tourPageOrder.length) return;

    final nextRoute = _tourPageOrder[_currentTourIndex];
    if (_currentTourIndex == 0) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(nextRoute, (route) => false);
    } else {
      navigatorKey.currentState?.pushReplacementNamed(nextRoute);
    }
  }

  /// Navigate to the current page in the tour sequence
  static void _navigateToCurrentTourPage(BuildContext context) {
    if (_currentTourIndex >= _tourPageOrder.length) return;

    final currentRoute = _tourPageOrder[_currentTourIndex];
    navigatorKey.currentState?.pushReplacementNamed(currentRoute);
  }

  /// Get the current tour page index
  static int get currentTourIndex => _currentTourIndex;

  /// Get the total number of tour pages
  static int get totalTourPages => _tourPageOrder.length;
}
