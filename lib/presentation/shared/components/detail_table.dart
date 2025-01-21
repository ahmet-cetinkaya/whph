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
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface1,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (AppThemeHelper.isScreenGreaterThan(context, AppTheme.screenLarge)) {
                    return _buildLargeScreenRow(context, data);
                  } else {
                    return _buildSmallScreenLayout(context, data);
                  }
                },
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLargeScreenRow(BuildContext context, DetailTableRowData data) {
    if (forceVertical) {
      return _buildSmallScreenLayout(context, data);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 200,
          child: _buildLabel(context, data),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildContent(context, data),
        ),
      ],
    );
  }

  Widget _buildSmallScreenLayout(BuildContext context, DetailTableRowData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(context, data),
        if (data.hintText != null)
          Padding(
            padding: const EdgeInsets.only(left: 26, top: 4),
            child: Text(
              data.hintText!,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.lightTextColor.withAlpha((255 * 0.5).toInt()),
              ),
            ),
          ),
        const SizedBox(height: 8),
        _buildContent(context, data),
      ],
    );
  }

  Widget _buildLabel(BuildContext context, DetailTableRowData data) {
    return Row(
      children: [
        Icon(
          data.icon,
          size: 18,
          color: AppTheme.lightTextColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              Text(
                data.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.lightTextColor,
                ),
              ),
              if (data.tooltip != null) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: data.tooltip!,
                  child: Icon(
                    Icons.help_outline,
                    size: 14,
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
      child: data.widget,
    );
  }
}
