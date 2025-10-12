import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/features/app_usages/pages/app_usage_view_page.dart';
import 'package:whph/presentation/ui/features/calendar/pages/today_page.dart';
import 'package:whph/presentation/ui/features/habits/pages/habits_page.dart';
import 'package:whph/presentation/ui/features/notes/pages/notes_page.dart';
import 'package:whph/presentation/ui/features/tags/pages/tags_page.dart';
import 'package:whph/presentation/ui/features/tasks/pages/tasks_page.dart';

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

  /// Start the multi-page tour from the beginning
  static void startMultiPageTour(BuildContext context) {
    _currentTourIndex = 0;
    _isMultiPageTourActive = true;
    // Delay navigation to ensure dialog is fully closed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToNextTourPage(context);
    });
  }

  /// Called when a page tour completes to continue to the next page
  static void onPageTourCompleted(BuildContext context) {
    if (!_isMultiPageTourActive) return;

    _currentTourIndex++;
    if (_currentTourIndex < _tourPageOrder.length) {
      // Delay navigation to ensure tour dialog is fully closed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToNextTourPage(context);
      });
    } else {
      // Tour completed for all pages - navigate to Today page
      _isMultiPageTourActive = false;
      _currentTourIndex = 0; // Reset for future tours

      // Navigate to Today page after tour completion
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          TodayPage.route,
          (route) => false, // Remove all previous routes
        );
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

  /// Skip the multi-page tour
  static void skipMultiPageTour() {
    _isMultiPageTourActive = false;
    _currentTourIndex = 0;
  }

  /// Check if multi-page tour is currently active
  static bool get isMultiPageTourActive => _isMultiPageTourActive;

  /// Navigate to the next page in the tour sequence
  static void _navigateToNextTourPage(BuildContext context) {
    if (_currentTourIndex >= _tourPageOrder.length) return;

    final nextRoute = _tourPageOrder[_currentTourIndex];
    Navigator.of(context).pushReplacementNamed(nextRoute);
  }

  /// Navigate to the current page in the tour sequence
  static void _navigateToCurrentTourPage(BuildContext context) {
    if (_currentTourIndex >= _tourPageOrder.length) return;

    final currentRoute = _tourPageOrder[_currentTourIndex];
    Navigator.of(context).pushReplacementNamed(currentRoute);
  }

  /// Get the current tour page index
  static int get currentTourIndex => _currentTourIndex;

  /// Get the total number of tour pages
  static int get totalTourPages => _tourPageOrder.length;
}
