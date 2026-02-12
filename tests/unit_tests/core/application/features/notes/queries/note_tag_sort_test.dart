import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:domain/features/notes/note.dart';
import 'package:domain/features/tags/tag.dart';
import 'package:domain/features/notes/note_tag.dart';
import 'package:infrastructure_persistence/features/notes/repositories/drift_note_repository.dart';
import 'package:infrastructure_persistence/features/notes/repositories/drift_note_tag_repository.dart';
import 'package:infrastructure_persistence/features/tags/repositories/drift_tag_repository.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:application/features/notes/queries/get_list_notes_query.dart';
import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';
import 'package:path/path.dart' as p;

class MockMediator extends Mediator {
  MockMediator(super.container);
}

void main() {
  group('Note Tag Sorting Test', () {
    late AppDatabase database;
    late DriftNoteRepository repository;
    late DriftTagRepository tagRepository;
    late DriftNoteTagRepository noteTagRepository;
    late Directory tempDir;
    late GetListNotesQueryHandler handler;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      tempDir = await Directory.systemTemp.createTemp();
      AppDatabase.testDirectory = tempDir;
      AppDatabase.isTestMode = true;
    });

    setUp(() async {
      AppDatabase.resetInstance();
      AppDatabase.isTestMode = true;
      AppDatabase.testDirectory = tempDir;

      final dbPath = p.join(tempDir.path, databaseName);
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }

      repository = DriftNoteRepository();
      noteTagRepository = DriftNoteTagRepository();
      database = AppDatabase.instance();
      tagRepository = DriftTagRepository.withDatabase(database);
      handler = GetListNotesQueryHandler(noteRepository: repository);
    });

    tearDown(() async {
      await database.close();
      AppDatabase.resetInstance();
    });

    tearDownAll(() async {
      await tempDir.delete(recursive: true);
    });

    test('should sort notes by tag name alphabetically', () async {
      // Arrange
      final now = DateTime.now();
      final tagA = Tag(id: 'a', name: 'Alpha', createdDate: now);
      final tagB = Tag(id: 'b', name: 'Beta', createdDate: now);
      await tagRepository.add(tagA);
      await tagRepository.add(tagB);

      final note1 = Note(id: 'n1', title: 'Note 1', createdDate: now);
      final note2 = Note(id: 'n2', title: 'Note 2', createdDate: now);
      await repository.add(note1);
      await repository.add(note2);

      // Note 1 -> Tag B (Beta)
      // Note 2 -> Tag A (Alpha)
      await noteTagRepository.add(NoteTag(id: 'nt1', noteId: 'n1', tagId: 'b', createdDate: now));
      await noteTagRepository.add(NoteTag(id: 'nt2', noteId: 'n2', tagId: 'a', createdDate: now));

      // Act
      final result = await handler.call(GetListNotesQuery(
        pageIndex: 0,
        pageSize: 10,
        sortBy: [SortOption(field: NoteSortFields.tag, direction: SortDirection.asc)],
      ));

      // Assert
      expect(result.items.length, 2);
      expect(result.items[0].id, 'n2'); // Alpha should come first
      expect(result.items[1].id, 'n1'); // Beta should come second
    });

    test('should sort notes by custom tag order', () async {
      // Arrange
      final now = DateTime.now();
      final tagA = Tag(id: 'a', name: 'Alpha', createdDate: now);
      final tagB = Tag(id: 'b', name: 'Beta', createdDate: now);
      await tagRepository.add(tagA);
      await tagRepository.add(tagB);

      final note1 = Note(id: 'n1', title: 'Note 1', createdDate: now);
      final note2 = Note(id: 'n2', title: 'Note 2', createdDate: now);
      await repository.add(note1);
      await repository.add(note2);

      // Note 1 -> Tag A
      // Note 2 -> Tag B
      await noteTagRepository.add(NoteTag(id: 'nt1', noteId: 'n1', tagId: 'a', createdDate: now));
      await noteTagRepository.add(NoteTag(id: 'nt2', noteId: 'n2', tagId: 'b', createdDate: now));

      // Custom Order: Tag B, then Tag A
      // Act
      final result = await handler.call(GetListNotesQuery(
        pageIndex: 0,
        pageSize: 10,
        sortBy: [SortOption(field: NoteSortFields.tag, direction: SortDirection.asc)],
        customTagSortOrder: ['b', 'a'],
      ));

      // Assert
      expect(result.items.length, 2);
      expect(result.items[0].id, 'n2'); // Tag B is first in custom order
      expect(result.items[1].id, 'n1'); // Tag A is second in custom order
    });
  });
}
