import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/features/notes/components/note_delete_button.dart';
import 'package:whph/features/notes/components/note_details_content.dart';
import 'package:whph/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/shared/constants/app_theme.dart';

class NoteDetailsPage extends StatefulWidget {
  static const String route = '/notes/details';
  final String noteId;

  const NoteDetailsPage({super.key, required this.noteId});

  @override
  State<NoteDetailsPage> createState() => _NoteDetailsPageState();
}

class _NoteDetailsPageState extends State<NoteDetailsPage> {
  final _themeService = container.resolve<IThemeService>();
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
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        actions: [
          NoteDeleteButton(
            noteId: widget.noteId,
            onDeleted: _handleNoteDeleted,
            buttonColor: _themeService.primaryColor,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: context.pageBodyPadding,
          child: NoteDetailsContent(
            noteId: widget.noteId,
          ),
        ),
      ),
    );
  }
}
