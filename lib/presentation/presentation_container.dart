import 'package:whph/core/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/core/acore/sounds/abstraction/sound_player/i_sound_player.dart';
import 'package:whph/presentation/features/app_usages/services/app_usages_service.dart';
import 'package:whph/presentation/features/habits/services/habits_service.dart';
import 'package:whph/presentation/features/notes/services/notes_service.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/services/translation_service.dart';
import 'package:whph/presentation/shared/utils/audio_player_sound_player.dart';
import 'package:whph/presentation/features/tasks/services/tasks_service.dart';

void registerPresentation(IContainer container) {
  container.registerSingleton<AppUsagesService>((_) => AppUsagesService());
  container.registerSingleton<HabitsService>((_) => HabitsService());
  container.registerSingleton<NotesService>((_) => NotesService());
  container.registerSingleton<TasksService>((_) => TasksService());
  container.registerSingleton<ISoundPlayer>((_) => AudioPlayerSoundPlayer());
  container.registerSingleton<ITranslationService>((_) => TranslationService());
}
