import 'package:flutter/material.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/shared/utils/app_theme_helper.dart';

class SecondaryAppBar extends AppBar {
  SecondaryAppBar({
    super.key,
    super.actions,
    super.actionsIconTheme,
    super.automaticallyImplyLeading,
    super.backgroundColor,
    super.bottom,
    super.bottomOpacity,
    super.centerTitle,
    super.clipBehavior,
    super.elevation,
    super.excludeHeaderSemantics,
    super.flexibleSpace,
    super.forceMaterialTransparency,
    super.foregroundColor,
    super.iconTheme,
    super.leading,
    super.leadingWidth,
    super.notificationPredicate,
    super.primary,
    super.scrolledUnderElevation,
    super.shadowColor,
    super.surfaceTintColor,
    super.systemOverlayStyle,
    super.title,
    super.titleSpacing,
    super.titleTextStyle,
    super.toolbarHeight,
    super.toolbarOpacity,
    super.toolbarTextStyle,
    required BuildContext context,
  }) : super(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(!AppThemeHelper.isScreenGreaterThan(context, AppTheme.screenMedium)
                  ? AppTheme.containerBorderRadius
                  : 0),
              bottomRight: Radius.circular(AppTheme.containerBorderRadius),
            ),
          ),
        );
}
