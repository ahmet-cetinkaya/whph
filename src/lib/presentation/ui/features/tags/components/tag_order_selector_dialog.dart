import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class TagOrderSelectorDialog extends StatefulWidget {
  final List<String> currentOrder;
  final List<TagListItem> tags;
  final ITranslationService translationService;

  const TagOrderSelectorDialog({
    super.key,
    required this.currentOrder,
    required this.tags,
    required this.translationService,
  });

  @override
  State<TagOrderSelectorDialog> createState() => _TagOrderSelectorDialogState();
}

class _TagOrderSelectorDialogState extends State<TagOrderSelectorDialog> {
  late List<TagListItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.tags);
    _sortItems();
  }

  void _sortItems() {
    if (widget.currentOrder.isEmpty) return;

    final orderMap = {for (var i = 0; i < widget.currentOrder.length; i++) widget.currentOrder[i]: i};

    _items.sort((a, b) {
      final indexA = orderMap[a.id];
      final indexB = orderMap[b.id];

      if (indexA != null && indexB != null) {
        return indexA.compareTo(indexB);
      } else if (indexA != null) {
        return -1; // Specific order comes first
      } else if (indexB != null) {
        return 1;
      } else {
        return a.name.compareTo(b.name); // Default to name
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.translationService.translate(SharedTranslationKeys.sortCustomTitle)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(_items.map((e) => e.id).toList());
            },
            child: Text(
              widget.translationService.translate(SharedTranslationKeys.doneButton),
              style: AppTheme.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.sizeMedium),
            child: Text(
              widget.translationService.translate(SharedTranslationKeys.sortCustomDescription),
              style: AppTheme.bodySmall.copyWith(color: AppTheme.secondaryTextColor),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium),
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: _items.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final item = _items.removeAt(oldIndex);
                    _items.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final tag = _items[index];
                  return Card(
                    key: ValueKey(tag.id),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: Icon(
                        TagUiConstants.getTagTypeIcon(tag.type),
                        color: tag.color != null
                            ? Color(int.parse('FF${tag.color}', radix: 16))
                            : AppTheme.secondaryTextColor,
                      ),
                      title: Text(tag.name),
                      trailing: ReorderableDragStartListener(
                        index: index,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.sizeSmall),
                            child: Icon(
                              Icons.drag_handle,
                              size: 20,
                              color: AppTheme.textColor.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
