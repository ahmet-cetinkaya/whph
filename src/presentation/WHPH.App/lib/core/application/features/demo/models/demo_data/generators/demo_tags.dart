import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/application/features/demo/constants/demo_translation_keys.dart';

/// Demo tag data generator
class DemoTags {
  /// Demo tags using translation function
  static List<Tag> getTags(String Function(String) translate) => [
        Tag(
          id: KeyHelper.generateStringId(),
          name: translate(DemoTranslationKeys.tagWork),
          color: 'FF6B6B',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 30)),
          type: TagType.label,
        ),
        Tag(
          id: KeyHelper.generateStringId(),
          name: translate(DemoTranslationKeys.tagPersonal),
          color: '4ECDC4',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 29)),
          type: TagType.label,
        ),
        Tag(
          id: KeyHelper.generateStringId(),
          name: translate(DemoTranslationKeys.tagHealth),
          color: '45B7D1',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 28)),
          type: TagType.label,
        ),
        Tag(
          id: KeyHelper.generateStringId(),
          name: translate(DemoTranslationKeys.tagLearning),
          color: '96CEB4',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 27)),
          type: TagType.label,
        ),
        Tag(
          id: KeyHelper.generateStringId(),
          name: translate(DemoTranslationKeys.tagEntertainment),
          color: 'FD79A8',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 25)),
          type: TagType.label,
        ),
        Tag(
          id: KeyHelper.generateStringId(),
          name: translate(DemoTranslationKeys.tagSocial),
          color: '00B894',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 24)),
          type: TagType.label,
        ),
        Tag(
          id: KeyHelper.generateStringId(),
          name: translate(DemoTranslationKeys.tagHome),
          color: 'A29BFE',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 23)),
          type: TagType.context,
        ),
        Tag(
          id: KeyHelper.generateStringId(),
          name: translate(DemoTranslationKeys.tagOffice),
          color: '6C5CE7',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 22)),
          type: TagType.context,
        ),
        Tag(
          id: KeyHelper.generateStringId(),
          name: translate(DemoTranslationKeys.tagProjectWHPH),
          color: '00CEC9',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 21)),
          type: TagType.project,
        ),
        Tag(
          id: KeyHelper.generateStringId(),
          name: translate(DemoTranslationKeys.tagMarket),
          color: '55E6C1',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 19)),
          type: TagType.context,
        ),
      ];
}
