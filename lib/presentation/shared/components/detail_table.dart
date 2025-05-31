import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/utils/app_theme_helper.dart';

class DetailTableRowData {
  final String label;
  final IconData icon;
  final Widget widget;
  final String? tooltip;
  final String? hintText;

  DetailTableRowData({
    required this.label,
    required this.icon,
    required this.widget,
    this.tooltip,
    this.hintText,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rowData.map((data) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.sizeXSmall),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface1,
              borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium, vertical: AppTheme.sizeXSmall),
              // Ensure minimum height for each row
              child: !forceVertical
                  ? SizedBox(
                      // You can adjust the minHeight value as needed
                      // Use a constant or theme value for consistency
                      height: isDense ? AppTheme.size3XLarge : AppTheme.size4XLarge,
                      child: _buildRow(context, data),
                    )
                  : _buildRow(context, data),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRow(BuildContext context, DetailTableRowData data) {
    final isSmallScreen = AppThemeHelper.isSmallScreen(context);
    final labelWidth = isSmallScreen ? 110.0 : 160.0;

    if (forceVertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(context, data),
          if (data.hintText != null)
            Padding(
              padding: const EdgeInsets.only(left: AppTheme.sizeLarge + AppTheme.sizeXSmall, top: AppTheme.sizeXSmall),
              child: Text(
                data.hintText!,
                style: AppTheme.labelSmall.copyWith(
                  color: AppTheme.lightTextColor.withValues(alpha: 0.6),
                ),
              ),
            ),
          const SizedBox(height: AppTheme.sizeXSmall),
          Padding(
            padding: const EdgeInsets.only(left: AppTheme.sizeLarge + AppTheme.sizeXSmall),
            child: _buildContent(context, data),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: labelWidth,
          child: _buildLabel(context, data),
        ),
        const SizedBox(width: AppTheme.sizeSmall),
        Expanded(
          child: _buildContent(context, data),
        ),
      ],
    );
  }

  Widget _buildLabel(BuildContext context, DetailTableRowData data) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          data.icon,
          size: AppTheme.iconSizeSmall,
          color: AppTheme.lightTextColor.withValues(alpha: 0.8),
        ),
        const SizedBox(width: AppTheme.sizeXSmall),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  data.label,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.lightTextColor.withValues(alpha: 0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (data.tooltip != null) ...[
                const SizedBox(width: AppTheme.sizeXSmall),
                Tooltip(
                  message: data.tooltip!,
                  child: Icon(
                    SharedUiConstants.helpIcon,
                    size: AppTheme.iconSizeXSmall,
                    color: AppTheme.lightTextColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, DetailTableRowData data) {
    return Container(
      padding: contentPadding ?? EdgeInsets.zero,
      clipBehavior: Clip.none,
      constraints: const BoxConstraints(minHeight: 28),
      alignment: Alignment.centerLeft,
      child: DefaultTextStyle(
        style: AppTheme.bodyMedium.copyWith(overflow: TextOverflow.ellipsis),
        child: data.widget,
      ),
    );
  }
}
