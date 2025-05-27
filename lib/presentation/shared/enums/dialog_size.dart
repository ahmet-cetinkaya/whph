/// Enum to define different dialog sizes for responsive dialogs.
enum DialogSize {
  /// Minimum dialog size - uses default Dialog behavior
  /// Desktop: Default Dialog sizing (content-based)
  /// Mobile: Default Dialog sizing (content-based)
  /// Perfect for AlertDialogs and confirmation steps - no size constraints applied
  min,

  /// Small dialog size
  /// Desktop: 30% width, 40% height
  /// Mobile: 50% initial height
  small,

  /// Medium dialog size (default)
  /// Desktop: 60% width, 70% height
  /// Mobile: 70% initial height
  medium,

  /// Large dialog size
  /// Desktop: 80% width, 80% height
  /// Mobile: 85% initial height
  large,

  /// Fullscreen dialog size
  /// Desktop: 95% width, 95% height
  /// Mobile: 95% initial height
  max;

  /// Returns the width ratio for desktop dialogs
  double get desktopWidthRatio {
    switch (this) {
      case DialogSize.min:
        return 0; // No width constraint for min size
      case DialogSize.small:
        return 0.5;
      case DialogSize.medium:
        return 0.6;
      case DialogSize.large:
        return 0.8;
      case DialogSize.max:
        return 0.95;
    }
  }

  /// Returns the height ratio for desktop dialogs
  double get desktopHeightRatio {
    switch (this) {
      case DialogSize.min:
        return 0; // No height constraint for min size
      case DialogSize.small:
        return 0.4;
      case DialogSize.medium:
        return 0.7;
      case DialogSize.large:
        return 0.8;
      case DialogSize.max:
        return 0.95;
    }
  }

  /// Returns the initial child size for mobile bottom sheets
  double get mobileInitialSize {
    switch (this) {
      case DialogSize.min:
        return 0; // No initial size for min size
      case DialogSize.small:
        return 0.35;
      case DialogSize.medium:
        return 0.7;
      case DialogSize.large:
        return 0.85;
      case DialogSize.max:
        return 0.95;
    }
  }

  /// Returns the minimum child size for mobile bottom sheets
  double get mobileMinSize {
    switch (this) {
      case DialogSize.min:
        return 0; // No minimum size for min size
      case DialogSize.small:
        return 0.35;
      case DialogSize.medium:
        return 0.4;
      case DialogSize.large:
        return 0.5;
      case DialogSize.max:
        return 0.6;
    }
  }

  /// Returns the maximum child size for mobile bottom sheets
  double get mobileMaxSize {
    switch (this) {
      case DialogSize.min:
        return 0; // No maximum size for min size
      case DialogSize.small:
        return 0.7;
      case DialogSize.medium:
        return 0.85;
      case DialogSize.large:
        return 0.95;
      case DialogSize.max:
        return 0.98;
    }
  }

  /// Returns the maximum width constraint for desktop dialogs
  double get maxDesktopWidth {
    switch (this) {
      case DialogSize.min:
        return double.infinity; // No max width for min size
      case DialogSize.small:
        return 600;
      case DialogSize.medium:
        return 900;
      case DialogSize.large:
        return 1200;
      case DialogSize.max:
        return double.infinity;
    }
  }
}
