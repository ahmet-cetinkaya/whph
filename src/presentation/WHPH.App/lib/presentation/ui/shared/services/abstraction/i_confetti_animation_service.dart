import 'package:flutter/widgets.dart';

/// Service for handling confetti animations throughout the application
abstract class IConfettiAnimationService {
  /// Shows a confetti animation effect
  ///
  /// [context] - The build context where the animation should be displayed
  /// [duration] - Optional duration for the animation (defaults to 3 seconds)
  void showConfettiFromBottomOfScreen(BuildContext context, {Duration? duration});
}
