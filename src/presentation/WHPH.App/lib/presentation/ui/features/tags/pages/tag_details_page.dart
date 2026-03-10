import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_archive_button.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_delete_button.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_details_content.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/features/tags/services/tags_service.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_statistics_view.dart';

class TagDetailsPage extends StatefulWidget {
  static const String route = '/tags/details';
  final String tagId;

  const TagDetailsPage({super.key, required this.tagId});

  @override
  State<TagDetailsPage> createState() => _TagDetailsPageState();
}

class _TagDetailsPageState extends State<TagDetailsPage> {
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        actions: [
          TagArchiveButton(
            tagId: widget.tagId,
            onArchiveSuccess: _goBack,
            buttonColor: _themeService.primaryColor,
            tooltip: _translationService.translate(TagTranslationKeys.archiveTagTooltip),
          ),
          TagDeleteButton(
            tagId: widget.tagId,
            onDeleteSuccess: _goBack,
            buttonColor: _themeService.primaryColor,
            tooltip: _translationService.translate(TagTranslationKeys.deleteTagTooltip),
          ),
        ],
      ),
      body: Padding(
        padding: context.pageBodyPadding,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TagDetailsContent(
                tagId: widget.tagId,
                onTagUpdated: () {
                  final tagsService = container.resolve<TagsService>();
                  tagsService.notifyTagUpdated(widget.tagId);
                },
              ),
              const SizedBox(height: AppTheme.sizeSmall),
              TagStatisticsView(
                tagId: widget.tagId,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
