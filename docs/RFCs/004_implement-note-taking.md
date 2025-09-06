# Implement Note-Taking Module

> RFC: 004
> Status: Implemented

## Summary

This RFC details the notes module in WHPH's architecture, utilizing core/application/features/notes/ for commands/queries/services. It provides rich text notes with markdown, tagging, search, and linking to tasks/habits using Flutter UI and Drift storage, enhancing knowledge organization in a privacy-focused, cross-platform setup.

## Motivation

Essential for documenting and linking ideas (PRD 3.1), notes support workflows (sections 4). Fills integrated local-first gaps, aligning with unified hub/privacy (PRD 1.3) via modular dependencies on tags and mapper modules.

## Detailed Design

Clean architecture: domain in core/domain/features/notes/, application layer in core/application/features/notes/, persistence via Drift in infrastructure/persistence/features/notes/, UI in presentation/ui/features/notes/. Key elements:

### Data Models

- **Note Entity** (core/domain/features/notes/models/note_model.dart): Fields: id (UUID), title (String), content (String, markdown), tags (List<String>), linkedTaskIds/linkedHabitIds (List<UUID>?), createdAt/updatedAt (DateTime).
- **Storage**: Drift (SQLite) tables with JSON tags/links; FTS5 for full-text search on content/title.

### UI Components

- **Note List View** (presentation/ui/features/notes/widgets/note_list_view.dart): ListView previews with snippets, tag chips, link indicators.
- **Note Editor**: RichTextField with markdown toolbar; @mentions auto-link tasks/habits.
- **Tag System**: Chip input; tag cloud sidebar, integrates with tags module.
- **Search Interface**: Autocomplete bar, highlighted results.
- **Linking**: Modal for selections; backlinks in footers.

### APIs and Logic

- **CRUD Operations**: Provider edits; saveNote() in notes_service.dart parses markdown, stores via Drift repo; loadNote() renders with flutter_markdown.
- **Search Functionality**: notes_queries.dart with FTS fuzzy matching; filters by tags/links.
- **Linking Logic**: Extract @patterns on save for foreign keys; bidirectional with tasks/habits.
- **Cross-Platform**: Keyboard formatting (desktop), touch editor (mobile).
- **Integration**: Depends on tags module for assignment, mapper for DTOs; sync for multi-device.

Trade-offs: Markdown limits rich text (no images); simplicity/portability prioritized. Local FTS fast to ~10k notes.

Assumptions: Uses drift for DB with FTS (infrastructure/persistence/shared/repositories/drift/); libraries flutter_markdown, markdown GPL-compatible. Offline conflicts resolved timestamp-based in sync module.

## Alternatives Considered

- **Plain Text**: Rejected for formatting (PRD rich text); markdown balances.
- **External Sync (Evernote)**: Avoided for privacy/open-source (PRD 5.1.3).
- **NoSQL (Sembast)**: SQLite FTS better for search; relational for linking.
- **No @Mentions**: Less intuitive; improves discoverability.

## Implementation Notes

Phases: 1) Models/DB FTS (Week 4), 2) Editor UI (Week 5), 3) Search/linking (Week 6), 4) Testing (Week 7). Challenges: Rendering consistency (unified package). Outcomes: Instant search 200+ notes; 92% coverage. Integrated with global search/themes/tags.

## References

- [PRD 3.1](https://github.com/ahmet-cetinkaya/whph/blob/ea71256c1/docs/PRD.md#L69-L74).
- [MODULES.md: Notes Module](https://github.com/ahmet-cetinkaya/whph/blob/ea71256c1/docs/MODULES.md#L134-L160).
- Flutter: [Markdown](https://pub.dev/packages/flutter_markdown).
- Drift FTS5: [Full-Text Search](https://drift.simonbinder.eu/docs/advanced-features/full-text-search/).

