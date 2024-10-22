import 'package:flutter/material.dart';
import 'package:whph/presentation/features/shared/components/secondary_app_bar.dart';
import 'package:whph/presentation/features/tags/components/tag_details_content.dart';
import 'package:whph/presentation/features/tags/components/tag_name_input_field.dart';

class TagDetailsPage extends StatelessWidget {
  final String tagId;

  const TagDetailsPage({super.key, required this.tagId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SecondaryAppBar(
          context: context,
          title: TagNameInputField(
            id: tagId,
          )),
      body: TagDetailsContent(
        tagId: tagId,
      ),
    );
  }
}
