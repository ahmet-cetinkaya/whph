import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/notes/queries/get_note_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/notes/components/note_delete_button.dart';
import 'package:whph/presentation/features/notes/components/note_details_content.dart';
import 'package:whph/presentation/features/notes/constants/note_translation_keys.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';

class NoteDetailsPage extends StatefulWidget {
  static const String route = '/notes/details';
  final String noteId;

  const NoteDetailsPage({super.key, required this.noteId});

  @override
  State<NoteDetailsPage> createState() => _NoteDetailsPageState();
}

class _NoteDetailsPageState extends State<NoteDetailsPage> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  String _title = '';

  @override
  void initState() {
    super.initState();
    _loadNoteDetails();
  }

  Future<void> _loadNoteDetails() async {
    var query = await _mediator.send<GetNoteQuery, GetNoteQueryResponse>(
      GetNoteQuery(id: widget.noteId),
    );

    _refreshTitle(query.title);
  }

  void _refreshTitle(String title) {
    setState(() {
      _title = title;
    });
  }

  void _handleNoteDeleted() {
    // Navigate back to notes list after deletion
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title.isNotEmpty ? _title : _translationService.translate(NoteTranslationKeys.noteDetails)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
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
              onTitleUpdated: _refreshTitle,
            ),
          ),
        ),
      ),
    );
  }
}
