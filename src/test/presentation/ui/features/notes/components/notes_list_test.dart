import 'dart:async';

import 'package:acore/acore.dart' hide Container;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/notes/queries/get_list_notes_query.dart';
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/features/notes/components/note_card.dart';
import 'package:whph/presentation/ui/features/notes/components/notes_list.dart';
import 'package:whph/presentation/ui/features/notes/services/notes_service.dart';
import 'package:whph/presentation/ui/shared/enums/pagination_mode.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class _FakeTranslationService extends Fake implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) => key;
}

class _FakeContainer extends Fake implements IContainer {
  final Map<Type, Object> _registrations = {};

  void register<T extends Object>(T instance) => _registrations[T] = instance;

  @override
  T resolve<T>([String? name]) {
    final registration = _registrations[T];
    if (registration == null) throw StateError('Service not registered: $T');
    return registration as T;
  }
}

String _noteId(int n) => 'note-${n.toString().padLeft(2, '0')}';

/// Serves [GetListNotesQuery] from an in-memory, stably ordered dataset the way
/// the real repository does (`OFFSET pageIndex * pageSize`), records every
/// request's `(pageIndex, pageSize)`, and can hold responses on completers.
class _PagingNotesMediator extends Fake implements Mediator {
  _PagingNotesMediator({this.emptyPages = false});

  /// Reported total row count; the in-memory dataset has this many notes.
  int totalItemCount = 50;

  /// When true every page returns zero items while still reporting [totalItemCount].
  final bool emptyPages;

  final List<(int, int)> queries = [];

  /// Holds only the next query's response.
  bool holdNext = false;

  /// Holds every subsequent query's response.
  bool holdAll = false;

  final List<Completer<void>> _held = [];

  int get heldCount => _held.length;

  void releaseNextHeld() => _held.removeAt(0).complete();

  @override
  Future<R> send<T extends IRequest<R>, R extends Object?>(T request) async {
    final Object message = request;
    if (message is GetListNotesQuery) {
      queries.add((message.pageIndex, message.pageSize));
      final response = _page(message.pageIndex, message.pageSize);
      if (holdNext || holdAll) {
        holdNext = false;
        final completer = Completer<void>();
        _held.add(completer);
        await completer.future;
      }
      return response as R;
    }
    throw UnsupportedError('Unexpected request: $request');
  }

