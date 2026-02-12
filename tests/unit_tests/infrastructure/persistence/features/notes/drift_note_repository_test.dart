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
import 'package:acore/acore.dart';

import 'package:path/path.dart' as p;

void main() {
  group('DriftNoteRepository', () {
    late AppDatabase database;
    late DriftNoteRepository repository;
    late DriftTagRepository tagRepository;
    late DriftNoteTagRepository noteTagRepository;
    late Directory tempDir;

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

      // Ensure clean state by deleting the database file
      final dbPath = p.join(tempDir.path, databaseName);
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }

      // Initialize singleton logic by creating repositories
      // DriftNoteRepository calls AppDatabase.instance(), which will now respect isTestMode=true
      repository = DriftNoteRepository();
      noteTagRepository = DriftNoteTagRepository();

      // Get the singleton instance to pass to other repos or uses
      database = AppDatabase.instance();

      // TagRepository has a named constructor for custom db, but we can also use the default which uses singleton
      // Since we want everything to share the same singleton instance:
      tagRepository = DriftTagRepository.withDatabase(database);
    });

    tearDown(() async {
      await database.close();
      AppDatabase.resetInstance();
    });

    tearDownAll(() async {
      await tempDir.delete(recursive: true);
    });

    group('getList', () {
      test('should return paginated notes with tags', () async {
        // Arrange
        // 1. Create Tags
        final tag1 = Tag(id: 'tag-1', createdDate: DateTime.utc(2024, 1, 1), name: 'Tag 1', color: '#FF0000');
        final tag2 = Tag(id: 'tag-2', createdDate: DateTime.utc(2024, 1, 1), name: 'Tag 2', color: '#00FF00');
        await tagRepository.add(tag1);
        await tagRepository.add(tag2);

        // 2. Create Notes
        final note1 = Note(id: 'note-1', createdDate: DateTime.utc(2024, 1, 1), title: 'Note 1', content: 'Content 1');
        final note2 = Note(id: 'note-2', createdDate: DateTime.utc(2024, 1, 2), title: 'Note 2', content: 'Content 2');
        final note3 = Note(id: 'note-3', createdDate: DateTime.utc(2024, 1, 3), title: 'Note 3', content: 'Content 3');

        await repository.add(note1);
        await repository.add(note2);
        await repository.add(note3);

        // 3. Associate Tags
        final noteTag1 = NoteTag(id: 'nt-1', createdDate: DateTime.utc(2024, 1, 1), noteId: 'note-1', tagId: 'tag-1');
        final noteTag2 = NoteTag(id: 'nt-2', createdDate: DateTime.utc(2024, 1, 1), noteId: 'note-1', tagId: 'tag-2');
        final noteTag3 = NoteTag(id: 'nt-3', createdDate: DateTime.utc(2024, 1, 1), noteId: 'note-3', tagId: 'tag-1');

        await noteTagRepository.add(noteTag1);
        await noteTagRepository.add(noteTag2);
        await noteTagRepository.add(noteTag3);

        // Act - Get first page, size 2
        final result = await repository.getList(0, 2);

        // Assert
        expect(result.items.length, equals(2));
        expect(result.totalItemCount, equals(3));

        // Verify Content
        final fetchedNote1 = result.items.firstWhere((n) => n.id == 'note-1');
        expect(fetchedNote1.tags.length, equals(2));
        expect(fetchedNote1.tags.map((t) => t.tagId), containsAll(['tag-1', 'tag-2']));
        expect(fetchedNote1.tags.first.tag, isNotNull); // Verify populated Tag object
        expect(fetchedNote1.tags.first.tag!.name, isNotNull);

        final fetchedNote2 = result.items.firstWhere((n) => n.id == 'note-2');
        expect(fetchedNote2.tags, isEmpty);
      });

      test('should sort notes by title correctly', () async {
        // Arrange
        final noteA = Note(id: 'a', createdDate: DateTime.now(), title: 'A Note');
        final noteB = Note(id: 'b', createdDate: DateTime.now(), title: 'B Note');
        final noteC = Note(id: 'c', createdDate: DateTime.now(), title: 'C Note');

        await repository.add(noteC);
        await repository.add(noteA);
        await repository.add(noteB);

        // Act
        final result =
            await repository.getList(0, 10, customOrder: [CustomOrder(field: 'title', direction: SortDirection.asc)]);

        // Assert
        expect(result.items.length, equals(3));
        expect(result.items[0].id, equals('a'));
        expect(result.items[1].id, equals('b'));
        expect(result.items[2].id, equals('c'));
      });

      test('should sort notes by title descending', () async {
        // Arrange
        final noteA = Note(id: 'a', createdDate: DateTime.now(), title: 'A Note');
        final noteB = Note(id: 'b', createdDate: DateTime.now(), title: 'B Note');
        final noteC = Note(id: 'c', createdDate: DateTime.now(), title: 'C Note');

        await repository.add(noteC);
        await repository.add(noteA);
        await repository.add(noteB);

        // Act
        final result =
            await repository.getList(0, 10, customOrder: [CustomOrder(field: 'title', direction: SortDirection.desc)]);

        // Assert
        expect(result.items.length, equals(3));
        expect(result.items[0].id, equals('c'));
        expect(result.items[1].id, equals('b'));
        expect(result.items[2].id, equals('a'));
      });

      test('getList should apply custom where filter', () async {
        final noteDate = DateTime.now();
        final note1 = Note(id: 'n1', title: 'Find Me', createdDate: noteDate);
        final note2 = Note(id: 'n2', title: 'Hide Me', createdDate: noteDate);

        await repository.add(note1);
        await repository.add(note2);

        final result =
            await repository.getList(0, 10, customWhereFilter: CustomWhereFilter("title LIKE ?", ['%Find%']));

        expect(result.items.length, 1);
        expect(result.items.first.id, 'n1');
      });

      test('getById should return note with correct tags', () async {
        final noteDate = DateTime.now();
        final note = Note(id: 'n1', title: 'Note 1', createdDate: noteDate);
        final tag1 = Tag(id: 't1', name: 'Tag 1', color: 'red', createdDate: noteDate);
        final tag2 = Tag(id: 't2', name: 'Tag 2', color: 'blue', createdDate: noteDate);

        await repository.add(note);
        await tagRepository.add(tag1);
        await tagRepository.add(tag2);

        await noteTagRepository.add(NoteTag(id: 'nt1', noteId: note.id, tagId: tag1.id, createdDate: noteDate));
        await noteTagRepository.add(NoteTag(id: 'nt2', noteId: note.id, tagId: tag2.id, createdDate: noteDate));

        final fetchedNote = await repository.getById('n1');

        expect(fetchedNote, isNotNull);
        expect(fetchedNote!.id, 'n1');
        expect(fetchedNote.tags.length, 2);
        expect(fetchedNote.tags.any((nt) => nt.tag?.name == 'Tag 1'), isTrue);
        expect(fetchedNote.tags.any((nt) => nt.tag?.name == 'Tag 2'), isTrue);
      });
    });
  });
}
