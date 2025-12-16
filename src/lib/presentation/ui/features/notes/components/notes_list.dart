import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/notes/queries/get_list_notes_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/notes/components/note_card.dart';
import 'package:whph/presentation/ui/features/notes/constants/note_translation_keys.dart';
import 'package:whph/presentation/ui/features/notes/pages/note_details_page.dart';
import 'package:whph/presentation/ui/features/notes/services/notes_service.dart';
import 'package:whph/presentation/ui/shared/components/icon_overlay.dart';
import 'package:whph/presentation/ui/shared/components/load_more_button.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/shared/enums/pagination_mode.dart';

class NotesList extends StatefulWidget {
  final String? search;
  final List<String>? filterByTags;
  final bool filterNoTags;
  final bool ignoreArchivedTagVisibility;
  final Function(String)? onClickNote;
  final void Function(int count)? onList;
  final SortConfig<NoteSortFields>? sortConfig;
  final int pageSize;
  final PaginationMode paginationMode;

  const NotesList({
    super.key,
    this.search,
    this.filterByTags,
    this.filterNoTags = false,
    this.ignoreArchivedTagVisibility = false,
    this.onClickNote,
    this.onList,
    this.sortConfig,
    this.pageSize = 10,
    this.paginationMode = PaginationMode.loadMore,
  });

  @override
  State<NotesList> createState() => NotesListState();
}

class NotesListState extends State<NotesList> {
  final _notesService = container.resolve<NotesService>();
  final _translationService = container.resolve<ITranslationService>();
  final _mediator = container.resolve<Mediator>();
  final ScrollController _scrollController = ScrollController();
  GetListNotesQueryResponse? _noteList;
  Timer? _refreshDebounce;
  bool _pendingRefresh = false;
  late FilterContext _currentFilters;
  double? _savedScrollPosition;

