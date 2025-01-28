import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/components/filter_icon_button.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import '../constants/shared_translation_keys.dart';

class SearchFilter extends StatefulWidget {
  final String? initialValue;
  final Function(String?) onSearch;
  final String? placeholder;
  final double iconSize;
  final Color? iconColor;
  final double expandedWidth;

  const SearchFilter({
    super.key,
    this.initialValue,
    required this.onSearch,
    this.placeholder,
    this.iconSize = 20,
    this.iconColor,
    this.expandedWidth = 200,
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
    _controller.text = widget.initialValue ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (!_isExpanded) {
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
          ? TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                hintText: widget.placeholder ?? _translationService.translate(SharedTranslationKeys.searchPlaceholder),
                hintStyle: AppTheme.bodySmall.copyWith(color: Colors.white70),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: _toggleSearch,
                  padding: EdgeInsets.zero,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                fillColor: AppTheme.surface1,
              ),
              onChanged: widget.onSearch,
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
