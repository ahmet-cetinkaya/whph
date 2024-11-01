import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:whph/domain/features/shared/constants/app_theme.dart';

class AppThemeHelper {
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < AppTheme.screenMedium;
  }

  static bool isMediumScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= AppTheme.screenMedium &&
        MediaQuery.of(context).size.width < AppTheme.screenLarge;
  }

  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= AppTheme.screenLarge &&
        MediaQuery.of(context).size.width < AppTheme.screenXLarge;
  }

  static bool isXLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= AppTheme.screenXLarge;
  }

  static bool isScreenGreaterThan(BuildContext context, double width) {
    return MediaQuery.of(context).size.width > width;
  }

  static bool isScreenSmallerThan(BuildContext context, double width) {
    return MediaQuery.of(context).size.width < width;
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
