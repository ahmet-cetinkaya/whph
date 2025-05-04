import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/notes/components/note_delete_button.dart';
import 'package:whph/presentation/features/notes/components/note_details_content.dart';
import 'package:whph/presentation/features/notes/constants/note_translation_keys.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

class NoteDetailsPage extends StatefulWidget {
  static const String route = '/notes/details';
  final String noteId;

  const NoteDetailsPage({super.key, required this.noteId});

  @override
  State<NoteDetailsPage> createState() => _NoteDetailsPageState();
}

class _NoteDetailsPageState extends State<NoteDetailsPage> {
  final _translationService = container.resolve<ITranslationService>();
  String _title = '';

  void _refreshTitle(String title) {
    if (mounted) {
      setState(() {
        _title = title;
      });
    }
  }

  void _handleNoteDeleted() {
    // Navigate back to notes list after deletion
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      appBarTitle: Text(_title.isNotEmpty ? _title : _translationService.translate(NoteTranslationKeys.noteDetails)),
      appBarActions: [
        NoteDeleteButton(
          noteId: widget.noteId,
          onDeleteSuccess: _handleNoteDeleted,
          buttonColor: AppTheme.primaryColor,
        ),
      ],
      builder: (context) => SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: NoteDetailsContent(
              noteId: widget.noteId,
              onTitleUpdated: _refreshTitle,
            ),
          ),
        ),
      ),
    );
  }
}
