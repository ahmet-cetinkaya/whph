import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/components/filter_icon_button.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import '../constants/shared_translation_keys.dart';

class SearchFilter extends StatefulWidget {
  final String? initialValue;
  final Function(String?) onSearch;
  final String? placeholder;
  final double iconSize;
  final Color? iconColor;
  final double expandedWidth;
  final bool isDense;

  const SearchFilter({
    super.key,
    this.initialValue,
    required this.onSearch,
    this.placeholder,
    this.iconSize = 20,
    this.iconColor,
    this.expandedWidth = 200,
    this.isDense = false,
  });

  @override
  State<SearchFilter> createState() => _SearchFilterState();
}

class _SearchFilterState extends State<SearchFilter> {
  final TextEditingController _controller = TextEditingController();
  final _translationService = container.resolve<ITranslationService>();
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();

    // Set the initial text with cursor at the end
    final initialText = widget.initialValue ?? '';
    _controller.text = initialText;
    _controller.selection = TextSelection.collapsed(offset: initialText.length);

    // If initial value is provided, expand the search field
    _isExpanded = (widget.initialValue != null && widget.initialValue!.isNotEmpty);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SearchFilter oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update text controller when initialValue changes from parent
    if (widget.initialValue != oldWidget.initialValue && widget.initialValue != _controller.text) {
      // Preserve cursor position when updating text
      final currentSelection = _controller.selection;
      _controller.value = TextEditingValue(
        text: widget.initialValue ?? '',
        selection: currentSelection.isValid && (widget.initialValue?.length ?? 0) >= currentSelection.end
            ? currentSelection
            : TextSelection.collapsed(offset: widget.initialValue?.length ?? 0),
      );
      // Don't trigger onSearch here, as it would cause a loop
    }
  }

  void _toggleSearch() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        // When expanding, if there's an initial value, trigger search
        if (_controller.text.isNotEmpty) {
          widget.onSearch(_controller.text);

          // Set cursor at the end of text for better editing experience
          Future.microtask(() {
            _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
          });
        }
      } else {
        // When collapsing, clear the search
        _controller.clear();
        widget.onSearch(null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isExpanded ? widget.expandedWidth : widget.iconSize * 2,
      child: _isExpanded
          ? SizedBox(
              height: widget.isDense ? AppTheme.size2XLarge : AppTheme.size3XLarge,
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: widget.isDense ? AppTheme.bodyXSmall : null,
                decoration: InputDecoration(
                  isDense: widget.isDense,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppTheme.sizeSmall,
                    vertical: AppTheme.sizeSmall,
                  ),
                  hintText:
                      widget.placeholder ?? _translationService.translate(SharedTranslationKeys.searchPlaceholder),
                  hintStyle: widget.isDense
                      ? AppTheme.bodyXSmall.copyWith(color: AppTheme.secondaryTextColor.withValues(alpha: 0.7))
                      : AppTheme.bodySmall.copyWith(color: AppTheme.secondaryTextColor.withValues(alpha: 0.7)),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: AppTheme.fontSizeSmall,
                    ),
                    onPressed: _toggleSearch,
                    padding: EdgeInsets.zero,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(widget.isDense ? 12 : 20),
                  ),
                  fillColor: AppTheme.surface1,
                ),
                onChanged: (value) {
                  // Always call onSearch with the current value, even if it's empty
                  widget.onSearch(value.isEmpty ? null : value);
                },
                // Prevent text selection on focus
                onTap: () {
                  if (_controller.selection.start == 0 &&
                      _controller.selection.end == _controller.text.length &&
                      _controller.text.isNotEmpty) {
                    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
                  }
                },
              ),
            )
          : FilterIconButton(
              icon: Icons.search,
              iconSize: widget.iconSize,
              color: _controller.text.isNotEmpty ? primaryColor : widget.iconColor,
              tooltip: _translationService.translate(SharedTranslationKeys.searchTooltip),
              onPressed: _toggleSearch,
            ),
    );
  }
}
