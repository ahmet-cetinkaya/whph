import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';

/// Demo tag data generator
class DemoTags {
  /// Demo tags to be created
  static List<Tag> get tags => [
        Tag(
          id: KeyHelper.generateStringId(),
          name: 'Work',
          color: 'FF6B6B',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 30)),
        ),
        Tag(
          id: KeyHelper.generateStringId(),
          name: 'Personal',
          color: '4ECDC4',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 29)),
        ),
        Tag(
          id: KeyHelper.generateStringId(),
          name: 'Health',
          color: '45B7D1',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 28)),
        ),
        Tag(
          id: KeyHelper.generateStringId(),
          name: 'Learning',
          color: '96CEB4',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 27)),
        ),
        Tag(
          id: KeyHelper.generateStringId(),
          name: 'Finance',
          color: 'FFEAA7',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 26)),
        ),
        Tag(
          id: KeyHelper.generateStringId(),
          name: 'Entertainment',
          color: 'FD79A8',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 25)),
        ),
        Tag(
          id: KeyHelper.generateStringId(),
          name: 'Social',
          color: '00B894',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 24)),
        ),
      ];
}