  // Infinity scroll state
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _currentFilters = _captureCurrentFilters(); // Initialize _currentFilters first
    _getNotes();
    _setupEventListeners();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _removeEventListeners();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    if (widget.paginationMode == PaginationMode.infinityScroll) {
      _scrollController.addListener(_onScroll);
    }
  }

  void _onScroll() {
    if (widget.paginationMode != PaginationMode.infinityScroll) return;
    if (_isLoadingMore || _noteList == null || !_noteList!.hasNext) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = maxScroll * 0.8;

    if (currentScroll >= threshold) {
      _loadMoreInfinityScroll();
    }
  }

  Future<void> _loadMoreInfinityScroll() async {
    if (_isLoadingMore || _noteList == null || !_noteList!.hasNext) return;

    setState(() => _isLoadingMore = true);
    await _getNotes(pageIndex: _noteList!.pageIndex + 1);
    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
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
        ignoreArchivedTagVisibility: widget.ignoreArchivedTagVisibility,
        sortConfig: widget.sortConfig,
      );

  bool _isFilterChanged({required FilterContext oldFilters, required FilterContext newFilters}) {
    final oldMap = {
      'search': oldFilters.search,
      'filterNoTags': oldFilters.filterNoTags,
      'ignoreArchivedTagVisibility': oldFilters.ignoreArchivedTagVisibility,
      'tags': oldFilters.filterByTags,
      'sortConfig': oldFilters.sortConfig,
    };

    final newMap = {
      'search': newFilters.search,
      'filterNoTags': newFilters.filterNoTags,
      'ignoreArchivedTagVisibility': newFilters.ignoreArchivedTagVisibility,
      'tags': newFilters.filterByTags,
      'sortConfig': newFilters.sortConfig,
    };

    return CollectionUtils.hasAnyMapValueChanged(oldMap, newMap);
  }

  void _saveScrollPosition() {
    if (_scrollController.hasClients && _scrollController.position.hasViewportDimension) {
      _savedScrollPosition = _scrollController.position.pixels;
    }
  }

  void _backLastScrollPosition() {
    if (_savedScrollPosition == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _scrollController.hasClients &&
          _scrollController.position.hasViewportDimension &&
          _savedScrollPosition! <= _scrollController.position.maxScrollExtent) {
        _scrollController.jumpTo(_savedScrollPosition!);
      }
    });
  }

  Future<void> refresh() async {
    if (!mounted) return;

    _saveScrollPosition();
    _refreshDebounce?.cancel();

    if (_pendingRefresh) {
      _pendingRefresh = false;
    }

    _refreshDebounce = Timer(const Duration(milliseconds: 100), () async {
      await _getNotes(isRefresh: true);
      _backLastScrollPosition();

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
    if (_noteList?.items.any((n) => n.id == noteId) == true) {
      refresh();
    }
  }

  Future<void> _getNotes({
    int pageIndex = 0,
    bool isRefresh = false,
  }) async {
    await AsyncErrorHandler.execute<GetListNotesQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(NoteTranslationKeys.loadingError),
      operation: () async {
        final query = GetListNotesQuery(
          pageIndex: pageIndex,
          pageSize: isRefresh && (_noteList?.items.length ?? 0) > widget.pageSize
              ? _noteList?.items.length ?? widget.pageSize
              : widget.pageSize,
          search: _currentFilters.search,
          filterByTags: _currentFilters.filterByTags,
          filterNoTags: _currentFilters.filterNoTags,
          ignoreArchivedTagVisibility: _currentFilters.ignoreArchivedTagVisibility,
          sortBy: _currentFilters.sortConfig?.orderOptions,
          sortByCustomOrder: _currentFilters.sortConfig?.useCustomOrder ?? false,
        );

        return await _mediator.send<GetListNotesQuery, GetListNotesQueryResponse>(query);
      },
      onSuccess: (result) {
        setState(() {
          if (_noteList == null || isRefresh) {
            _noteList = result;
          } else {
            _noteList = GetListNotesQueryResponse(
              items: [..._noteList!.items, ...result.items],
              totalItemCount: result.totalItemCount,
              pageIndex: result.pageIndex,
              pageSize: result.pageSize,
            );
          }
        });

        // Notify about list count
        widget.onList?.call(_noteList?.items.length ?? 0);

        // For infinity scroll: check if viewport needs more content
        if (widget.paginationMode == PaginationMode.infinityScroll && _noteList!.hasNext) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkAndFillViewport();
          });
        }
      },
    );
  }

  void _checkAndFillViewport() {
    if (!mounted || _isLoadingMore || _noteList == null || !_noteList!.hasNext) return;
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) {
      _loadMoreInfinityScroll();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_noteList == null) {
      // No loading indicator since local DB is fast
      return const SizedBox.shrink();
    }

    if (_noteList == null || _noteList!.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.sizeMedium),
        child: IconOverlay(
          icon: Icons.note_alt_outlined,
          iconSize: AppTheme.iconSizeXLarge,
          message: _translationService.translate(NoteTranslationKeys.noNotes),
        ),
      );
    }

    final showLoadMore = _noteList!.hasNext && widget.paginationMode == PaginationMode.loadMore;
    final showInfinityLoading =
        _noteList!.hasNext && widget.paginationMode == PaginationMode.infinityScroll && _isLoadingMore;
    final extraItemCount = (showLoadMore || showInfinityLoading) ? 1 : 0;

    return ListView.separated(
      controller: _scrollController,
      shrinkWrap: true,
      itemCount: _noteList!.items.length + extraItemCount,
      separatorBuilder: (context, index) => const SizedBox(height: AppTheme.size3XSmall),
      itemBuilder: (context, index) {
        if (index == _noteList!.items.length && showLoadMore) {
          return Padding(
            padding: const EdgeInsets.only(top: AppTheme.size2XSmall),
            child: Center(child: LoadMoreButton(onPressed: _onLoadMore)),
          );
        } else if (index == _noteList!.items.length && showInfinityLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppTheme.sizeMedium),
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (index >= _noteList!.items.length) {
          return const SizedBox.shrink();
        }

        final note = _noteList!.items[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.size3XSmall),
          child: NoteCard(
            note: note,
            onOpenDetails: () => _onNoteSelected(note.id),
            isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
          ),
        );
      },
    );
  }

  Future<void> _onLoadMore() async {
    if (_noteList == null || !_noteList!.hasNext) return;

    _saveScrollPosition();
    await _getNotes(pageIndex: _noteList!.pageIndex + 1);
    _backLastScrollPosition();
  }

  Future<void> _onNoteSelected(String id) async {
    if (widget.onClickNote != null) {
      widget.onClickNote!(id);
      return;
    }

    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: NoteDetailsPage(
        noteId: id,
      ),
      size: DialogSize.max,
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
  final bool ignoreArchivedTagVisibility;
  final SortConfig<NoteSortFields>? sortConfig;

  const FilterContext({
    this.search,
    this.filterByTags,
    this.filterNoTags = false,
    this.ignoreArchivedTagVisibility = false,
    this.sortConfig,
  });

  /// Returns true if any filter is active
  bool get hasAnyFilter => search?.isNotEmpty == true || filterByTags?.isNotEmpty == true || filterNoTags;

  @override
  String toString() =>
      'FilterContext(search: $search, tags: $filterByTags, noTags: $filterNoTags, ignoreArchivedTagVisibility: $ignoreArchivedTagVisibility, sortConfig: $sortConfig)';
}
