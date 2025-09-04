import 'package:whph/core/application/features/notes/constants/note_translation_keys.dart' as application;

class NoteTranslationKeys extends application.NoteTranslationKeys {
  static const String notesLabel = 'notes.title';
  static const String newNote = 'notes.new_note';
  static const String titlePlaceholder = 'notes.title_placeholder';
  static const String noteDetails = 'notes.note_details';
  static const String noNotes = 'notes.no_notes';
  static const String notes = 'notes.notes';

  // Fields
  static const String titleLabel = 'notes.details.title';
  static const String contentLabel = 'notes.details.content';
  static const String tagsLabel = 'notes.details.tags.label';
  static const String tagsHint = 'notes.details.tags.hint';

  // Actions and buttons
  static const String addNote = 'notes.actions.add';
  static const String editNote = 'notes.actions.edit';
  static const String deleteNote = 'notes.actions.delete';
  static const String saveNote = 'notes.actions.save';

  // Tooltips
  static const String editNameTooltip = 'notes.tooltips.edit_name';
  static const String filterTagsTooltip = 'notes.filters.tooltips.filter_by_tags';

  // Delete confirmation
  static const String confirmDeleteTitle = 'notes.delete.confirm_title';
  static const String confirmDeleteMessage = 'notes.delete.confirm_message';

  // Help
  static const String helpTitle = 'notes.help.title';
  static const String helpContent = 'notes.help.content';

  // Errors
  static const String loadingError = 'notes.errors.loading_details';
  static const String savingError = 'notes.errors.saving_note';
  static const String deletingError = 'notes.errors.deleting';
  static const String loadingTagsError = 'notes.errors.loading_tags';
  static const String addTagError = 'notes.errors.adding_tag';
  static const String removeTagError = 'notes.errors.removing_tag';

  // Filters
  static const String searchPlaceholder = 'notes.filters.search.placeholder';
}
