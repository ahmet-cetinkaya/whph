import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/enums/dialog_size.dart';
import 'package:whph/presentation/shared/utils/app_theme_helper.dart';

/// A utility class for showing detail pages responsively,
/// as modal dialogs on desktop and bottom sheets on mobile.
class ResponsiveDialogHelper {
  /// Shows a details page responsively.
  /// On desktop, it appears as a modal dialog.
  /// On mobile, it appears as a bottom sheet.
  ///
  /// Returns the result from the dialog/bottom sheet when closed.
  static Future<T?> showResponsiveDialog<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    DialogSize size = DialogSize.medium,
    bool isScrollable = true,
    bool isDismissible = true,
    bool enableDrag = true,
  }) async {
    final isDesktop = AppThemeHelper.isScreenGreaterThan(context, AppTheme.screenMedium);
    final screenSize = MediaQuery.of(context).size;

    if (isDesktop) {
      // Show as modal dialog on desktop
      return showDialog<T>(
        context: context,
        barrierDismissible: isDismissible,
        builder: (BuildContext context) {
          // For minimum size, use default Dialog behavior (content-based sizing)
          if (size == DialogSize.min) {
            return child; // Completely default behavior - no Dialog wrapper, no constraints
          }

          // For other sizes, use ratio-based sizing
          final dialogHeight = screenSize.height * size.desktopHeightRatio;
          final dialogWidth = screenSize.width * size.desktopWidthRatio;
          final maxWidth = size.maxDesktopWidth;

          return Dialog(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
              child: SizedBox(
                child: _wrapWithConstrainedContent(
                  context,
                  child,
                  maxHeight: dialogHeight,
                  maxWidth:
                      maxWidth == double.infinity ? dialogWidth : (dialogWidth < maxWidth ? dialogWidth : maxWidth),
                  isScrollable: isScrollable,
                ),
              ),
            ),
          );
        },
      );
    } else {
      // Show as bottom sheet on mobile
      // For minimum size, use simple modal dialog instead of bottom sheet
      if (size == DialogSize.min) {
        return showDialog<T>(
          context: context,
          barrierDismissible: isDismissible,
          builder: (BuildContext context) {
            return child; // Completely default behavior - no Dialog wrapper, no constraints
          },
        );
      }

      // For other sizes, use bottom sheet
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        isDismissible: isDismissible,
        enableDrag: enableDrag,
        useSafeArea: false, // We'll handle safe area manually
        builder: (BuildContext context) {
          final mediaQuery = MediaQuery.of(context);
          final bottomInset = mediaQuery.viewInsets.bottom;
          final bottomPadding = mediaQuery.padding.bottom;

          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: DraggableScrollableSheet(
              initialChildSize: size.mobileInitialSize,
              minChildSize: size.mobileMinSize,
              maxChildSize: size.mobileMaxSize,
              expand: false,
              builder: (context, scrollController) {
                return Material(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppTheme.containerBorderRadius),
                  ),
                  child: _wrapWithConstrainedContent(
                    context,
                    child,
                    scrollController: scrollController, // Pass controller for identification only
                    isScrollable: isScrollable,
                    bottomPadding: bottomPadding,
                  ),
                );
              },
            ),
          );
        },
      );
    }
  }

  /// Wraps content with appropriate constraints to prevent unbounded height errors
  /// when content contains a Scaffold or similar widget that expects bounded height.
  static Widget _wrapWithConstrainedContent(
    BuildContext context,
    Widget child, {
    ScrollController? scrollController,
    bool isScrollable = true,
    double? maxHeight,
    double? maxWidth,
    double? bottomPadding,
  }) {
    Widget constrainedContent = child;

    // For bottom sheets, we need to ensure the content has bounded height
    // This prevents Scaffold and similar widgets from trying to expand infinitely
    if (scrollController != null) {
      // We're in a DraggableScrollableSheet context
      // Don't use SingleChildScrollView as it conflicts with DraggableScrollableSheet
      // Instead, let the DraggableScrollableSheet handle scrolling and just constrain the content
      return LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = MediaQuery.of(context).size.height;
          final availableHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : screenHeight * 0.9;

          // Use ClipRect to ensure content doesn't overflow and add bottom padding
          return ClipRect(
            child: Container(
              height: availableHeight,
              width: constraints.maxWidth.isFinite ? constraints.maxWidth : null,
              padding: EdgeInsets.only(
                bottom: (bottomPadding ?? MediaQuery.of(context).padding.bottom) + 16,
              ),
              child: child,
            ),
          );
        },
      );
    }

    // For desktop dialogs, use the original constraint-based approach
    if (maxHeight != null || maxWidth != null) {
      constrainedContent = ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight ?? double.infinity,
          maxWidth: maxWidth ?? double.infinity,
        ),
        child: child,
      );
    }

    // If scrollable for desktop dialogs
    if (isScrollable && maxHeight != null) {
      constrainedContent = SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: constrainedContent,
      );
    }

    return constrainedContent;
  }
}
