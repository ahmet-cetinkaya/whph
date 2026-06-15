import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart' show MarkdownEditor;
import 'package:whph/core/application/features/notes/commands/add_note_tag_command.dart';
import 'package:whph/core/application/features/notes/commands/remove_note_tag_command.dart';
import 'package:whph/core/application/features/notes/commands/save_note_command.dart';
import 'package:whph/core/application/features/notes/commands/update_note_tags_order_command.dart';
import 'package:whph/core/application/features/notes/queries/get_note_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/notes/constants/note_translation_keys.dart';
import 'package:whph/presentation/ui/features/notes/services/notes_service.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/ui/shared/components/detail_table.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/components/optional_field_chip.dart';

class NoteDetailsContent extends StatefulWidget {
  final String noteId;
  final VoidCallback? onNoteUpdated;
  final Function(String)? onTitleUpdated;

  const NoteDetailsContent({
    super.key,
    required this.noteId,
    this.onNoteUpdated,
    this.onTitleUpdated,
  });

  @override
  State<NoteDetailsContent> createState() => _NoteDetailsContentState();
}

class _NoteDetailsContentState extends State<NoteDetailsContent> {
  final _mediator = container.resolve<Mediator>();
  final _notesService = container.resolve<NotesService>();

  GetNoteQueryResponse? _note;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();
  Timer? _debounce;

  // Track active input fields to prevent text selection conflicts
  bool _isTitleFieldActive = false;
  bool _isContentFieldActive = false;

  final _translationService = container.resolve<ITranslationService>();

  final Set<String> _visibleOptionalFields = {};
  String? _autoOpenField; // Track which field should auto-open its dialog

  static const String keyTags = 'tags';

  @override
  void initState() {
    super.initState();
    _notesService.onNoteUpdated.addListener(_handleNoteUpdated);

    _titleFocusNode.addListener(_handleTitleFocusChange);
    _contentFocusNode.addListener(_handleContentFocusChange);

    _getInitialData();
  }

  @override
  void dispose() {
    _notesService.onNoteUpdated.removeListener(_handleNoteUpdated);
    _titleFocusNode.removeListener(_handleTitleFocusChange);
    _contentFocusNode.removeListener(_handleContentFocusChange);

    if (widget.onTitleUpdated != null && _titleController.text.isNotEmpty) {
      widget.onTitleUpdated!(_titleController.text);
    }

    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _handleNoteUpdated() {
    if (!mounted || _notesService.onNoteUpdated.value != widget.noteId) return;

    if (_isTitleFieldActive || _isContentFieldActive) return;

    _getNote();
  }

  void _handleTitleFocusChange() {
    if (!mounted) return;
    setState(() {
      _isTitleFieldActive = _titleFocusNode.hasFocus;
    });
  }

  void _handleContentFocusChange() {
    if (!mounted) return;
    setState(() {
      _isContentFieldActive = _contentFocusNode.hasFocus;
    });
  }

  Future<void> _getNote() async {
    await AsyncErrorHandler.execute(
      context: context,
      errorMessage: _translationService.translate(NoteTranslationKeys.loadingError),
      operation: () async {
        final query = GetNoteQuery(id: widget.noteId);
        return await _mediator.send<GetNoteQuery, GetNoteQueryResponse>(query);
      },
      onSuccess: (response) {
        if (_isTitleFieldActive || _isContentFieldActive) return;

        setState(() {
          final bool isTitleDirty = _titleController.text != (_note?.title ?? '');
          final bool isContentDirty = _contentController.text != (_note?.content ?? '');

          _note = response;

          if (!isTitleDirty && _titleController.text != response.title) {
            _titleController.text = response.title;
          }

          if (response.title.isEmpty) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _titleFocusNode.requestFocus();
              }
            });
          }

          final content = response.content ?? '';
          if (!isContentDirty && _contentController.text != content) {
            _contentController.text = content;
          }
        });

