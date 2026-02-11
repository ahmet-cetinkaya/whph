import 'package:equatable/equatable.dart';
import 'package:domain/features/tags/tag.dart';

class TagListItem extends Equatable {
  final String tagId;
  final String tagName;
  final String? tagColor;
  final TagType tagType;
  final int tagOrder;

  const TagListItem({
    required this.tagId,
    required this.tagName,
    this.tagColor,
    this.tagType = TagType.label,
    this.tagOrder = 0,
  });

  @override
  List<Object?> get props => [tagId, tagName, tagColor, tagType, tagOrder];
}

class NoteListItem extends Equatable {
  final String id;
  final String title;
  final String? content;
  final List<TagListItem> tags;
  final DateTime createdDate;
  final DateTime? modifiedDate;
  final String? groupName;
  final bool isGroupNameTranslatable;

  const NoteListItem({
    required this.id,
    required this.title,
    this.content,
    this.tags = const [],
    required this.createdDate,
    this.modifiedDate,
    this.groupName,
    this.isGroupNameTranslatable = true,
  });

  DateTime? get updatedAt => modifiedDate;

  NoteListItem copyWith({
    String? id,
    String? title,
    Object? content = _sentinel,
    List<TagListItem>? tags,
    DateTime? createdDate,
    Object? modifiedDate = _sentinel,
    Object? groupName = _sentinel,
    bool? isGroupNameTranslatable,
  }) {
    return NoteListItem(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content == _sentinel ? this.content : content as String?,
      tags: tags ?? this.tags,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate == _sentinel ? this.modifiedDate : modifiedDate as DateTime?,
      groupName: groupName == _sentinel ? this.groupName : groupName as String?,
      isGroupNameTranslatable: isGroupNameTranslatable ?? this.isGroupNameTranslatable,
    );
  }

  static const _sentinel = Object();

  @override
  List<Object?> get props => [
        id,
        title,
        content,
        tags,
        createdDate,
        modifiedDate,
        groupName,
        isGroupNameTranslatable,
      ];
}
