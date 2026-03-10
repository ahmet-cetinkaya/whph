import 'package:flutter/material.dart';

/// Interface for managing multi-page tour navigation
abstract class ITourNavigationService {
  /// Check if the tour has been completed or skipped
  Future<bool> isTourCompletedOrSkipped();

  /// Start the multi-page tour from the beginning
  Future<void> startMultiPageTour(BuildContext context, {bool force = false});

  /// Called when a page tour completes to continue to the next page
  Future<void> onPageTourCompleted(BuildContext context);

  /// Navigate back to the previous page in the tour sequence
  void navigateBackInTour(BuildContext context);

  /// Skip the multi-page tour and persist the skip state
  Future<void> skipMultiPageTour();

  /// Check if multi-page tour is currently active
  bool get isMultiPageTourActive;

  /// Check if we can navigate back in the tour
  bool get canNavigateBack;

  /// Get the current tour page index
  int get currentTourIndex;

  /// Get the total number of tour pages
  int get totalTourPages;
}
