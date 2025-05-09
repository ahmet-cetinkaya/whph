import 'dart:async';

import 'package:flutter/material.dart';
import 'package:markdown_editor_plus/markdown_editor_plus.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/notes/commands/add_note_tag_command.dart';
import 'package:whph/application/features/notes/commands/remove_note_tag_command.dart';
import 'package:whph/application/features/notes/commands/save_note_command.dart';
import 'package:whph/application/features/notes/queries/get_note_query.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/notes/constants/note_translation_keys.dart';
import 'package:whph/presentation/features/notes/constants/note_ui_constants.dart';
import 'package:whph/presentation/features/notes/services/notes_service.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/shared/components/detail_table.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/shared/components/optional_field_chip.dart';

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
  Timer? _debounce;

  final _translationService = container.resolve<ITranslationService>();

  // Field visibility management
  final Set<String> _visibleOptionalFields = {};

  // Define optional field keys
  static const String keyTags = 'tags';

  @override
  void initState() {
    super.initState();
    _notesService.onNoteUpdated.addListener(_handleNoteUpdated);
    _getInitialData();
  }

  @override
  void dispose() {
    _notesService.onNoteUpdated.removeListener(_handleNoteUpdated);
    _titleController.dispose();
    _contentController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _handleNoteUpdated() {
    if (!mounted || _notesService.onNoteUpdated.value != widget.noteId) return;
    _getNote();
  }

  Future<void> _getNote() async {
    try {
      final query = GetNoteQuery(id: widget.noteId);
      final response = await _mediator.send<GetNoteQuery, GetNoteQueryResponse>(query);

      if (mounted) {
        // Store current selections before updating
        final titleSelection = _titleController.selection;
        final contentSelection = _contentController.selection;

        setState(() {
          _note = response;

          // Update title if it's different
          if (_titleController.text != response.title) {
            _titleController.text = response.title;
          } else if (titleSelection.isValid) {
            // Restore selection if title didn't change
            _titleController.selection = titleSelection;
          }

          // Update content if it's different
          final content = response.content ?? '';
          if (_contentController.text != content) {
            _contentController.text = content;
          } else if (contentSelection.isValid) {
            // Restore selection if content didn't change
            _contentController.selection = contentSelection;
          }
        });

        // Process field visibility after loading note
        _processFieldVisibility();
      }
    } on BusinessException catch (e) {
      if (mounted) ErrorHelper.showError(context, e);
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(NoteTranslationKeys.loadingError),
        );
      }
    }
  }

  // Process field content and update UI after note data is loaded
  void _processFieldVisibility() {
    if (_note == null) return;

    setState(() {
      // Make fields with content automatically visible
      if (_hasFieldContent(keyTags)) _visibleOptionalFields.add(keyTags);
    });
  }

  // Check if the field should be displayed in the chips section
  bool _shouldShowAsChip(String fieldKey) {
    // Don't show chip if field is already visible OR if it has content
    return !_visibleOptionalFields.contains(fieldKey) && !_hasFieldContent(fieldKey);
  }

  // Method to determine if a field has content
  bool _hasFieldContent(String fieldKey) {
    if (_note == null) return false;

    switch (fieldKey) {
      case keyTags:
        return _note!.tags.isNotEmpty;
      default:
        return false;
    }
  }

  // Remove unused _addTag and _removeTag methods since we have _addTagToNote and _removeTagFromNote

  void _onTagsSelected(List<DropdownOption<String>> tagOptions) {
    if (_note == null) return;

    final tagsToAdd = tagOptions
        .where((tagOption) => !_note!.tags.any((noteTag) => noteTag.tagId == tagOption.value))
        .map((option) => option.value)
        .toList();

    final tagsToRemove =
        _note!.tags.where((noteTag) => !tagOptions.map((tag) => tag.value).contains(noteTag.tagId)).toList();

    // Batch process all tag operations
    Future<void> processTags() async {
      // Add all tags
      for (final tagId in tagsToAdd) {
        await _addTagToNote(tagId);
      }

      // Remove all tags
      for (final noteTag in tagsToRemove) {
        await _removeTagFromNote(noteTag.id);
      }

      // Notify only once after all tag operations are complete
      if (tagsToAdd.isNotEmpty || tagsToRemove.isNotEmpty) {
        _notesService.notifyNoteUpdated(widget.noteId);
      }
    }

    // Execute the tag operations
    processTags();
  }

  Future<void> _saveNote() async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final command = SaveNoteCommand(
          id: widget.noteId,
          title: _titleController.text,
          content: _contentController.text,
        );

        await _mediator.send(command);

        // Notify the app that a note was updated
        _notesService.notifyNoteUpdated(widget.noteId);

        if (widget.onNoteUpdated != null) {
          widget.onNoteUpdated!();
        }
      } on BusinessException catch (e) {
        if (mounted) ErrorHelper.showError(context, e);
      } catch (e, stackTrace) {
        if (mounted) {
          ErrorHelper.showUnexpectedError(
            context,
            e as Exception,
            stackTrace,
            message: _translationService.translate(NoteTranslationKeys.savingError),
          );
        }
      }
    });
  }

  // Add tag operations helper methods
  Future<bool> _addTagToNote(String tagId) async {
    try {
      final command = AddNoteTagCommand(noteId: widget.noteId, tagId: tagId);
      await _mediator.send(command);
      await _getNote();
      return true;
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(NoteTranslationKeys.addTagError),
        );
      }
      return false;
    }
  }

  Future<bool> _removeTagFromNote(String id) async {
    try {
      final command = RemoveNoteTagCommand(id: id);
      await _mediator.send(command);
      await _getNote();
      return true;
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(NoteTranslationKeys.removeTagError),
        );
      }
      return false;
    }
  }

  // Helper method to check if a field should be displayed as a chip
  bool _isFieldVisible(String fieldKey) {
    return _visibleOptionalFields.contains(fieldKey);
  }

  // Build a chip for toggling optional fields
  Widget _buildOptionalFieldChip(String fieldKey, bool selected) {
    return OptionalFieldChip(
      label: _getFieldLabel(fieldKey),
      icon: _getFieldIcon(fieldKey),
      selected: _isFieldVisible(fieldKey),
      onSelected: (_) => setState(() {
        if (_visibleOptionalFields.contains(fieldKey)) {
          _visibleOptionalFields.remove(fieldKey);
        } else {
          _visibleOptionalFields.add(fieldKey);
        }
      }),
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
        return NoteUiConstants.tagsIcon;
      default:
        return Icons.label;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_note == null) return const SizedBox.shrink();

    final availableChipFields = [keyTags].where(_shouldShowAsChip).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Note Title (always visible)
          TextFormField(
            controller: _titleController,
            maxLines: null,
            onChanged: (value) {
              _saveNote();
              widget.onTitleUpdated?.call(value);
            },
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffixIcon: Tooltip(
                message: _translationService.translate(NoteTranslationKeys.editNameTooltip),
                child: const Icon(Icons.edit, size: AppTheme.iconSizeSmall),
              ),
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppTheme.sizeSmall),

          // Optional fields (Tags)
          if (_isFieldVisible(keyTags)) DetailTable(rowData: [_buildTagsSection()]),

          // Optional field chips at the bottom
          if (availableChipFields.isNotEmpty) ...[
            const SizedBox(height: AppTheme.sizeSmall),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableChipFields.map((fieldKey) => _buildOptionalFieldChip(fieldKey, false)).toList(),
            ),
            const SizedBox(height: AppTheme.sizeSmall),
          ],

          // Divider
          const Divider(thickness: 1, color: AppTheme.dividerColor),

          // Note Content (always visible)
          const SizedBox(height: AppTheme.sizeSmall),
          MarkdownAutoPreview(
            controller: _contentController,
            onChanged: (_) => _saveNote(),
            hintText: SharedUiConstants.markdownEditorHint,
            toolbarBackground: AppTheme.surface1,
            style: AppTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Future<void> _getInitialData() async {
    await _getNote();
  }

  DetailTableRowData _buildTagsSection() => DetailTableRowData(
        label: _translationService.translate(NoteTranslationKeys.tagsLabel),
        icon: NoteUiConstants.tagsIcon,
        hintText: _translationService.translate(NoteTranslationKeys.tagsHint),
        widget: _note != null
            ? TagSelectDropdown(
                key: ValueKey(_note!.tags.length),
                isMultiSelect: true,
                onTagsSelected: (List<DropdownOption<String>> tagOptions, bool _) => _onTagsSelected(tagOptions),
                showSelectedInDropdown: true,
                initialSelectedTags:
                    _note!.tags.map((tag) => DropdownOption<String>(value: tag.tagId, label: tag.tagName)).toList(),
                icon: SharedUiConstants.addIcon,
              )
            : Container(),
      );
}
