import 'package:equatable/equatable.dart';

class TagListItem extends Equatable {
  final String tagId;
  final String tagName;
  final String? tagColor;

  const TagListItem({
    required this.tagId,
    required this.tagName,
    this.tagColor,
  });

  @override
  List<Object?> get props => [tagId, tagName, tagColor];
}

class NoteListItem extends Equatable {
  final String id;
  final String title;
  final String? content;
  final List<TagListItem> tags;
  final DateTime createdDate;
  final DateTime? modifiedDate;
  final String? groupName;

  const NoteListItem({
    required this.id,
    required this.title,
    this.content,
    this.tags = const [],
    required this.createdDate,
    this.modifiedDate,
    this.groupName,
  });

  DateTime? get updatedAt => modifiedDate;

  NoteListItem copyWith({
    String? id,
    String? title,
    String? content,
    List<TagListItem>? tags,
    DateTime? createdDate,
    DateTime? modifiedDate,
    String? groupName,
  }) {
    return NoteListItem(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      groupName: groupName ?? this.groupName,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        content,
        tags,
        createdDate,
        modifiedDate,
        groupName,
      ];
}
