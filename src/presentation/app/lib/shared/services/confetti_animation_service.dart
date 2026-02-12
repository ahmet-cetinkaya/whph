import 'package:flutter/material.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:whph/shared/services/abstraction/i_confetti_animation_service.dart';

/// Implementation of confetti animation service using flutter_confetti package
class ConfettiAnimationService implements IConfettiAnimationService {
  @override
  void showConfettiFromBottomOfScreen(BuildContext context, {Duration? duration}) {
    try {
      // Launch confetti from bottom center going upward
      Confetti.launch(
        context,
        options: const ConfettiOptions(
          particleCount: 100,
          spread: 90,
          y: 1.0, // Start from bottom
          x: 0.5, // Center horizontally
          angle: 90, // Straight up
          startVelocity: 45,
          colors: [
            Colors.green,
            Colors.lightGreen,
            Colors.yellow,
            Colors.orange,
            Colors.blue,
            Colors.purple,
            Colors.pink,
          ],
        ),
      );
    } catch (e) {
      // Silently handle errors
    }
  }
}
