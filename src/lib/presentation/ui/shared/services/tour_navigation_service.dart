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
import 'package:whph/presentation/ui/shared/services/abstraction/i_tour_navigation_service.dart';

/// Static bridge for TourNavigationService to support legacy calls and convenience
class TourNavigationService {
  static ITourNavigationService get _instance => container.resolve<ITourNavigationService>();

  static Future<bool> isTourCompletedOrSkipped() => _instance.isTourCompletedOrSkipped();

  static Future<void> startMultiPageTour(BuildContext context, {bool force = false}) =>
      _instance.startMultiPageTour(context, force: force);

  static Future<void> onPageTourCompleted(BuildContext context) => _instance.onPageTourCompleted(context);

  static void navigateBackInTour(BuildContext context) => _instance.navigateBackInTour(context);

  static Future<void> skipMultiPageTour() => _instance.skipMultiPageTour();

  static bool get isMultiPageTourActive => _instance.isMultiPageTourActive;

  static bool get canNavigateBack => _instance.canNavigateBack;

  static int get currentTourIndex => _instance.currentTourIndex;

  static int get totalTourPages => _instance.totalTourPages;
}

/// Implementation of ITourNavigationService for managing multi-page tour navigation
class TourNavigationServiceImpl implements ITourNavigationService {
  final Mediator _mediator;

  TourNavigationServiceImpl(this._mediator);

  static const List<String> _tourPageOrder = [
    TasksPage.route, // 0: Tasks page
    HabitsPage.route, // 1: Habits page
    TodayPage.route, // 2: Today page (time tracking overview)
    TagsPage.route, // 3: Tags page
    AppUsageViewPage.route, // 4: App usage page
    NotesPage.route, // 5: Notes page
  ];

  int _currentTourIndex = 0;
  bool _isMultiPageTourActive = false;

  @override
  Future<bool> isTourCompletedOrSkipped() async {
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

  @override
  Future<void> startMultiPageTour(BuildContext context, {bool force = false}) async {
    final navigator = Navigator.of(context, rootNavigator: true);

    if (!force) {
      final isAlreadyDone = await isTourCompletedOrSkipped();
      if (isAlreadyDone) {
        return;
      }
    }

    _currentTourIndex = 0;
    _isMultiPageTourActive = true;

    void navigate() => _navigateToNextTourPage(navigator);

    if (force) {
      navigate();
    } else {
      // Delay navigation to ensure dialog is fully closed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigate();
      });
    }
  }

  @override
  Future<void> onPageTourCompleted(BuildContext context) async {
    if (!_isMultiPageTourActive) return;

    _currentTourIndex++;
    if (_currentTourIndex < _tourPageOrder.length) {
      final navigator = Navigator.of(context, rootNavigator: true);
      _navigateToNextTourPage(navigator);
    } else {
      // Tour completed for all pages - mark as completed
      _isMultiPageTourActive = false;
      _currentTourIndex = 0;

      // Navigate to Today page after tour completion
      NavigatorState navigator;
      try {
        navigator = Navigator.of(context, rootNavigator: true);
      } catch (e) {
        // Fallback if context is invalid
        return;
      }

      // Mark as completed
      await _markTourCompleted();

      // Navigate to Today page after tour completion
      navigator.pushNamedAndRemoveUntil(
        TodayPage.route,
        (route) => false,
      );

      // Show completion dialog on TodayPage
      if (navigator.mounted) {
        ResponsiveDialogHelper.showResponsiveDialog(
          context: navigator.context,
          child: const TourCompletionDialog(),
          size: DialogSize.min,
        );
      }
    }
  }

  @override
  void navigateBackInTour(BuildContext context) {
    if (!_isMultiPageTourActive || _currentTourIndex <= 0) return;

    _currentTourIndex--;
    final navigator = Navigator.of(context, rootNavigator: true);
    _navigateToCurrentTourPage(navigator);
  }

  @override
  bool get canNavigateBack => _isMultiPageTourActive && _currentTourIndex > 0;

  @override
  Future<void> skipMultiPageTour() async {
    await _markTourSkipped();
    _isMultiPageTourActive = false;
    _currentTourIndex = 0;
  }

  /// Mark the tour as completed in persistent storage
  Future<void> _markTourCompleted() async {
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
  Future<void> _markTourSkipped() async {
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

  @override
  bool get isMultiPageTourActive => _isMultiPageTourActive;

  /// Navigate to the next page in the tour sequence
  void _navigateToNextTourPage(NavigatorState navigator) {
    if (_currentTourIndex >= _tourPageOrder.length) return;

    final nextRoute = _tourPageOrder[_currentTourIndex];

    if (_currentTourIndex == 0) {
      navigator.pushNamedAndRemoveUntil(nextRoute, (route) => false);
    } else {
      navigator.pushReplacementNamed(nextRoute);
    }
  }

  /// Navigate to the current page in the tour sequence
  void _navigateToCurrentTourPage(NavigatorState navigator) {
    if (_currentTourIndex >= _tourPageOrder.length) return;

    final currentRoute = _tourPageOrder[_currentTourIndex];
    navigator.pushReplacementNamed(currentRoute);
  }

  @override
  int get currentTourIndex => _currentTourIndex;

  @override
  int get totalTourPages => _tourPageOrder.length;
}
