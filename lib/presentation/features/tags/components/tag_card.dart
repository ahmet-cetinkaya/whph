import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/main.dart';

class TagCard extends StatelessWidget {
  final TagListItem tag;
  final VoidCallback onOpenDetails;

  final Mediator mediator = container.resolve<Mediator>();

  TagCard({super.key, required this.tag, required this.onOpenDetails});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        leading: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.label),
        ),
        title: Text(tag.name),
        onTap: onOpenDetails,
      ),
    );
  }
}