        _processFieldVisibility();
      },
    );
  }

  void _processFieldVisibility() {
    if (_note == null) return;

    setState(() {
      if (_hasFieldContent(keyTags)) _visibleOptionalFields.add(keyTags);
    });
  }

  bool _shouldShowAsChip(String fieldKey) {
    return !_visibleOptionalFields.contains(fieldKey) && !_hasFieldContent(fieldKey);
  }

  bool _hasFieldContent(String fieldKey) {
    if (_note == null) return false;

    switch (fieldKey) {
      case keyTags:
        return _note!.tags.isNotEmpty;
      default:
        return false;
    }
  }

  void _onTagsSelected(List<DropdownOption<String>> tagOptions) {
    if (_note == null) return;

    final tagsToAdd = tagOptions
        .where((tagOption) => !_note!.tags.any((noteTag) => noteTag.tagId == tagOption.value))
        .map((option) => option.value)
        .toList();

    final tagsToRemove =
        _note!.tags.where((noteTag) => !tagOptions.map((tag) => tag.value).contains(noteTag.tagId)).toList();

    Future<void> processTags() async {
      for (final tagId in tagsToAdd) {
        await _addTagToNote(tagId);
      }

      for (final noteTag in tagsToRemove) {
        await _removeTagFromNote(noteTag.id);
      }

      if (tagOptions.isNotEmpty) {
        final tagOrders = {for (int i = 0; i < tagOptions.length; i++) tagOptions[i].value: i};
        final orderCommand = UpdateNoteTagsOrderCommand(noteId: widget.noteId, tagOrders: tagOrders);
        await _mediator.send(orderCommand);
      }

      if (tagsToAdd.isNotEmpty || tagsToRemove.isNotEmpty || tagOptions.isNotEmpty) {
        await _getNote();
        _notesService.notifyNoteUpdated(widget.noteId);
      }
    }

    processTags();
  }

  void _forceImmediateUpdate() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
  }

  SaveNoteCommand _buildSaveCommand() {
    return SaveNoteCommand(
      id: widget.noteId,
      title: _titleController.text,
      content: _contentController.text,
    );
  }

  Future<void> _executeSaveCommand() async {
    await _mediator.send(_buildSaveCommand());
  }

  void _handleFieldChange<T>(T value, VoidCallback? onUpdate) {
    _forceImmediateUpdate();
    _saveNote();
    onUpdate?.call();
  }

  void _onTitleChanged(String value) {
    _isTitleFieldActive = true;
    _handleFieldChange(value, () => widget.onTitleUpdated?.call(value));
  }

  void _onContentChanged(String value) {
    _isContentFieldActive = true;
    _handleFieldChange<String>(value, null);
  }

  Future<void> _saveNote() async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(SharedUiConstants.contentSaveDebounceTime, () async {
      if (!mounted) return;

      await AsyncErrorHandler.executeVoid(
        context: context,
        errorMessage: _translationService.translate(NoteTranslationKeys.savingError),
        operation: _executeSaveCommand,
        onSuccess: () {
          _notesService.notifyNoteUpdated(widget.noteId);

          if (widget.onNoteUpdated != null) {
            widget.onNoteUpdated!();
          }
        },
      );
    });
  }

  Future<bool> _addTagToNote(String tagId) async {
    final result = await AsyncErrorHandler.execute<AddNoteTagCommandResponse>(
      context: context,
      errorMessage: _translationService.translate(NoteTranslationKeys.addTagError),
      operation: () async {
        final command = AddNoteTagCommand(noteId: widget.noteId, tagId: tagId);
        return await _mediator.send(command);
      },
      onSuccess: (_) async {
        await _getNote();
      },
    );

    return result != null;
  }

  Future<bool> _removeTagFromNote(String id) async {
    final result = await AsyncErrorHandler.execute<RemoveNoteTagCommandResponse>(
      context: context,
      errorMessage: _translationService.translate(NoteTranslationKeys.removeTagError),
      operation: () async {
        final command = RemoveNoteTagCommand(id: id);
        return await _mediator.send(command);
      },
      onSuccess: (_) async {
        await _getNote();
      },
    );

    return result != null;
  }

  bool _isFieldVisible(String fieldKey) {
    return _visibleOptionalFields.contains(fieldKey);
  }

  Widget _buildOptionalFieldChip(String fieldKey, bool selected) {
    return OptionalFieldChip(
      label: _getFieldLabel(fieldKey),
      icon: _getFieldIcon(fieldKey),
      selected: _isFieldVisible(fieldKey),
      onSelected: (_) {
        if (!_visibleOptionalFields.contains(fieldKey)) {
          setState(() {
            _autoOpenField = fieldKey;
          });
        }
        setState(() {
          if (_visibleOptionalFields.contains(fieldKey)) {
            _visibleOptionalFields.remove(fieldKey);
          } else {
            _visibleOptionalFields.add(fieldKey);
          }
        });
      },
      backgroundColor: selected ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1) : null,
    );
  }

  String _getFieldLabel(String fieldKey) {
    switch (fieldKey) {
      case keyTags:
        return _translationService.translate(NoteTranslationKeys.tagsLabel);
      default:
        return fieldKey;
    }
  }

  IconData _getFieldIcon(String fieldKey) {
    switch (fieldKey) {
      case keyTags:
        return TagUiConstants.tagIcon;
      default:
        return Icons.question_mark; // Default icon for unknown fields
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_note == null) return const SizedBox.shrink();

    final availableChipFields = [keyTags].where(_shouldShowAsChip).toList();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _titleController,
          focusNode: _titleFocusNode,
          maxLines: null,
          onChanged: _onTitleChanged,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            hintText: _translationService.translate(NoteTranslationKeys.titlePlaceholder),
          ),
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: AppTheme.size2XSmall),
        if (_isFieldVisible(keyTags)) ...[
          DetailTable(
            rowData: [_buildTagsSection()],
            isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
          ),
          const SizedBox(height: AppTheme.size2XSmall),
        ],
        if (availableChipFields.isNotEmpty) ...[
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: availableChipFields.map((fieldKey) => _buildOptionalFieldChip(fieldKey, false)).toList(),
          ),
          const SizedBox(height: AppTheme.size2XSmall),
        ],
        Expanded(
          child: MarkdownEditor.simple(
            controller: _contentController,
            focusNode: _contentFocusNode,
            onChanged: _onContentChanged,
            style: theme.textTheme.bodyMedium,
            initialPreviewMode: _contentController.text.trim().isNotEmpty,
            hintText: _translationService.translate(SharedTranslationKeys.markdownEditorHint),
            translations: SharedTranslationKeys.mapMarkdownTranslations(_translationService),
          ),
        ),
      ],
    );
  }

  Future<void> _getInitialData() async {
    await _getNote();
  }

  DetailTableRowData _buildTagsSection() => DetailTableRowData(
        label: _translationService.translate(NoteTranslationKeys.tagsLabel),
        icon: TagUiConstants.tagIcon,
        widget: _note != null
            ? TagSelectDropdown(
                key: ValueKey(_note!.tags.map((t) => '${t.tagId}_${t.tagOrder}').join(',')),
                isMultiSelect: true,
                onTagsSelected: (List<DropdownOption<String>> tagOptions, bool _) => _onTagsSelected(tagOptions),
                autoOpen: _autoOpenField == keyTags,
                showSelectedInDropdown: true,
                initialSelectedTags: _note!.tags
                    .map((tag) => DropdownOption<String>(
                        value: tag.tagId,
                        label: tag.tagName.isNotEmpty
                            ? tag.tagName
                            : _translationService.translate(SharedTranslationKeys.untitled)))
                    .toList(),
                icon: SharedUiConstants.addIcon,
                iconSize: AppTheme.iconSizeMedium,
              )
            : Container(),
      );
}
