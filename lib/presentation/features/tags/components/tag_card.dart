import 'package:flutter/material.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';

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
        leading: const Icon(
          Icons.label,
          size: AppTheme.fontSizeLarge,
        ),
        title: Text(tag.name),
        onTap: onOpenDetails,
      ),
    );
  }
}
