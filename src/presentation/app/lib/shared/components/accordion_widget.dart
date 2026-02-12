import 'package:flutter/material.dart';
import 'package:whph/shared/constants/app_theme.dart';

/// A reusable accordion widget that can expand/collapse content
class AccordionWidget extends StatefulWidget {
  /// The title displayed in the accordion header
  final String title;

  /// Optional hint text shown on the right side of the header
  final String? hintText;

  /// The content to show when expanded
  final Widget content;

  /// Whether the accordion is initially expanded
  final bool initiallyExpanded;

  /// Callback when the expansion state changes
  final ValueChanged<bool>? onExpansionChanged;

  /// Custom padding for the header
  final EdgeInsetsGeometry? headerPadding;

  /// Custom padding for the content
  final EdgeInsetsGeometry? contentPadding;

  /// Custom margin for the entire accordion
  final EdgeInsetsGeometry? margin;

  const AccordionWidget({
    super.key,
    required this.title,
    this.hintText,
    required this.content,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    this.headerPadding,
    this.contentPadding,
    this.margin,
  });

  @override
  State<AccordionWidget> createState() => _AccordionWidgetState();
}

class _AccordionWidgetState extends State<AccordionWidget> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(AccordionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initiallyExpanded != widget.initiallyExpanded) {
      _isExpanded = widget.initiallyExpanded;
    }
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    widget.onExpansionChanged?.call(_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: widget.margin ?? EdgeInsets.zero,
      child: Column(
        children: [
          // Toggle button
          InkWell(
            onTap: _toggleExpansion,
            child: Padding(
              padding: widget.headerPadding ?? const EdgeInsets.all(AppTheme.sizeMedium),
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: AppTheme.iconSizeMedium,
                  ),
                  const SizedBox(width: AppTheme.sizeSmall),
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const Spacer(),
                  if (widget.hintText != null)
                    Text(
                      widget.hintText!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
          ),

          // Expandable content
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: widget.contentPadding ?? const EdgeInsets.all(AppTheme.sizeMedium),
              child: widget.content,
            ),
          ],
        ],
      ),
    );
  }
}
