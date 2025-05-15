import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/notes/queries/get_list_notes_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/notes/components/note_card.dart';
import 'package:whph/presentation/features/notes/constants/note_translation_keys.dart';
import 'package:whph/presentation/features/notes/pages/note_details_page.dart';
import 'package:whph/presentation/features/notes/services/notes_service.dart';
import 'package:whph/presentation/shared/components/icon_overlay.dart';
import 'package:whph/presentation/shared/components/load_more_button.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/shared/utils/filter_change_analyzer.dart';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';

class NotesList extends StatefulWidget {
  final String? search;
  final List<String>? filterByTags;
  final bool filterNoTags;
  final Function(String)? onClickNote;

  const NotesList({
    super.key,
    this.search,
    this.filterByTags,
    this.filterNoTags = false,
    this.onClickNote,
  });

  @override
  State<NotesList> createState() => NotesListState();
}

class NotesListState extends State<NotesList> {
  final _notesService = container.resolve<NotesService>();
  final _translationService = container.resolve<ITranslationService>();
  final _mediator = container.resolve<Mediator>();
  GetListNotesQueryResponse? _notes;
  Timer? _refreshDebounce;
  bool _pendingRefresh = false;
  late FilterContext _currentFilters;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _currentFilters = _captureCurrentFilters(); // Initialize _currentFilters first
    _getNotes();
    _setupEventListeners();
  }

  @override
  void dispose() {
    _removeEventListeners();
    super.dispose();
  }

  @override
  void didUpdateWidget(NotesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newFilters = _captureCurrentFilters();
    if (_isFilterChanged(oldFilters: _currentFilters, newFilters: newFilters)) {
      _currentFilters = newFilters;
      refresh();
    }
  }

  FilterContext _captureCurrentFilters() => FilterContext(
        search: widget.search,
        filterByTags: widget.filterByTags,
        filterNoTags: widget.filterNoTags,
      );

  bool _isFilterChanged({required FilterContext oldFilters, required FilterContext newFilters}) {
    final oldMap = {
      'search': oldFilters.search,
      'filterNoTags': oldFilters.filterNoTags,
      'tags': oldFilters.filterByTags,
    };

    final newMap = {
      'search': newFilters.search,
      'filterNoTags': newFilters.filterNoTags,
      'tags': newFilters.filterByTags,
    };

    return FilterChangeAnalyzer.hasAnyFilterChanged(oldMap, newMap);
  }

  Future<void> refresh() async {
    if (!mounted) return;

    _refreshDebounce?.cancel();

    if (_pendingRefresh) {
      _pendingRefresh = false;
    }

    _refreshDebounce = Timer(const Duration(milliseconds: 100), () async {
      await _getNotes(isRefresh: true);

      if (_pendingRefresh) {
        _pendingRefresh = false;
        refresh();
      }
    });
  }

  void _refresh() {
    if (!mounted) return;

    // Always refresh on note creation
    if (_notesService.onNoteCreated.value != null) {
      refresh();
      return;
    }

    // Check which note was updated or deleted
    String? noteId = _notesService.onNoteUpdated.value ?? _notesService.onNoteDeleted.value;

    // Refresh if noteId is null or if the note is in our list
    if (noteId == null || _notes?.items.any((n) => n.id == noteId) == true) {
      refresh();
    }
  }

  Future<void> _getNotes({
    int pageIndex = 0,
    bool isRefresh = false,
  }) async {
    List<NoteListItem>? existingItems;
    if (isRefresh && _notes != null) {
      existingItems = List.from(_notes!.items);
    }

    final result = await AsyncErrorHandler.execute<GetListNotesQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(NoteTranslationKeys.loadingError),
      operation: () async {
        final query = GetListNotesQuery(
          pageIndex: pageIndex,
          pageSize: _pageSize,
          search: _currentFilters.search,
          filterByTags: _currentFilters.filterByTags,
          filterNoTags: _currentFilters.filterNoTags,
        );

        return await _mediator.send<GetListNotesQuery, GetListNotesQueryResponse>(query);
      },
      onSuccess: (result) {
        setState(() {
          if (_notes == null || !isRefresh) {
            _notes = result;
          } else {
            _notes = GetListNotesQueryResponse(
              items: [...result.items],
              totalItemCount: result.totalItemCount,
              totalPageCount: result.totalPageCount,
              pageIndex: result.pageIndex,
              pageSize: result.pageSize,
            );
          }
        });
      },
    );

    // If an error occurred (result is null) and we have existing items, restore them
    if (result == null && existingItems != null && _notes != null) {
      setState(() {
        _notes = GetListNotesQueryResponse(
          items: existingItems!,
          totalItemCount: _notes!.totalItemCount,
          totalPageCount: _notes!.totalPageCount,
          pageIndex: _notes!.pageIndex,
          pageSize: _notes!.pageSize,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_notes == null) {
      // No loading indicator since local DB is fast
      return const SizedBox.shrink();
    }

    if (_notes == null || _notes!.items.isEmpty) {
      final hasFilters = _currentFilters.hasAnyFilter;
      return IconOverlay(
        icon: Icons.note_alt_outlined,
        iconSize: 48,
        message: _translationService.translate(
          hasFilters ? NoteTranslationKeys.noNotesWithFilters : NoteTranslationKeys.noNotes,
        ),
      );
    }

    return ListView(
      children: [
        ..._notes!.items.map((note) => NoteCard(
              note: note,
              onOpenDetails: () => _onNoteSelected(note.id),
            )),
        if (_notes!.hasNext) LoadMoreButton(onPressed: () => _getNotes(pageIndex: _notes!.pageIndex + 1)),
      ],
    );
  }

  Future<void> _onNoteSelected(String id) async {
    if (widget.onClickNote != null) {
      widget.onClickNote!(id);
      return;
    }

    await ResponsiveDialogHelper.showResponsiveDetailsPage(
      context: context,
      title: _translationService.translate(NoteTranslationKeys.noteDetails),
      child: NoteDetailsPage(
        noteId: id,
      ),
    );
    _refresh();
  }

  void _setupEventListeners() {
    _notesService.onNoteUpdated.addListener(_refresh);
    _notesService.onNoteDeleted.addListener(_refresh);
    _notesService.onNoteCreated.addListener(_refresh);
  }

  void _removeEventListeners() {
    _notesService.onNoteUpdated.removeListener(_refresh);
    _notesService.onNoteDeleted.removeListener(_refresh);
    _notesService.onNoteCreated.removeListener(_refresh);
  }
}

class FilterContext {
  final String? search;
  final List<String>? filterByTags;
  final bool filterNoTags;

  const FilterContext({
    this.search,
    this.filterByTags,
    this.filterNoTags = false,
  });

  /// Returns true if any filter is active
  bool get hasAnyFilter => search?.isNotEmpty == true || filterByTags?.isNotEmpty == true || filterNoTags;

  @override
  String toString() => 'FilterContext(search: $search, tags: $filterByTags, noTags: $filterNoTags)';
}
