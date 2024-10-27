import 'package:flutter/material.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';

class TagCard extends StatelessWidget {
  final TagListItem tag;
  final VoidCallback onOpenDetails;

  const TagCard({
    super.key,
    required this.tag,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(9.0),
        leading: const Icon(Icons.label),
        title: Text(tag.name),
        onTap: onOpenDetails,
      ),
    );
  }
}
