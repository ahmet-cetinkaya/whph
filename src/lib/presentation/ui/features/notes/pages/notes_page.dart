import 'dart:async';

import 'package:flutter/material.dart';
import 'package:whph/core/application/features/notes/queries/get_list_notes_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/notes/components/note_add_button.dart';
import 'package:whph/presentation/ui/features/notes/components/note_list_options.dart';
import 'package:whph/presentation/ui/features/notes/components/notes_list.dart';
import 'package:whph/presentation/ui/features/notes/constants/note_translation_keys.dart';
import 'package:whph/presentation/ui/features/notes/pages/note_details_page.dart';
import 'package:whph/presentation/ui/shared/components/kebab_menu.dart';
import 'package:whph/presentation/ui/shared/components/loading_overlay.dart';
import 'package:whph/presentation/ui/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/corePackages/acore/lib/utils/dialog_size.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/corePackages/acore/lib/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/shared/components/tour_overlay.dart';
import 'package:whph/presentation/ui/shared/services/tour_navigation_service.dart';

class NotesPage extends StatefulWidget {
  static const String route = '/notes';

  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with AutomaticKeepAliveClientMixin {
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();

  // Tour keys
  final GlobalKey _addNoteButtonKey = GlobalKey();
  final GlobalKey _noteFiltersKey = GlobalKey();
  final GlobalKey _notesListKey = GlobalKey();
  final GlobalKey _mainContentKey = GlobalKey();

  final Completer<void> _pageReadyCompleter = Completer<void>();
  int _loadedComponents = 0;
  static const int _totalComponentsToLoad = 2;

  bool _isListVisible = false;
  bool _isDataLoaded = false;
  List<String>? _selectedTagIds;
  bool _showNoTagsFilter = false;
  String? _searchQuery;
  SortConfig<NoteSortFields>? _sortConfig;

  @override
  bool get wantKeepAlive => true; // Keep the state alive when navigating away

  @override
  void initState() {
    super.initState();
    // Auto-start tour if multi-page tour is active
    _checkAndStartTour();
  }

  void _checkAndStartTour() async {
    final tourAlreadyDone = await TourNavigationService.isTourCompletedOrSkipped();
    if (tourAlreadyDone) return;

    if (TourNavigationService.isMultiPageTourActive && TourNavigationService.currentTourIndex == 5) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _pageReadyCompleter.future;
        if (mounted) {
          _startTour(isMultiPageTour: true);
        }
      });
    }
  }

  void _componentLoaded() {
    _loadedComponents++;
    if (_loadedComponents >= _totalComponentsToLoad && !_pageReadyCompleter.isCompleted) {
      _pageReadyCompleter.complete();
    }
  }

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
    _componentLoaded();
  }

  void _onDataListed(int count) {
    if (mounted) {
      setState(() {
        _isDataLoaded = true;
      });
      _componentLoaded();
    }
  }

  bool get _isPageFullyLoaded {
    return _isListVisible && _isDataLoaded;
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
              key: _addNoteButtonKey,
              mini: true,
              onNoteCreated: _handleNoteCreated,
              buttonColor: _themeService.primaryColor,
              initialTitle: _searchQuery,
              initialTagIds: _selectedTagIds,
            ),
            KebabMenu(
              helpTitleKey: NoteTranslationKeys.helpTitle,
              helpMarkdownContentKey: NoteTranslationKeys.helpContent,
              onStartTour: _startIndividualTour,
            ),
          ],
        ),
      ],
      builder: (context) => LoadingOverlay(
        isLoading: !_isPageFullyLoaded,
        child: Column(
          key: _mainContentKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters section with consistent padding
            NoteListOptions(
              key: _noteFiltersKey,
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
                  key: _notesListKey,
                  filterByTags: _selectedTagIds,
                  filterNoTags: _showNoTagsFilter,
                  search: _searchQuery,
                  sortConfig: _sortConfig,
                  onClickNote: _openDetails,
                  onList: _onDataListed,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _startTour({bool isMultiPageTour = false}) {
    final tourSteps = [
      // 1. Page introduce
      TourStep(
        title: _translationService.translate(NoteTranslationKeys.tourNoteTakingTitle),
        description: _translationService.translate(NoteTranslationKeys.tourNoteTakingDescription),
        icon: Icons.note_alt_outlined,
        targetKey: _mainContentKey,
        position: TourPosition.bottom,
      ),
      // 2. Note list introduce
      TourStep(
        title: _translationService.translate(NoteTranslationKeys.tourYourNotesTitle),
        description: _translationService.translate(NoteTranslationKeys.tourYourNotesDescription),
        targetKey: _notesListKey,
        position: TourPosition.top,
      ),
      // 3. List options introduce
      TourStep(
        title: _translationService.translate(NoteTranslationKeys.tourFilterSearchTitle),
        description: _translationService.translate(NoteTranslationKeys.tourFilterSearchDescription),
        targetKey: _noteFiltersKey,
        position: TourPosition.bottom,
      ),
      // 4. Add button introduce
      TourStep(
        title: _translationService.translate(NoteTranslationKeys.tourCreateNotesTitle),
        description: _translationService.translate(NoteTranslationKeys.tourCreateNotesDescription),
        targetKey: _addNoteButtonKey,
        position: TourPosition.bottom,
      ),
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => TourOverlay(
        steps: tourSteps,
        onComplete: () {
          Navigator.of(context).pop();
          if (isMultiPageTour) {
            TourNavigationService.onPageTourCompleted(context);
          }
        },
        onSkip: () async {
          if (isMultiPageTour) {
            await TourNavigationService.skipMultiPageTour();
          }
          if (context.mounted) Navigator.of(context).pop();
        },
        onBack: isMultiPageTour && TourNavigationService.canNavigateBack
            ? () => TourNavigationService.navigateBackInTour(context)
            : null,
        showBackButton: isMultiPageTour,
        isFinalPageOfTour: !isMultiPageTour || TourNavigationService.currentTourIndex == 5, // Notes page is final
        translationService: _translationService,
      ),
    );
  }

  void _startIndividualTour() {
    _startTour(isMultiPageTour: false);
  }
}
