import 'package:flutter/material.dart';
import 'package:whph/presentation/features/notes/components/note_delete_button.dart';
import 'package:whph/presentation/features/notes/components/note_details_content.dart';
import 'package:whph/presentation/features/notes/constants/note_translation_keys.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';

class NoteDetailsPage extends StatefulWidget {
  static const String route = '/notes/details';
  final String noteId;

  const NoteDetailsPage({super.key, required this.noteId});

  @override
  State<NoteDetailsPage> createState() => _NoteDetailsPageState();
}

class _NoteDetailsPageState extends State<NoteDetailsPage> {
  void _handleNoteDeleted() {
    Navigator.of(context).pop();
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        actions: [
          NoteDeleteButton(
            noteId: widget.noteId,
            onDeleted: _handleNoteDeleted,
            buttonColor: AppTheme.primaryColor,
          ),
          HelpMenu(
            titleKey: NoteTranslationKeys.noteDetails,
            markdownContentKey: NoteTranslationKeys.helpContent,
          ),
          const SizedBox(width: 2),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: NoteDetailsContent(
              noteId: widget.noteId,
              onNoteUpdated: () {},
              onTitleUpdated: (_) {},
            ),
          ),
        ),
      ),
    );
  }
}
