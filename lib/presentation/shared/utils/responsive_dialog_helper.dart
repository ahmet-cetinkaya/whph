import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
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
    bool fullHeight = true,
    double maxWidthRatio = 0.8,
    double maxHeightRatio = 0.8,
    bool isScrollable = true,
    bool isDismissible = true,
    bool enableDrag = true,
  }) async {
    return Navigator.of(context).push<T>(
      PageRouteBuilder<T>(
        opaque: false,
        barrierDismissible: isDismissible,
        pageBuilder: (context, animation, secondaryAnimation) {
          return OrientationBuilder(
            builder: (context, orientation) {
              final screenSize = MediaQuery.of(context).size;
              final isDesktop = AppThemeHelper.isScreenGreaterThan(context, AppTheme.screenMedium);

              if (isDesktop) {
                final dialogHeight = screenSize.height * maxHeightRatio;
                final dialogWidth = screenSize.width * maxWidthRatio;

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Center(
                    child: Dialog(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                        child: SizedBox(
                          width: dialogWidth,
                          height: fullHeight ? dialogHeight : null,
                          child: _wrapWithConstrainedContent(
                            context,
                            child,
                            maxHeight: dialogHeight,
                            maxWidth: dialogWidth < 1200 ? dialogWidth : 1200,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              // Mobile bottom sheet view
              final bottomSheetMaxHeight = screenSize.height * 0.9;
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: DraggableScrollableSheet(
                    initialChildSize: fullHeight ? 0.9 : 0.6,
                    minChildSize: 0.5,
                    maxChildSize: 0.95,
                    expand: false,
                    builder: (context, scrollController) {
                      return Material(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: _wrapWithConstrainedContent(
                                context,
                                child,
                                scrollController: isScrollable ? scrollController : null,
                                isScrollable: isScrollable,
                                maxHeight: bottomSheetMaxHeight,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
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
  }) {
    // Create a bounded container with optional scrolling
    Widget constrainedContent = ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight ?? double.infinity,
        maxWidth: maxWidth ?? double.infinity,
      ),
      child: child,
    );

    // If scrollable, wrap with SingleChildScrollView
    if (isScrollable) {
      constrainedContent = SingleChildScrollView(
        controller: scrollController,
        child: constrainedContent,
      );
    }

    return constrainedContent;
  }
}
