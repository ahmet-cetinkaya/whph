import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/domain/features/tags/tag.dart';

void main() {
  group('TagType Enum Tests', () {
    group('value getter', () {
      test('should return "label" for TagType.label', () {
        expect(TagType.label.value, equals('label'));
      });

      test('should return "context" for TagType.context', () {
        expect(TagType.context.value, equals('context'));
      });

      test('should return "project" for TagType.project', () {
        expect(TagType.project.value, equals('project'));
      });
    });

    group('fromString method', () {
      test('should parse "label" string to TagType.label', () {
        expect(TagType.fromString('label'), equals(TagType.label));
      });

      test('should parse "context" string to TagType.context', () {
        expect(TagType.fromString('context'), equals(TagType.context));
      });

      test('should parse "project" string to TagType.project', () {
        expect(TagType.fromString('project'), equals(TagType.project));
      });

      test('should default to TagType.label for invalid string', () {
        expect(TagType.fromString('invalid'), equals(TagType.label));
      });

      test('should default to TagType.label for empty string', () {
        expect(TagType.fromString(''), equals(TagType.label));
      });
    });
  });

  group('Tag Entity Tests', () {
    group('fromJson - type field parsing', () {
      test('should parse valid "label" string type', () {
        final json = {
          'id': 'tag-1',
          'createdDate': DateTime.now().toIso8601String(),
          'name': 'Work',
          'isArchived': false,
          'type': 'label',
        };

        final tag = Tag.fromJson(json);

        expect(tag.type, equals(TagType.label));
      });

      test('should parse valid "context" string type', () {
        final json = {
          'id': 'tag-1',
          'createdDate': DateTime.now().toIso8601String(),
          'name': 'Home',
          'isArchived': false,
          'type': 'context',
        };

        final tag = Tag.fromJson(json);

        expect(tag.type, equals(TagType.context));
      });

      test('should parse valid "project" string type', () {
        final json = {
          'id': 'tag-1',
          'createdDate': DateTime.now().toIso8601String(),
          'name': 'Website',
          'isArchived': false,
          'type': 'project',
        };

        final tag = Tag.fromJson(json);

        expect(tag.type, equals(TagType.project));
      });

      test('should parse int type 0 as TagType.label', () {
        final json = {
          'id': 'tag-1',
          'createdDate': DateTime.now().toIso8601String(),
          'name': 'Work',
          'isArchived': false,
          'type': 0,
        };

        final tag = Tag.fromJson(json);

        expect(tag.type, equals(TagType.label));
      });

      test('should parse int type 1 as TagType.context', () {
        final json = {
          'id': 'tag-1',
          'createdDate': DateTime.now().toIso8601String(),
          'name': 'Home',
          'isArchived': false,
          'type': 1,
        };

        final tag = Tag.fromJson(json);

        expect(tag.type, equals(TagType.context));
      });

      test('should parse int type 2 as TagType.project', () {
        final json = {
          'id': 'tag-1',
          'createdDate': DateTime.now().toIso8601String(),
          'name': 'Website',
          'isArchived': false,
          'type': 2,
        };

        final tag = Tag.fromJson(json);

        expect(tag.type, equals(TagType.project));
      });

      test('should default to TagType.label when type is null', () {
        final json = {
          'id': 'tag-1',
          'createdDate': DateTime.now().toIso8601String(),
          'name': 'Work',
          'isArchived': false,
          'type': null,
        };

        final tag = Tag.fromJson(json);

        expect(tag.type, equals(TagType.label));
      });

      test('should default to TagType.label when type field is missing', () {
        final json = {
          'id': 'tag-1',
          'createdDate': DateTime.now().toIso8601String(),
          'name': 'Work',
          'isArchived': false,
        };

        final tag = Tag.fromJson(json);

        expect(tag.type, equals(TagType.label));
      });

      test('should default to TagType.label for invalid int value', () {
        final json = {
          'id': 'tag-1',
          'createdDate': DateTime.now().toIso8601String(),
          'name': 'Work',
          'isArchived': false,
          'type': 999,
        };

        final tag = Tag.fromJson(json);

        expect(tag.type, equals(TagType.label));
      });

      test('should default to TagType.label for invalid string value', () {
        final json = {
          'id': 'tag-1',
          'createdDate': DateTime.now().toIso8601String(),
          'name': 'Work',
          'isArchived': false,
          'type': 'invalid_type',
        };

        final tag = Tag.fromJson(json);

        expect(tag.type, equals(TagType.label));
      });

      test('should default to TagType.label for negative int value', () {
        final json = {
          'id': 'tag-1',
          'createdDate': DateTime.now().toIso8601String(),
          'name': 'Work',
          'isArchived': false,
          'type': -1,
        };

        final tag = Tag.fromJson(json);

        expect(tag.type, equals(TagType.label));
      });
    });

    group('toJson - type field serialization', () {
      test('should serialize TagType.label as "label" string', () {
        final tag = Tag(
          id: 'tag-1',
          createdDate: DateTime.now().toUtc(),
          name: 'Work',
          type: TagType.label,
        );

        final json = tag.toJson();

        expect(json['type'], equals('label'));
      });

      test('should serialize TagType.context as "context" string', () {
        final tag = Tag(
          id: 'tag-1',
          createdDate: DateTime.now().toUtc(),
          name: 'Home',
          type: TagType.context,
        );

        final json = tag.toJson();

        expect(json['type'], equals('context'));
      });

      test('should serialize TagType.project as "project" string', () {
        final tag = Tag(
          id: 'tag-1',
          createdDate: DateTime.now().toUtc(),
          name: 'Website',
          type: TagType.project,
        );

        final json = tag.toJson();

        expect(json['type'], equals('project'));
      });
    });

    group('Round-trip serialization', () {
      test('should preserve TagType.label through toJson/fromJson cycle', () {
        final original = Tag(
          id: 'tag-1',
          createdDate: DateTime.now().toUtc(),
          name: 'Work',
          color: 'FF0000',
          type: TagType.label,
        );

        final json = original.toJson();
        final restored = Tag.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.name, equals(original.name));
        expect(restored.color, equals(original.color));
        expect(restored.type, equals(TagType.label));
      });

      test('should preserve TagType.context through toJson/fromJson cycle', () {
        final original = Tag(
          id: 'tag-1',
          createdDate: DateTime.now().toUtc(),
          name: 'Home',
          color: '00FF00',
          type: TagType.context,
        );

        final json = original.toJson();
        final restored = Tag.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.name, equals(original.name));
        expect(restored.color, equals(original.color));
        expect(restored.type, equals(TagType.context));
      });

      test('should preserve TagType.project through toJson/fromJson cycle', () {
        final original = Tag(
          id: 'tag-1',
          createdDate: DateTime.now().toUtc(),
          name: 'Website',
          color: '0000FF',
          type: TagType.project,
        );

        final json = original.toJson();
        final restored = Tag.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.name, equals(original.name));
        expect(restored.color, equals(original.color));
        expect(restored.type, equals(TagType.project));
      });
    });

    group('Default values', () {
      test('should use TagType.label as default type when creating Tag', () {
        final tag = Tag(
          id: 'tag-1',
          createdDate: DateTime.now().toUtc(),
          name: 'Work',
        );

        expect(tag.type, equals(TagType.label));
      });

      test('should use false as default isArchived when creating Tag', () {
        final tag = Tag(
          id: 'tag-1',
          createdDate: DateTime.now().toUtc(),
          name: 'Work',
        );

        expect(tag.isArchived, isFalse);
      });

      test('should use null as default color when creating Tag', () {
        final tag = Tag(
          id: 'tag-1',
          createdDate: DateTime.now().toUtc(),
          name: 'Work',
        );

        expect(tag.color, isNull);
      });
    });

    group('Complete tag with all fields', () {
      test('should create complete Tag with all fields', () {
        final now = DateTime.now().toUtc();
        final tag = Tag(
          id: 'tag-1',
          createdDate: now,
          modifiedDate: now,
          deletedDate: null,
          name: 'Complete Tag',
          isArchived: true,
          color: 'ABC123',
          type: TagType.project,
        );

        expect(tag.id, equals('tag-1'));
        expect(tag.name, equals('Complete Tag'));
        expect(tag.isArchived, isTrue);
        expect(tag.color, equals('ABC123'));
        expect(tag.type, equals(TagType.project));
        expect(tag.createdDate, equals(now));
        expect(tag.modifiedDate, equals(now));
        expect(tag.deletedDate, isNull);
      });

      test('should serialize and deserialize complete Tag correctly', () {
        final now = DateTime.now().toUtc();
        final original = Tag(
          id: 'tag-1',
          createdDate: now,
          modifiedDate: now,
          deletedDate: null,
          name: 'Complete Tag',
          isArchived: true,
          color: 'ABC123',
          type: TagType.context,
        );

        final json = original.toJson();
        final restored = Tag.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.name, equals(original.name));
        expect(restored.isArchived, equals(original.isArchived));
        expect(restored.color, equals(original.color));
        expect(restored.type, equals(original.type));
        expect(restored.createdDate.toIso8601String(), equals(original.createdDate.toIso8601String()));
        expect(restored.modifiedDate!.toIso8601String(), equals(original.modifiedDate!.toIso8601String()));
      });
    });

    group('Edge cases and error handling', () {
      test('should handle missing optional fields in JSON', () {
        final json = {
          'id': 'tag-1',
          'createdDate': DateTime.now().toIso8601String(),
          'name': 'Minimal Tag',
        };

        final tag = Tag.fromJson(json);

        expect(tag.id, equals('tag-1'));
        expect(tag.name, equals('Minimal Tag'));
        expect(tag.isArchived, isFalse); // default
        expect(tag.color, isNull);
        expect(tag.type, equals(TagType.label)); // default
      });

      test('should handle null modifiedDate in JSON', () {
        final json = {
          'id': 'tag-1',
          'createdDate': DateTime.now().toIso8601String(),
          'modifiedDate': null,
          'name': 'Tag',
        };

        final tag = Tag.fromJson(json);

        expect(tag.modifiedDate, isNull);
      });

      test('should handle null deletedDate in JSON', () {
        final json = {
          'id': 'tag-1',
          'createdDate': DateTime.now().toIso8601String(),
          'deletedDate': null,
          'name': 'Tag',
        };

        final tag = Tag.fromJson(json);

        expect(tag.deletedDate, isNull);
      });

      test('should handle null color in JSON', () {
        final json = {
          'id': 'tag-1',
          'createdDate': DateTime.now().toIso8601String(),
          'color': null,
          'name': 'Tag',
        };

        final tag = Tag.fromJson(json);

        expect(tag.color, isNull);
      });

      test('should handle all three tag types in a list', () {
        final tagsJson = [
          {
            'id': 'tag-1',
            'createdDate': DateTime.now().toIso8601String(),
            'name': 'Label Tag',
            'type': 'label',
          },
          {
            'id': 'tag-2',
            'createdDate': DateTime.now().toIso8601String(),
            'name': 'Context Tag',
            'type': 'context',
          },
          {
            'id': 'tag-3',
            'createdDate': DateTime.now().toIso8601String(),
            'name': 'Project Tag',
            'type': 'project',
          },
        ];

        final tags = tagsJson.map((json) => Tag.fromJson(json)).toList();

        expect(tags[0].type, equals(TagType.label));
        expect(tags[1].type, equals(TagType.context));
        expect(tags[2].type, equals(TagType.project));
      });
    });
  });
}
