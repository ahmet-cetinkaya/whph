import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/commands/add_app_usage_tag_command.dart';
import 'package:whph/application/features/app_usages/commands/remove_tag_tag_command.dart';
import 'package:whph/application/features/app_usages/queries/get_list_app_usage_tags_query.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';
import 'package:whph/presentation/features/shared/models/dropdown_option.dart';

class AppUsageCard extends StatefulWidget {
  final AppUsage appUsage;
  final Mediator mediator;

  const AppUsageCard({
    super.key,
    required this.appUsage,
    required this.mediator,
  });

  @override
  State<AppUsageCard> createState() => _AppUsageCardState();
}

class _AppUsageCardState extends State<AppUsageCard> {
  late Future<GetListAppUsageTagsQueryResponse> _appUsageTagsFuture;
  late Future<GetListTagsQueryResponse> _allTagsFuture;
  List<DropdownOption<int?>> _tagOptions = [];

  @override
  void initState() {
    super.initState();
    _appUsageTagsFuture = _fetchAppUsageTags();
    _allTagsFuture = _fetchAllTags();
  }

  Future<GetListAppUsageTagsQueryResponse> _fetchAppUsageTags() async {
    var query = GetListAppUsageTagsQuery(
      appUsageId: widget.appUsage.id,
      pageIndex: 0,
      pageSize: 100,
    );
    return await widget.mediator.send<GetListAppUsageTagsQuery, GetListAppUsageTagsQueryResponse>(query);
  }

  Future<GetListTagsQueryResponse> _fetchAllTags() async {
    var query = GetListTagsQuery(pageIndex: 0, pageSize: 100);
    // add lazy loading
    return await widget.mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(query);
  }

  Future<void> _addAppUsageTag(int tagId) async {
    var command = AddAppUsageTagCommand(
      appUsageId: widget.appUsage.id,
      tagId: tagId,
    );
    await widget.mediator.send<AddAppUsageTagCommand, AddAppUsageTagCommandResponse>(command);
    setState(() {
      _appUsageTagsFuture = _fetchAppUsageTags(); // Refresh tags
    });
  }

  Future<void> _removeAppUsageTag(String tagId) async {
    var command = RemoveAppUsageTagCommand(id: tagId);
    await widget.mediator.send<RemoveAppUsageTagCommand, RemoveAppUsageTagCommandResponse>(command);
    setState(() {
      _appUsageTagsFuture = _fetchAppUsageTags(); // Refresh tags
    });
  }

  Widget _buildHeader() {
    return Text(
      widget.appUsage.title,
      style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildDuration() {
    final durationInMinutes = (widget.appUsage.duration / Duration.secondsPerMinute).roundToDouble();
    return Text(
      "$durationInMinutes minutes",
      style: const TextStyle(fontSize: 14.0, color: Colors.grey),
    );
  }

  Widget _buildTagChips(List<AppUsageTagListItem> tags) {
    return Wrap(
      spacing: 6.0,
      runSpacing: 6.0,
      children: tags.map((tag) {
        return Chip(
          label: Text(tag.tagName),
          backgroundColor: Colors.blue.shade100,
          onDeleted: () => _removeAppUsageTag(tag.id),
        );
      }).toList(),
    );
  }

  Widget _buildTagDropdown(List<DropdownOption<int?>> options) {
    return DropdownButton<int?>(
      items: options.map((option) {
        return DropdownMenuItem<int?>(
          value: option.value,
          child: Text(option.label),
        );
      }).toList(),
      onChanged: (int? tagId) {
        if (tagId != null) {
          _addAppUsageTag(tagId);
        }
      },
    );
  }

  Widget _buildTagSection() {
    return FutureBuilder<GetListAppUsageTagsQueryResponse>(
      future: _appUsageTagsFuture,
      builder: (context, tagsSnapshot) {
        if (tagsSnapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (tagsSnapshot.hasError) {
          return Text("Tags error: ${tagsSnapshot.error}");
        }

        final tags = tagsSnapshot.data?.items ?? [];

        return FutureBuilder<GetListTagsQueryResponse>(
          future: _allTagsFuture,
          builder: (context, allTagsSnapshot) {
            if (allTagsSnapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            if (allTagsSnapshot.hasError) {
              return Text("Tags error: ${allTagsSnapshot.error}");
            }

            _tagOptions = [
              DropdownOption(label: 'Add new', value: null),
              ...allTagsSnapshot.data!.items
                  .where((tag) => !tags.any((t) => t.tagId == tag.id))
                  .map((tag) => DropdownOption(label: tag.name, value: tag.id)),
            ];

            // Check if there are available options for the dropdown
            final showDropdown = _tagOptions.length > 1; // 1 because of 'Add new'

            return Row(
              children: [
                Expanded(child: _buildTagChips(tags)),
                if (showDropdown) _buildTagDropdown(_tagOptions),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 8.0),
            _buildDuration(),
            const SizedBox(height: 8.0),
            _buildTagSection(),
          ],
        ),
      ),
    );
  }
}
