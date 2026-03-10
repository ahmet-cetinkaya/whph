import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/providers/drag_state_provider.dart';

extension TooltipWidgetExtension on Widget {
  Widget wrapWithTooltip({required bool enabled, required String message}) {
    if (!enabled) return this;
    return Builder(
      builder: (context) {
        // Check if dragging is happening globally
        final isDragging = DragStateProvider.isDragging(context);
        if (isDragging) return this;

        try {
          return Tooltip(message: message, child: this);
        } catch (e) {
          // If there's any error during tooltip rendering, just return the original widget
          return this;
        }
      },
    );
  }
}
