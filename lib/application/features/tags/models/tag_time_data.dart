import 'package:whph/application/features/tags/models/tag_time_category.dart';

class TagTimeData {
  final String tagId;
  final String tagName;
  final int duration;
  final TagTimeCategory category;
  final String? tagColor;

  const TagTimeData({
    required this.tagId,
    required this.tagName,
    required this.duration,
    required this.category,
    this.tagColor,
  });

  TagTimeData copyWith({
    String? tagId,
    String? tagName,
    int? duration,
    TagTimeCategory? category,
    String? tagColor,
  }) {
    return TagTimeData(
      tagId: tagId ?? this.tagId,
      tagName: tagName ?? this.tagName,
      duration: duration ?? this.duration,
      category: category ?? this.category,
      tagColor: tagColor ?? this.tagColor,
    );
  }
}
