import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habits_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_tags_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_records_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/habits/models/habit_sort_fields.dart';

void main() {
  group('Habit Queries Integration Tests', () {
    late AppDatabase database;
    late DriftHabitRepository habitRepository;
    late DriftHabitTagRepository habitTagsRepository;
    late DriftHabitRecordRepository habitRecordRepository;
    late GetListHabitsQueryHandler getListHabitsHandler;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() async {
      database = AppDatabase.forTesting();
      habitRepository = DriftHabitRepository.withDatabase(database);
      habitTagsRepository = DriftHabitTagRepository.withDatabase(database);
      habitRecordRepository = DriftHabitRecordRepository.withDatabase(database);

      getListHabitsHandler = GetListHabitsQueryHandler(
        habitRepository: habitRepository,
        habitTagRepository: habitTagsRepository,
        habitRecordRepository: habitRecordRepository,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('should sort habits locally by name case-insensitively', () async {
      final habit1 = Habit(
        id: '1',
        name: 'Apple',
        createdDate: DateTime.now(),
        description: '',
      );
      final habit2 = Habit(
        id: '2',
        name: 'Banana',
        createdDate: DateTime.now(),
        description: '',
      );
      final habit3 = Habit(
        id: '3',
        name: 'apple 2',
        createdDate: DateTime.now(),
        description: '',
      );
      final habit4 = Habit(
        id: '4',
        name: 'card',
        createdDate: DateTime.now(),
        description: '',
      );

      await habitRepository.add(habit1);
      await habitRepository.add(habit2);
      await habitRepository.add(habit3);
      await habitRepository.add(habit4);

      final query = GetListHabitsQuery(
        pageIndex: 0,
        pageSize: 10,
        sortBy: [SortOption(field: HabitSortFields.name, direction: SortDirection.asc)],
        sortByCustomSort: false,
      );

      final result = await getListHabitsHandler(query);

      expect(result.items.length, 4);
      expect(result.items[0].name, 'Apple');
      expect(result.items[1].name, 'apple 2');
      expect(result.items[2].name, 'Banana');
      expect(result.items[3].name, 'card');

      // Verify group names are correct
      expect(result.items[0].groupName, 'A');
      expect(result.items[1].groupName, 'A');
      expect(result.items[2].groupName, 'B');
      expect(result.items[3].groupName, 'C');
    });
  });
}
