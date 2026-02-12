// ignore_for_file: unused_local_variable

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:application/features/tags/queries/get_tag_query.dart';
import 'package:application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:domain/features/tags/tag.dart';
import 'package:acore/acore.dart';

import 'get_tag_query_test.mocks.dart';

@GenerateMocks([ITagRepository])
void main() {
  late GetTagQueryHandler handler;
  late MockITagRepository mockTagRepository;

  setUp(() {
    mockTagRepository = MockITagRepository();
    handler = GetTagQueryHandler(tagRepository: mockTagRepository);
  });

  group('GetTagQueryHandler Tests', () {
    group('Successful Tag Retrieval', () {
      test('should return tag with type label', () async {
        // Arrange
        const tagId = 'tag-1';
        final tag = Tag(
          id: tagId,
          createdDate: DateTime.now().toUtc(),
          name: 'Work',
          color: 'FF0000',
          isArchived: false,
          type: TagType.label,
        );

        final query = GetTagQuery(id: tagId);

        when(mockTagRepository.getById(tagId)).thenAnswer((_) async => tag);

        // Act
        final result = await handler(query);

        // Assert
        expect(result.id, equals(tagId));
        expect(result.name, equals('Work'));
        expect(result.color, equals('FF0000'));
        expect(result.isArchived, isFalse);
        expect(result.type, equals(TagType.label));
        verify(mockTagRepository.getById(tagId)).called(1);
      });

      test('should return tag with type context', () async {
        // Arrange
        const tagId = 'tag-1';
        final tag = Tag(
          id: tagId,
          createdDate: DateTime.now().toUtc(),
          name: 'Home',
          type: TagType.context,
        );

        final query = GetTagQuery(id: tagId);

        when(mockTagRepository.getById(tagId)).thenAnswer((_) async => tag);

        // Act
        final result = await handler(query);

        // Assert
        expect(result.type, equals(TagType.context));
        expect(result.name, equals('Home'));
      });

      test('should return tag with type project', () async {
        // Arrange
        const tagId = 'tag-1';
        final tag = Tag(
          id: tagId,
          createdDate: DateTime.now().toUtc(),
          name: 'Website Redesign',
          color: '0000FF',
          type: TagType.project,
        );

        final query = GetTagQuery(id: tagId);

        when(mockTagRepository.getById(tagId)).thenAnswer((_) async => tag);

        // Act
        final result = await handler(query);

        // Assert
        expect(result.type, equals(TagType.project));
        expect(result.name, equals('Website Redesign'));
        expect(result.color, equals('0000FF'));
      });

      test('should return tag with all fields populated', () async {
        // Arrange
        const tagId = 'tag-1';
        final now = DateTime.now().toUtc();
        final tag = Tag(
          id: tagId,
          createdDate: now,
          modifiedDate: now,
          deletedDate: null,
          name: 'Complete Tag',
          isArchived: true,
          color: 'ABC123',
          type: TagType.project,
        );

        final query = GetTagQuery(id: tagId);

        when(mockTagRepository.getById(tagId)).thenAnswer((_) async => tag);

        // Act
        final result = await handler(query);

        // Assert
        expect(result.id, equals(tagId));
        expect(result.name, equals('Complete Tag'));
        expect(result.isArchived, isTrue);
        expect(result.color, equals('ABC123'));
        expect(result.type, equals(TagType.project));
        expect(result.createdDate, equals(now));
        expect(result.modifiedDate, equals(now));
        expect(result.deletedDate, isNull);
      });
    });

    group('Tag Not Found', () {
      test('should throw BusinessException when tag does not exist', () async {
        // Arrange
        const tagId = 'non-existent-tag';
        final query = GetTagQuery(id: tagId);

        when(mockTagRepository.getById(tagId)).thenAnswer((_) async => null);

        // Act & Assert
        expect(
          () => handler(query),
          throwsA(
            predicate((e) => e is BusinessException && e.message.contains('Tag not found')),
          ),
        );
        verify(mockTagRepository.getById(tagId)).called(1);
      });
    });

    group('Type Field Preservation', () {
      test('should preserve label type from repository', () async {
        // Arrange
        const tagId = 'tag-label';
        final tag = Tag(
          id: tagId,
          createdDate: DateTime.now().toUtc(),
          name: 'Label Tag',
          type: TagType.label,
        );

        final query = GetTagQuery(id: tagId);

        when(mockTagRepository.getById(tagId)).thenAnswer((_) async => tag);

        // Act
        final result = await handler(query);

        // Assert
        expect(result.type, equals(TagType.label));
      });

      test('should preserve context type from repository', () async {
        // Arrange
        const tagId = 'tag-context';
        final tag = Tag(
          id: tagId,
          createdDate: DateTime.now().toUtc(),
          name: 'Context Tag',
          type: TagType.context,
        );

        final query = GetTagQuery(id: tagId);

        when(mockTagRepository.getById(tagId)).thenAnswer((_) async => tag);

        // Act
        final result = await handler(query);

        // Assert
        expect(result.type, equals(TagType.context));
      });

      test('should preserve project type from repository', () async {
        // Arrange
        const tagId = 'tag-project';
        final tag = Tag(
          id: tagId,
          createdDate: DateTime.now().toUtc(),
          name: 'Project Tag',
          type: TagType.project,
        );

        final query = GetTagQuery(id: tagId);

        when(mockTagRepository.getById(tagId)).thenAnswer((_) async => tag);

        // Act
        final result = await handler(query);

        // Assert
        expect(result.type, equals(TagType.project));
      });
    });

    group('Optional Fields', () {
      test('should return tag with null color', () async {
        // Arrange
        const tagId = 'tag-1';
        final tag = Tag(
          id: tagId,
          createdDate: DateTime.now().toUtc(),
          name: 'No Color Tag',
          color: null,
          type: TagType.label,
        );

        final query = GetTagQuery(id: tagId);

        when(mockTagRepository.getById(tagId)).thenAnswer((_) async => tag);

        // Act
        final result = await handler(query);

        // Assert
        expect(result.color, isNull);
      });

      test('should return tag with null modifiedDate', () async {
        // Arrange
        const tagId = 'tag-1';
        final tag = Tag(
          id: tagId,
          createdDate: DateTime.now().toUtc(),
          modifiedDate: null,
          name: 'Unmodified Tag',
          type: TagType.label,
        );

        final query = GetTagQuery(id: tagId);

        when(mockTagRepository.getById(tagId)).thenAnswer((_) async => tag);

        // Act
        final result = await handler(query);

        // Assert
        expect(result.modifiedDate, isNull);
      });

      test('should return tag with null deletedDate', () async {
        // Arrange
        const tagId = 'tag-1';
        final tag = Tag(
          id: tagId,
          createdDate: DateTime.now().toUtc(),
          deletedDate: null,
          name: 'Active Tag',
          type: TagType.label,
        );

        final query = GetTagQuery(id: tagId);

        when(mockTagRepository.getById(tagId)).thenAnswer((_) async => tag);

        // Act
        final result = await handler(query);

        // Assert
        expect(result.deletedDate, isNull);
      });

      test('should return archived tag when isArchived is true', () async {
        // Arrange
        const tagId = 'tag-1';
        final tag = Tag(
          id: tagId,
          createdDate: DateTime.now().toUtc(),
          name: 'Archived Tag',
          isArchived: true,
          type: TagType.label,
        );

        final query = GetTagQuery(id: tagId);

        when(mockTagRepository.getById(tagId)).thenAnswer((_) async => tag);

        // Act
        final result = await handler(query);

        // Assert
        expect(result.isArchived, isTrue);
      });
    });

    group('Error Handling', () {
      test('should propagate repository exceptions', () async {
        // Arrange
        const tagId = 'tag-1';
        final query = GetTagQuery(id: tagId);

        when(mockTagRepository.getById(tagId)).thenThrow(
          Exception('Database connection error'),
        );

        // Act & Assert
        expect(
          () => handler(query),
          throwsException,
        );
        verify(mockTagRepository.getById(tagId)).called(1);
      });
    });

    group('Response Type', () {
      test('should return GetTagQueryResponse instance', () async {
        // Arrange
        const tagId = 'tag-1';
        final tag = Tag(
          id: tagId,
          createdDate: DateTime.now().toUtc(),
          name: 'Work',
          type: TagType.label,
        );

        final query = GetTagQuery(id: tagId);

        when(mockTagRepository.getById(tagId)).thenAnswer((_) async => tag);

        // Act
        final result = await handler(query);

        // Assert
        expect(result, isA<GetTagQueryResponse>());
        expect(result.id, equals(tagId));
      });
    });
  });
}
