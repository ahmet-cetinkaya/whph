import 'package:flutter/material.dart';
import 'package:whph/src/presentation/ui/features/notes/components/note_delete_button.dart';
import 'package:whph/src/presentation/ui/features/notes/components/note_details_content.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';

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
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
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
          const SizedBox(width: AppTheme.sizeSmall),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.sizeLarge),
          child: NoteDetailsContent(
            noteId: widget.noteId,
          ),
        ),
      ),
    );
  }
}
