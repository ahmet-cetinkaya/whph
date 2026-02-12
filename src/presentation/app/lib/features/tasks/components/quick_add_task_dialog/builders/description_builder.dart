import 'package:flutter/material.dart';
import 'package:whph/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';

/// Builds the description content for quick add task dialog
class DescriptionBuilder {
  static Widget buildContent({
    required BuildContext context,
    required String description,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
    required VoidCallback onDone,
    bool isBottomSheet = false,
  }) {
    final translationService = container.resolve<ITranslationService>();

    return DescriptionContentInput(
      description: description,
      onChanged: onChanged,
      onClear: onClear,
      onDone: onDone,
      isBottomSheet: isBottomSheet,
      translationService: translationService,
    );
  }

  /// Builds a simple description input field
  static Widget buildSimpleInput({
    required BuildContext context,
    required String description,
    required ValueChanged<String> onChanged,
    VoidCallback? onClear,
    bool showClearButton = true,
    int maxLines = 2,
  }) {
    final translationService = container.resolve<ITranslationService>();

    return SimpleDescriptionInput(
      initialText: description,
      onChanged: onChanged,
      onClear: onClear,
      showClearButton: showClearButton,
      maxLines: maxLines,
      translationService: translationService,
    );
  }
}

/// A stateful widget that properly manages TextEditingController lifecycle
class SimpleDescriptionInput extends StatefulWidget {
  final String initialText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final bool showClearButton;
  final int maxLines;
  final ITranslationService translationService;

  const SimpleDescriptionInput({
    super.key,
    required this.initialText,
    required this.onChanged,
    this.onClear,
    this.showClearButton = true,
    this.maxLines = 2,
    required this.translationService,
  });

  @override
  State<SimpleDescriptionInput> createState() => _SimpleDescriptionInputState();
}

class _SimpleDescriptionInputState extends State<SimpleDescriptionInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      maxLines: widget.maxLines,
      decoration: InputDecoration(
        hintText: widget.translationService.translate(TaskTranslationKeys.addDescriptionHint),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.all(12),
        suffixIcon: widget.showClearButton && _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 16),
                onPressed: widget.onClear,
                tooltip: widget.translationService.translate(SharedTranslationKeys.clearButton),
              )
            : null,
      ),
    );
  }
}

/// A stateful widget that properly manages TextEditingController lifecycle for description content
class DescriptionContentInput extends StatefulWidget {
  final String description;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onDone;
  final bool isBottomSheet;
  final ITranslationService translationService;

  const DescriptionContentInput({
    super.key,
    required this.description,
    required this.onChanged,
    required this.onClear,
    required this.onDone,
    this.isBottomSheet = false,
    required this.translationService,
  });

  @override
  State<DescriptionContentInput> createState() => _DescriptionContentInputState();
}

class _DescriptionContentInputState extends State<DescriptionContentInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.description);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // Description Title with close button
        Row(
          children: [
            Icon(
              Icons.description,
              size: widget.isBottomSheet ? 16 : 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.translationService.translate(TaskTranslationKeys.descriptionLabel),
                style: widget.isBottomSheet
                    ? Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        )
                    : Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: widget.onDone,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Description Input
        TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: widget.translationService.translate(TaskTranslationKeys.addDescriptionHint),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 16),
        // Action Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.onClear,
              child: Text(widget.translationService.translate(SharedTranslationKeys.clearButton)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: widget.onDone,
              child: Text(widget.translationService.translate(SharedTranslationKeys.doneButton)),
            ),
          ],
        ),
      ],
    );
  }
}
