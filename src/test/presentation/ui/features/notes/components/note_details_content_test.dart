import 'dart:async';

import 'package:acore/acore.dart' hide Container;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/notes/commands/save_note_command.dart';
import 'package:whph/core/application/features/notes/queries/get_note_query.dart';
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/features/notes/components/note_details_content.dart';
import 'package:whph/presentation/ui/features/notes/services/notes_service.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class _FakeTranslationService extends Fake implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) => key;
}

/// Emulates the repository's optimistic-concurrency check: an update is only
/// accepted when its expected revision matches the stored one.
class _RevisionCheckingMediator extends Fake implements Mediator {
  DateTime revision = DateTime.utc(2026, 1, 1);
  String title = 'Note';
  int acceptedUpdates = 0;
  int conflicts = 0;
  String? content;
  final List<UpdateNoteCommand> updates = [];

  /// When set, the first update waits for it (a slow in-flight save).
  Completer<void>? firstUpdateGate;

  @override
  Future<R> send<T extends IRequest<R>, R extends Object?>(T request) async {
    final Object message = request;
    if (message is GetNoteQuery) {
      return GetNoteQueryResponse(
        id: message.id,
        title: title,
        content: content,
        order: 'U',
        createdDate: DateTime.utc(2026, 1, 1),
        modifiedDate: revision,
        tags: [],
      ) as R;
    }
    if (message is UpdateNoteCommand) {
      updates.add(message);
      final gate = firstUpdateGate;
      if (gate != null && updates.length == 1) await gate.future;
      if (!message.expectedRevision.isAtSameMomentAs(revision)) {
        conflicts++;
        throw NoteRevisionConflictException(message.id);
      }
      acceptedUpdates++;
      revision = revision.add(const Duration(seconds: 1));
      title = message.title ?? title;
      return SaveNoteCommandResponse(id: message.id, revision: revision) as R;
    }
    throw UnsupportedError('Unexpected request: $request');
  }
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

void main() {
  late _FakeContainer container;
  late _RevisionCheckingMediator mediator;

  setUpAll(() {
    container = _FakeContainer();
    app_main.container = container;
  });

  // Failure tests log error output on purpose: the editor reports a failed save on leave via Logger only.
  setUp(() {
    mediator = _RevisionCheckingMediator();
    container.register<Mediator>(mediator);
    container.register<NotesService>(NotesService());
    container.register<ITranslationService>(_FakeTranslationService());
  });

  testWidgets('consecutive autosaves while the field keeps focus do not raise revision conflicts', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: NoteDetailsContent(noteId: 'n1'))),
    );
    await tester.pumpAndSettle();

    final titleField = find.byType(TextFormField).first;
    await tester.tap(titleField);
    await tester.pump();

    await tester.enterText(titleField, 'Note A');
    await tester.pump(SharedUiConstants.contentSaveDebounceTime + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    await tester.enterText(titleField, 'Note AB');
    await tester.pump(SharedUiConstants.contentSaveDebounceTime + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(mediator.conflicts, 0);
    expect(mediator.acceptedUpdates, 2);
    expect(mediator.title, 'Note AB');
  });

  testWidgets('leaving the editor within the autosave debounce still saves the edit once', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: NoteDetailsContent(noteId: 'n1'))),
    );
    await tester.pumpAndSettle();

    final titleField = find.byType(TextFormField).first;
    await tester.tap(titleField);
    await tester.pump();
    await tester.enterText(titleField, 'Typed just before leaving');
    await tester.pump(const Duration(milliseconds: 50));
    expect(mediator.acceptedUpdates, 0);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pumpAndSettle();

    expect(mediator.conflicts, 0);
    expect(mediator.acceptedUpdates, 1);
    expect(mediator.title, 'Typed just before leaving');
  });

  Future<Finder> editTitle(WidgetTester tester, String text) async {
    final titleField = find.byType(TextFormField).first;
    await tester.tap(titleField);
    await tester.pump();
    await tester.enterText(titleField, text);
    return titleField;
  }

  Future<void> pumpNote(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: NoteDetailsContent(noteId: 'n1'))));
    await tester.pumpAndSettle();
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pumpAndSettle();
  }

  testWidgets('the save on leave sends the typed title and the loaded content as a set update', (tester) async {
    mediator.content = 'Body text';
    await pumpNote(tester);
    await editTitle(tester, 'Typed title');
    await tester.pump(const Duration(milliseconds: 50));

    await leave(tester);

    final command = mediator.updates.single;
    expect(command.title, 'Typed title');
    expect(command.content.isChanged, isTrue);
    expect(command.content.value, 'Body text');
    expect(command.expectedRevision, DateTime.utc(2026, 1, 1));
  });

  testWidgets('a revision conflict on leave is swallowed without a crash', (tester) async {
    await pumpNote(tester);
    await editTitle(tester, 'Typed just before leaving');
    await tester.pump(const Duration(milliseconds: 50));
    mediator.revision = mediator.revision.add(const Duration(seconds: 5)); // edited elsewhere meanwhile

    await leave(tester);

    expect(tester.takeException(), isNull);
    expect(mediator.conflicts, 1);
    expect(mediator.acceptedUpdates, 0);
  });

  testWidgets('the leave flush runs after a slow in-flight save, not alongside it', (tester) async {
    await pumpNote(tester);
    mediator.firstUpdateGate = Completer<void>();
    await editTitle(tester, 'First');
    await tester.pump(SharedUiConstants.contentSaveDebounceTime + const Duration(milliseconds: 50)); // in flight
    final titleField = find.byType(TextFormField).first;
    await tester.enterText(titleField, 'Second');
    await tester.pump(const Duration(milliseconds: 50));

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pump();
    expect(mediator.updates.map((u) => u.title), ['First']); // the flush is still queued

    mediator.firstUpdateGate!.complete();
    await tester.pumpAndSettle();

    expect(mediator.updates.map((u) => u.title), ['First', 'Second']);
    expect(mediator.conflicts, 0);
    expect(mediator.title, 'Second');
  });

  testWidgets('leaving the editor with nothing pending sends no save', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: NoteDetailsContent(noteId: 'n1'))),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pumpAndSettle();

    expect(mediator.acceptedUpdates, 0);
  });
}
