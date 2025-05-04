import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/notes/queries/get_list_notes_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/notes/components/note_card.dart';
import 'package:whph/presentation/features/notes/constants/note_translation_keys.dart';
import 'package:whph/presentation/features/notes/pages/note_details_page.dart';
import 'package:whph/presentation/features/notes/services/notes_service.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';

class NotesList extends StatefulWidget {
  final NotesService _notesService = container.resolve<NotesService>();

  final String? search;
  final List<String>? filterByTags;
  final bool filterNoTags;
  final Function(String)? onClickNote;

  NotesList({
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
  final _translationService = container.resolve<ITranslationService>();
  final _mediator = container.resolve<Mediator>();
  GetListNotesQueryResponse? _notes;
  bool _isLoading = false;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    widget._notesService.onNoteTagUpdated.addListener(_refresh);
    widget._notesService.onNoteSaved.addListener(_refresh);
    _loadInitialData();
  }

  @override
  void dispose() {
    widget._notesService.onNoteTagUpdated.removeListener(_refresh);
    widget._notesService.onNoteSaved.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    await _getNotes(isRefresh: true);
  }

  Future<void> _getNotes({
    int pageIndex = 0,
    bool isRefresh = false,
    bool showLoading = false,
  }) async {
    if (_isLoading) return;

    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        if (isRefresh) _notes = null;
      });
    }

    try {
      final query = GetListNotesQuery(
        pageIndex: pageIndex,
        pageSize: _pageSize,
        search: widget.search,
        filterByTags: widget.filterByTags,
        filterNoTags: widget.filterNoTags,
      );

      final result = await _mediator.send<GetListNotesQuery, GetListNotesQueryResponse>(query);

      if (!mounted) return;

      setState(() {
        if (_notes == null || isRefresh) {
          _notes = result;
        } else {
          _notes!.items.addAll(result.items);
          _notes!.pageIndex = result.pageIndex;
          _notes!.totalItemCount = result.totalItemCount;
          _notes!.totalPageCount = result.totalPageCount;
        }
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace, message: "Failed to load notes");
      }
    }
  }

  void _refresh() {
    if (mounted) _getNotes(isRefresh: true);
  }

  Future<void> refresh({bool showLoading = false}) async {
    await _getNotes(isRefresh: true, showLoading: showLoading);
  }

  Future<void> _onClickNote(String id) async {
    if (widget.onClickNote != null) {
      widget.onClickNote!(id);
    } else {
      await Navigator.of(context).pushNamed(
        NoteDetailsPage.route,
        arguments: {'id': id},
      );
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _notes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notes?.items.isEmpty ?? true) {
      return Center(
        child: Text(_translationService.translate(NoteTranslationKeys.noNotes)),
      );
    }

    return ListView(
      children: [
        ..._notes!.items.map((note) => InkWell(
              onTap: () => _onClickNote(note.id),
              child: NoteCard(note: note),
            )),
        if (_notes!.pageIndex < _notes!.totalPageCount - 1)
          TextButton(
            onPressed: () => _getNotes(pageIndex: _notes!.pageIndex + 1),
            child: Text(_translationService.translate(SharedTranslationKeys.loadMoreButton)),
          ),
      ],
    );
  }
}
