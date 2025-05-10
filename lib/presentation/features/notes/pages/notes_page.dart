import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/notes/components/note_add_button.dart';
import 'package:whph/presentation/features/notes/components/note_filters.dart';
import 'package:whph/presentation/features/notes/components/notes_list.dart';
import 'package:whph/presentation/features/notes/constants/note_translation_keys.dart';
import 'package:whph/presentation/features/notes/pages/note_details_page.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';

class NotesPage extends StatefulWidget {
  static const String route = '/notes';

  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with AutomaticKeepAliveClientMixin {
  final _translationService = container.resolve<ITranslationService>();

  List<String>? _selectedTagIds;
  bool _showNoTagsFilter = false;
  String? _searchQuery;

  @override
  bool get wantKeepAlive => true; // Keep the state alive when navigating away

  Future<void> _openDetails(String noteId) async {
    await ResponsiveDialogHelper.showResponsiveDetailsPage(
      context: context,
      title: _translationService.translate(NoteTranslationKeys.noteDetails),
      child: NoteDetailsPage(
        noteId: noteId,
      ),
    );
  }

  /// Handles navigation to note details page after creating a new note
  Future<void> _handleNoteCreated(String noteId) async {
    // Navigate to the note details page using responsive dialog
    if (mounted) {
      await ResponsiveDialogHelper.showResponsiveDetailsPage(
        context: context,
        title: _translationService.translate(NoteTranslationKeys.noteDetails),
        child: NoteDetailsPage(
          noteId: noteId,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ResponsiveScaffoldLayout(
      title: _translationService.translate(NoteTranslationKeys.notesLabel),
      appBarActions: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NoteAddButton(
              mini: true,
              onNoteCreated: _handleNoteCreated,
              buttonColor: AppTheme.primaryColor,
            ),
            HelpMenu(
              titleKey: NoteTranslationKeys.helpTitle,
              markdownContentKey: NoteTranslationKeys.helpContent,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ],
      builder: (context) => Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filters section with consistent padding
              NoteFilters(
                selectedTagIds: _selectedTagIds,
                showNoTagsFilter: _showNoTagsFilter,
                search: _searchQuery,
                onTagFilterChange: (tags, isNoneSelected) {
                  setState(() {
                    _selectedTagIds = tags.isEmpty ? null : tags.map((t) => t.value).toList();
                    _showNoTagsFilter = isNoneSelected;
                  });
                },
                onSearchChange: (query) {
                  setState(() {
                    _searchQuery = query;
                  });
                },
              ),

              // Notes list
              Expanded(
                child: NotesList(
                  filterByTags: _selectedTagIds,
                  filterNoTags: _showNoTagsFilter,
                  search: _searchQuery,
                  onClickNote: _openDetails,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
