import 'package:flutter/material.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/src/presentation/ui/shared/utils/app_theme_helper.dart';

class DetailTableRowData {
  final String label;
  final IconData icon;
  final Widget widget;
  final String? tooltip;
  final String? hintText;
  final bool removePadding;

  DetailTableRowData({
    required this.label,
    required this.icon,
    required this.widget,
    this.tooltip,
    this.hintText,
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
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rowData.map((data) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.size3XSmall),
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
            ),
            child: Padding(
              padding: _getContainerPadding(data),
              // Ensure minimum height for each row
              child: !forceVertical
                  ? SizedBox(
                      // You can adjust the minHeight value as needed
                      // Use a constant or theme value for consistency
                      height: isDense ? AppTheme.size3XLarge : AppTheme.size4XLarge,
                      child: _buildRow(context, data, theme),
                    )
                  : _buildRow(context, data, theme),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRow(BuildContext context, DetailTableRowData data, ThemeData theme) {
    final isSmallScreen = AppThemeHelper.isSmallScreen(context);
    final labelWidth = isSmallScreen ? 110.0 : 160.0;

    if (forceVertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık kısmı - normal padding ile
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium),
            child: _buildLabel(context, data, theme),
          ),
          if (data.hintText != null)
            Padding(
              padding: const EdgeInsets.only(
                left: AppTheme.sizeMedium + AppTheme.sizeLarge + AppTheme.size2XSmall, 
                right: AppTheme.sizeMedium,
                top: AppTheme.size2XSmall,
              ),
              child: Text(
                data.hintText!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          const SizedBox(height: AppTheme.size3XSmall),
          // Content kısmı - minimal padding ile
          Padding(
            padding: data.removePadding 
                ? const EdgeInsets.symmetric(horizontal: AppTheme.size2XSmall)
                : const EdgeInsets.only(
                    left: AppTheme.sizeMedium + AppTheme.sizeLarge + AppTheme.size2XSmall,
                    right: AppTheme.sizeMedium,
                  ),
            child: _buildContent(context, data, theme),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: labelWidth,
          child: _buildLabel(context, data, theme),
        ),
        const SizedBox(width: AppTheme.sizeSmall),
        Expanded(
          child: _buildContent(context, data, theme),
        ),
      ],
    );
  }

  Widget _buildLabel(BuildContext context, DetailTableRowData data, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          data.icon,
          size: AppTheme.iconSizeSmall,
          color: theme.colorScheme.onSurface.withOpacity(0.8),
        ),
        const SizedBox(width: AppTheme.size2XSmall),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  data.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (data.tooltip != null) ...[
                const SizedBox(width: AppTheme.size2XSmall),
                Tooltip(
                  message: data.tooltip!,
                  child: Icon(
                    SharedUiConstants.helpIcon,
                    size: AppTheme.iconSizeXSmall,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, DetailTableRowData data, ThemeData theme) {
    return Container(
      padding: contentPadding ?? EdgeInsets.zero,
      clipBehavior: Clip.none,
      constraints: forceVertical ? null : const BoxConstraints(minHeight: 28),
      alignment: forceVertical ? Alignment.topLeft : Alignment.centerLeft,
      child: DefaultTextStyle(
        style: theme.textTheme.bodyMedium?.copyWith(
          overflow: forceVertical ? TextOverflow.visible : TextOverflow.ellipsis,
          color: theme.colorScheme.onSurface,
        ) ?? const TextStyle(),
        child: data.widget,
      ),
    );
  }

  EdgeInsets _getContainerPadding(DetailTableRowData data) {
    if (data.removePadding) {
      // Sadece vertical padding, horizontal padding'i içeride hallederiz
      return const EdgeInsets.symmetric(vertical: AppTheme.size3XSmall);
    }
    return const EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium, vertical: AppTheme.size3XSmall);
  }
}