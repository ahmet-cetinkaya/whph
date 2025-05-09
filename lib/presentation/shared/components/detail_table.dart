import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
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
    this.isDense = true,
    this.contentPadding,
    this.forceVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rowData.map((data) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.sizeMedium),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface1,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium, vertical: AppTheme.sizeSmall),
              child: _buildRow(context, data),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRow(BuildContext context, DetailTableRowData data) {
    final isSmallScreen = AppThemeHelper.isSmallScreen(context);
    final labelWidth = isSmallScreen ? 120.0 : 200.0;

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
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.lightTextColor.withAlpha((255 * 0.5).toInt()),
                ),
              ),
            ),
          const SizedBox(height: AppTheme.sizeSmall),
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
          size: AppTheme.fontSizeLarge,
          color: AppTheme.lightTextColor,
        ),
        const SizedBox(width: AppTheme.sizeSmall),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  data.label,
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.lightTextColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (data.tooltip != null) ...[
                const SizedBox(width: AppTheme.sizeXSmall),
                Tooltip(
                  message: data.tooltip!,
                  child: Icon(
                    Icons.help_outline,
                    size: AppTheme.fontSizeLarge,
                    color: AppTheme.lightTextColor.withAlpha((255 * 0.5).toInt()),
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
      constraints: const BoxConstraints(minHeight: 36),
      alignment: Alignment.centerLeft,
      child: DefaultTextStyle(
        style: const TextStyle(overflow: TextOverflow.ellipsis),
        child: data.widget,
      ),
    );
  }
}
