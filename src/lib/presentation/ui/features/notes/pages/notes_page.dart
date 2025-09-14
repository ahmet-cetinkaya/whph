import 'package:flutter/material.dart';
import 'package:whph/core/application/features/notes/queries/get_list_notes_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/notes/components/note_add_button.dart';
import 'package:whph/presentation/ui/features/notes/components/note_list_options.dart';
import 'package:whph/presentation/ui/features/notes/components/notes_list.dart';
import 'package:whph/presentation/ui/features/notes/constants/note_translation_keys.dart';
import 'package:whph/presentation/ui/features/notes/pages/note_details_page.dart';
import 'package:whph/presentation/ui/shared/components/kebab_menu.dart';
import 'package:whph/presentation/ui/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/utils/responsive_dialog_helper.dart';

class NotesPage extends StatefulWidget {
  static const String route = '/notes';

  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with AutomaticKeepAliveClientMixin {
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();

  bool _isListVisible = false;
  List<String>? _selectedTagIds;
  bool _showNoTagsFilter = false;
  String? _searchQuery;
  SortConfig<NoteSortFields>? _sortConfig;

  @override
  bool get wantKeepAlive => true; // Keep the state alive when navigating away

  Future<void> _openDetails(String noteId) async {
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: NoteDetailsPage(
        noteId: noteId,
      ),
      size: DialogSize.large,
    );
  }

  /// Handles navigation to note details page after creating a new note
  Future<void> _handleNoteCreated(String noteId) async {
    // Navigate to the note details page using responsive dialog
    if (mounted) {
      await ResponsiveDialogHelper.showResponsiveDialog(
        context: context,
        child: NoteDetailsPage(
          noteId: noteId,
        ),
        size: DialogSize.large,
      );
    }
  }

  /// Callback when settings are loaded from storage
  void _handleSettingsLoaded() {
    if (!mounted) return;
    setState(() {
      _isListVisible = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    const String noteListSettingKeySuffix = "NOTES_PAGE";

    return ResponsiveScaffoldLayout(
      title: _translationService.translate(NoteTranslationKeys.notesLabel),
      appBarActions: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NoteAddButton(
              mini: true,
              onNoteCreated: _handleNoteCreated,
              buttonColor: _themeService.primaryColor,
              initialTitle: _searchQuery,
              initialTagIds: _selectedTagIds,
            ),
            KebabMenu(
              helpTitleKey: NoteTranslationKeys.helpTitle,
              helpMarkdownContentKey: NoteTranslationKeys.helpContent,
            ),
          ],
        ),
      ],
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filters section with consistent padding
          NoteListOptions(
            selectedTagIds: _selectedTagIds,
            showNoTagsFilter: _showNoTagsFilter,
            search: _searchQuery,
            sortConfig: _sortConfig,
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
            onSortChange: (sortConfig) {
              setState(() {
                _sortConfig = sortConfig;
              });
            },
            onSettingsLoaded: _handleSettingsLoaded,
            onSaveSettings: () {
              // Force refresh the list when settings are saved
              setState(() {});
            },
            settingKeyVariantSuffix: noteListSettingKeySuffix,
          ),

          // Notes list
          if (_isListVisible)
            Expanded(
              child: NotesList(
                filterByTags: _selectedTagIds,
                filterNoTags: _showNoTagsFilter,
                search: _searchQuery,
                sortConfig: _sortConfig,
                onClickNote: _openDetails,
              ),
            ),
        ],
      ),
    );
  }
}