  GetListNotesQueryResponse _page(int pageIndex, int pageSize) {
    final start = pageIndex * pageSize;
    final end = (start + pageSize).clamp(0, totalItemCount);
    return GetListNotesQueryResponse(
      items: [
        if (!emptyPages)
          for (var i = start; i < end; i++)
            NoteListItem(
              id: _noteId(i + 1),
              title: 'Note ${(i + 1).toString().padLeft(2, '0')}',
              createdDate: DateTime.utc(2026, 1, 1),
            ),
      ],
      totalItemCount: totalItemCount,
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }
}

void main() {
  late _FakeContainer container;
  late _PagingNotesMediator mediator;

  setUpAll(() {
    container = _FakeContainer();
    app_main.container = container;
  });

  void registerServices(_PagingNotesMediator m) {
    mediator = m;
    container.register<Mediator>(m);
    container.register<NotesService>(NotesService());
    container.register<ITranslationService>(_FakeTranslationService());
  }

  Finder listScrollable() => find.byType(Scrollable).first;

  ScrollPosition position(WidgetTester tester) => tester.state<ScrollableState>(listScrollable()).position;

  Future<NotesListState> pumpNotesList(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey<NotesListState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 400,
              child: NotesList(key: key, paginationMode: PaginationMode.infinityScroll),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return key.currentState!;
  }

  /// Jumps to the end of the list so the infinity-scroll listener fires a load-more.
  Future<void> triggerLoadMore(WidgetTester tester) async {
    final pos = position(tester);
    pos.jumpTo(pos.maxScrollExtent);
    await tester.pump();
  }

  /// Pumps frames for [duration] without waiting for idle, so it also works while a
  /// held load-more keeps the infinite-scroll spinner animating.
  Future<void> pumpFor(WidgetTester tester, [Duration duration = const Duration(seconds: 2)]) async {
    const frame = Duration(milliseconds: 16);
    for (var elapsed = Duration.zero; elapsed < duration; elapsed += frame) {
      await tester.pump(frame);
    }
  }

  Future<void> refreshAndWait(WidgetTester tester, NotesListState state) async {
    unawaited(state.refresh());
    await tester.pump(const Duration(milliseconds: 150));
    await pumpFor(tester);
  }

  /// Scrolls through the whole list and returns the ids of every rendered note in
  /// visual order (duplicates preserved). Further load-mores fired by the scan are
  /// held so they cannot change the list while it is being read.
  Future<List<String>> collectRenderedIds(WidgetTester tester) async {
    mediator.holdAll = true;
    final idsByOffset = <int, String>{};
    final pos = position(tester);
    pos.jumpTo(0);
    await tester.pump();
    while (true) {
      final viewportTop = tester.getTopLeft(listScrollable()).dy;
      for (final element in find.byType(NoteCard, skipOffstage: false).evaluate()) {
        final box = element.renderObject! as RenderBox;
        final offset = box.localToGlobal(Offset.zero).dy - viewportTop + pos.pixels;
        idsByOffset[offset.round()] = (element.widget as NoteCard).note.id;
      }
      if (pos.pixels >= pos.maxScrollExtent) break;
      pos.jumpTo((pos.pixels + 200).clamp(0.0, pos.maxScrollExtent));
      await tester.pump();
    }
    final offsets = idsByOffset.keys.toList()..sort();
    return [for (final o in offsets) idsByOffset[o]!];
  }

  testWidgets('(a) load-more during scroll does not snap back to the pre-load offset', (tester) async {
    registerServices(_PagingNotesMediator());
    await pumpNotesList(tester);
    expect(mediator.queries, [(0, 10)]);

    final pos = position(tester);
    mediator.holdNext = true;
    pos.jumpTo(pos.maxScrollExtent * 0.85);
    await tester.pump();
    expect(mediator.queries, [(0, 10), (1, 10)], reason: 'crossing the 80% threshold should fire a load-more');
    expect(mediator.heldCount, 1);
    final triggerOffset = pos.pixels;

    // The user keeps scrolling while the load-more is in flight.
    await tester.drag(listScrollable(), const Offset(0, -300));
    await pumpFor(tester);
    final userOffset = pos.pixels;
    expect(userOffset, greaterThan(triggerOffset + 1), reason: 'the drag should move the list further down');

    mediator.releaseNextHeld();
    await tester.pumpAndSettle();

    expect(pos.pixels, greaterThanOrEqualTo(userOffset),
        reason: 'appending a page must not jump the user back to the offset saved before the load');
  });

  testWidgets('(b) refresh then load-more continues from the loaded rows without duplicates', (tester) async {
    registerServices(_PagingNotesMediator());
    final state = await pumpNotesList(tester);
    expect(mediator.queries, [(0, 10)]);

    await triggerLoadMore(tester);
    await tester.pumpAndSettle();
    await triggerLoadMore(tester);
    await tester.pumpAndSettle();
    expect(mediator.queries, [(0, 10), (1, 10), (2, 10)], reason: 'setup: load until 30 notes');

    await refreshAndWait(tester, state);
    expect(mediator.queries.sublist(3), [(0, 30)], reason: 'refresh reloads every loaded row in one page');

    await triggerLoadMore(tester);
    await tester.pumpAndSettle();
    expect(mediator.queries.sublist(3), [(0, 30), (3, 10)],
        reason: 'load-more after a 30-row refresh must continue at row 30 (pageIndex 3 of size 10)');

    final ids = await collectRenderedIds(tester);
    expect(ids, [for (var n = 1; n <= 40; n++) _noteId(n)],
        reason: 'loaded notes must be exactly note 1..40, unique and in order');
  });

  testWidgets('(c) scrolling during an in-flight refresh keeps the user offset', (tester) async {
    registerServices(_PagingNotesMediator());
    final state = await pumpNotesList(tester);
    expect(mediator.queries, [(0, 10)]);

    final pos = position(tester);
    pos.jumpTo(60);
    await tester.pumpAndSettle();
    final offsetA = pos.pixels;
    expect(mediator.queries, [(0, 10)], reason: 'idling at A must not fire a load-more');

    mediator.holdNext = true;
    unawaited(state.refresh());
    await tester.pump(const Duration(milliseconds: 150));
    expect(mediator.queries, [(0, 10), (0, 10)]);
    expect(mediator.heldCount, 1);

    await tester.drag(listScrollable(), const Offset(0, 40));
    await tester.pumpAndSettle();
    final offsetB = pos.pixels;
    expect((offsetB - offsetA).abs(), greaterThan(5), reason: 'the drag should move the list away from A');

    mediator.releaseNextHeld();
    await tester.pumpAndSettle();

    expect(pos.pixels, closeTo(offsetB, 0.5), reason: 'refresh must not restore the stale offset A');
  });

  testWidgets('(d) a load-more that lands after a refresh is dropped', (tester) async {
    registerServices(_PagingNotesMediator());
    final state = await pumpNotesList(tester);
    expect(mediator.queries, [(0, 10)]);

    mediator.holdNext = true;
    await triggerLoadMore(tester);
    expect(mediator.queries, [(0, 10), (1, 10)]);
    expect(mediator.heldCount, 1);

    await refreshAndWait(tester, state);
    expect(mediator.queries, [(0, 10), (1, 10), (0, 10)]);

    mediator.releaseNextHeld();
    await tester.pumpAndSettle();
    expect(mediator.queries, [(0, 10), (1, 10), (0, 10)], reason: 'no further queries after the stale result');

    final ids = await collectRenderedIds(tester);
    expect(ids, [for (var n = 1; n <= 10; n++) _noteId(n)],
        reason: 'the stale load-more must neither append to nor replace the refreshed list');
  });

  testWidgets('(e) loading terminates when every page is empty but totalItemCount is 50', (tester) async {
    registerServices(_PagingNotesMediator(emptyPages: true));
    final state = await pumpNotesList(tester);
    expect(mediator.queries, [(0, 10)]);

    // With zero items the list renders its empty state, so no scroll position is
    // attached; drive load-more through the mixin's public entry point instead.
    for (var i = 0; i < 10 && state.hasNextPage; i++) {
      unawaited(state.loadMoreInfinityScroll());
      await tester.pumpAndSettle();
    }

    expect(state.hasNextPage, isFalse);
    expect(mediator.queries.length, lessThanOrEqualTo(5), reason: 'at most ceil(50/10) queries');

    final queryCount = mediator.queries.length;
    await tester.pumpAndSettle();
    expect(mediator.queries.length, queryCount, reason: 'no further queries once loading has stopped');
  });
}
