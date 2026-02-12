import 'package:domain/features/notes/note.dart';
import 'package:application/shared/utils/key_helper.dart';
import 'package:application/features/demo/constants/demo_translation_keys.dart';

/// Demo note data generator
class DemoNotes {
  /// Demo notes using translation function
  static List<Note> getNotes(String Function(String) translate) => [
        Note(
          id: KeyHelper.generateStringId(),
          title: translate(DemoTranslationKeys.noteMeetingTitle),
          content: translate(DemoTranslationKeys.noteMeetingContent),
          order: 1.0,
          createdDate: DateTime.now().subtract(const Duration(days: 2)),
        ),
        Note(
          id: KeyHelper.generateStringId(),
          title: translate(DemoTranslationKeys.noteBookTitle),
          content: translate(DemoTranslationKeys.noteBookContent),
          order: 2.0,
          createdDate: DateTime.now().subtract(const Duration(days: 5)),
        ),
        Note(
          id: KeyHelper.generateStringId(),
          title: translate(DemoTranslationKeys.noteRecipeTitle),
          content: translate(DemoTranslationKeys.noteRecipeContent),
          order: 3.0,
          createdDate: DateTime.now().subtract(const Duration(days: 8)),
        ),
        Note(
          id: KeyHelper.generateStringId(),
          title: translate(DemoTranslationKeys.noteTravelTitle),
          content: translate(DemoTranslationKeys.noteTravelContent),
          order: 4.0,
          createdDate: DateTime.now().subtract(const Duration(days: 12)),
        ),
        Note(
          id: KeyHelper.generateStringId(),
          title: translate(DemoTranslationKeys.noteWeeklyGoalsTitle),
          content: translate(DemoTranslationKeys.noteWeeklyGoalsContent),
          order: 5.0,
          createdDate: DateTime.now().subtract(const Duration(days: 3)),
        ),
        Note(
          id: KeyHelper.generateStringId(),
          title: translate(DemoTranslationKeys.noteProjectIdeasTitle),
          content: translate(DemoTranslationKeys.noteProjectIdeasContent),
          order: 6.0,
          createdDate: DateTime.now().subtract(const Duration(days: 6)),
        ),
        Note(
          id: KeyHelper.generateStringId(),
          title: translate(DemoTranslationKeys.noteInvestmentTitle),
          content: translate(DemoTranslationKeys.noteInvestmentContent),
          order: 7.0,
          createdDate: DateTime.now().subtract(const Duration(days: 9)),
        ),
        Note(
          id: KeyHelper.generateStringId(),
          title: translate(DemoTranslationKeys.noteWorkoutTitle),
          content: translate(DemoTranslationKeys.noteWorkoutContent),
          order: 8.0,
          createdDate: DateTime.now().subtract(const Duration(days: 4)),
        ),
        Note(
          id: KeyHelper.generateStringId(),
          title: translate(DemoTranslationKeys.noteLearningTitle),
          content: translate(DemoTranslationKeys.noteLearningContent),
          order: 9.0,
          createdDate: DateTime.now().subtract(const Duration(days: 7)),
        ),
        Note(
          id: KeyHelper.generateStringId(),
          title: translate(DemoTranslationKeys.noteBudgetTitle),
          content: translate(DemoTranslationKeys.noteBudgetContent),
          order: 10.0,
          createdDate: DateTime.now().subtract(const Duration(days: 15)),
        ),
      ];
}
