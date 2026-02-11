import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';

class DetailTableRowData {
  final String label;
  final IconData icon;
  final Widget widget;
  final String? tooltip;
  final bool removePadding;

  DetailTableRowData({
    required this.label,
    required this.icon,
    required this.widget,
    this.tooltip,
    this.removePadding = false,
  });
}

class DetailTable extends StatelessWidget {
  final List<DetailTableRowData> rowData;
  final bool isDense;
  final EdgeInsets? contentPadding;
  final bool forceVertical;

  const DetailTable({
    super.key,
    required this.rowData,
    this.isDense = false,
    this.contentPadding,
    this.forceVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final useVertical = forceVertical || AppThemeHelper.isVerySmallScreen(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rowData.map((data) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.size4XSmall),
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
            ),
            child: Padding(
              padding: _getContainerPadding(data),
              child: !useVertical
                  ? SizedBox(
                      height: AppTheme.size4XLarge,
                      child: _buildRow(context, data, theme, useVertical),
                    )
                  : _buildRow(context, data, theme, useVertical),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRow(BuildContext context, DetailTableRowData data, ThemeData theme, bool useVertical) {
    if (useVertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.sizeSmall, left: AppTheme.sizeSmall),
            child: _buildLabel(context, data, theme),
          ),
          Padding(
            padding: data.removePadding
                ? const EdgeInsets.symmetric(horizontal: AppTheme.size2XSmall)
                : const EdgeInsets.only(
                    left: AppTheme.sizeSmall,
                    right: AppTheme.sizeSmall,
                  ),
            child: _buildContent(context, data, theme, useVertical),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: _buildLabel(context, data, theme),
        ),
        const SizedBox(width: AppTheme.sizeSmall),
        Expanded(
          flex: 7,
          child: _buildContent(context, data, theme, useVertical),
        ),
      ],
    );
  }

  Widget _buildLabel(BuildContext context, DetailTableRowData data, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StyledIcon(
          data.icon,
          isActive: true,
          size: AppTheme.iconSizeSmall,
        ),
        const SizedBox(width: AppTheme.sizeSmall),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Tooltip(
                  message: data.label,
                  triggerMode: TooltipTriggerMode.tap,
                  child: Text(
                    data.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.normal,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (data.tooltip != null) ...[
                const SizedBox(width: AppTheme.size2XSmall),
                Tooltip(
                  message: data.tooltip!,
                  child: Icon(
                    SharedUiConstants.helpIcon,
                    size: AppTheme.iconSizeXSmall,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, DetailTableRowData data, ThemeData theme, bool useVertical) {
    return Container(
      padding: contentPadding ?? EdgeInsets.zero,
      clipBehavior: Clip.none,
      constraints: useVertical ? null : const BoxConstraints(minHeight: 28),
      alignment: useVertical ? Alignment.topLeft : Alignment.centerLeft,
      child: DefaultTextStyle(
        style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.normal,
              overflow: useVertical ? TextOverflow.visible : TextOverflow.ellipsis,
              color: theme.colorScheme.onSurface,
            ) ??
            const TextStyle(),
        child: Align(
          alignment: useVertical ? Alignment.topLeft : Alignment.centerLeft,
          child: data.widget,
        ),
      ),
    );
  }

  EdgeInsets _getContainerPadding(DetailTableRowData data) {
    if (data.removePadding) {
      return const EdgeInsets.symmetric(vertical: AppTheme.size2XSmall);
    }
    return const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall, vertical: AppTheme.size2XSmall);
  }
}
