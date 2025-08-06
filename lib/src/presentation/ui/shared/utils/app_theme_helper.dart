import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';

class AppThemeHelper {
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.sizeOf(context).width < AppTheme.screenMedium;
  }

  static bool isMediumScreen(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= AppTheme.screenMedium && width < AppTheme.screenLarge;
  }

  static bool isLargeScreen(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= AppTheme.screenLarge && width < AppTheme.screenXLarge;
  }

  static bool isXLargeScreen(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= AppTheme.screenXLarge;
  }

  static bool isScreenGreaterThan(BuildContext context, double width) {
    return MediaQuery.sizeOf(context).width > width;
  }

  static bool isScreenSmallerThan(BuildContext context, double width) {
    return MediaQuery.sizeOf(context).width < width;
  }

  static final List<Color> _chartColors = [
    AppTheme.chartColor1,
    AppTheme.chartColor2,
    AppTheme.chartColor3,
    AppTheme.chartColor4,
    AppTheme.chartColor5,
    AppTheme.chartColor6,
    AppTheme.chartColor7,
    AppTheme.chartColor8,
    AppTheme.chartColor9,
    AppTheme.chartColor10
  ];
  static Color getRandomChartColor() {
    return _chartColors[Random().nextInt(_chartColors.length)];
  }
}
