import 'package:flutter_test/flutter_test.dart';
import 'package:whph/src/presentation/ui/shared/services/background_translation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackgroundTranslationService', () {
    late BackgroundTranslationService service;

    setUp(() {
      service = BackgroundTranslationService();
    });

    group('YAML Parsing', () {
      test('should parse simple YAML correctly', () {
        const yamlContent = '''
tasks:
  notifications:
    reminder_title: "Task Reminder: {title}"
    planned_message: "Your task is planned for {time}"
    deadline_title: "Task Deadline: {title}"
    deadline_message: "Your task deadline is at {time}"
  reminder:
    none: None
    atTime: At time
''';

        final result = service.parseSimpleYamlForTest(yamlContent);

        expect(result['tasks.notifications.reminder_title'], equals('Task Reminder: {title}'));
        expect(result['tasks.notifications.planned_message'], equals('Your task is planned for {time}'));
        expect(result['tasks.notifications.deadline_title'], equals('Task Deadline: {title}'));
        expect(result['tasks.notifications.deadline_message'], equals('Your task deadline is at {time}'));
        expect(result['tasks.reminder.none'], equals('None'));
        expect(result['tasks.reminder.atTime'], equals('At time'));
      });

      test('should parse Turkish YAML correctly', () {
        const yamlContent = '''
tasks:
  notifications:
    reminder_title: "Görev Hatırlatıcı: {title}"
    planned_message: "Göreviniz için planlanan zaman: {time}"
    deadline_title: "Görev Son Tarih: {title}"
    deadline_message: "Görevinizin son tarihi: {time}"
''';

        final result = service.parseSimpleYamlForTest(yamlContent);

        expect(result['tasks.notifications.reminder_title'], equals('Görev Hatırlatıcı: {title}'));
        expect(result['tasks.notifications.planned_message'], equals('Göreviniz için planlanan zaman: {time}'));
        expect(result['tasks.notifications.deadline_title'], equals('Görev Son Tarih: {title}'));
        expect(result['tasks.notifications.deadline_message'], equals('Görevinizin son tarihi: {time}'));
      });

      test('should handle complex nested structures', () {
        const yamlContent = '''
tasks:
  marathon:
    help:
      title: Marathon Mode Guide
      content: |
        This is a multiline content
        that should be ignored
  notifications:
    reminder_title: "Task Reminder: {title}"
  pomodoro:
    notifications:
      title: Pomodoro Timer
      break_completed: Break session completed!
''';

        final result = service.parseSimpleYamlForTest(yamlContent);

        expect(result['tasks.marathon.help.title'], equals('Marathon Mode Guide'));
        expect(result['tasks.notifications.reminder_title'], equals('Task Reminder: {title}'));
        expect(result['tasks.pomodoro.notifications.title'], equals('Pomodoro Timer'));
        expect(result['tasks.pomodoro.notifications.break_completed'], equals('Break session completed!'));

        // Multiline content should be ignored
        expect(result.containsKey('tasks.marathon.help.content'), isFalse);
      });

      test('should handle quotes correctly', () {
        const yamlContent = '''
tasks:
  notifications:
    title1: "Task Reminder: {title}"
    title2: 'Task Reminder: {title}'
    title3: Task Reminder: {title}
''';

        final result = service.parseSimpleYamlForTest(yamlContent);

        expect(result['tasks.notifications.title1'], equals('Task Reminder: {title}'));
        expect(result['tasks.notifications.title2'], equals('Task Reminder: {title}'));
        expect(result['tasks.notifications.title3'], equals('Task Reminder: {title}'));
      });

      test('should handle real YAML structure from tasks file', () {
        const yamlContent = '''
tasks:
  add_button:
    tooltip: Add new task
  all_tasks_done: All tasks completed!
  notifications:
    deadline_message: "Your task deadline is at {time}"
    deadline_title: "Task Deadline: {title}"
    planned_message: "Your task is planned for {time}"
    reminder_title: "Task Reminder: {title}"
  page:
    completed_tasks_title: Completed tasks
    title: Tasks
  pomodoro:
    notifications:
      break_completed: Break session completed!
      timer_completed: Timer completed!
      title: Pomodoro Timer
''';

        final result = service.parseSimpleYamlForTest(yamlContent);

        // Check notification keys specifically
        expect(result['tasks.notifications.reminder_title'], equals('Task Reminder: {title}'));
        expect(result['tasks.notifications.planned_message'], equals('Your task is planned for {time}'));
        expect(result['tasks.notifications.deadline_title'], equals('Task Deadline: {title}'));
        expect(result['tasks.notifications.deadline_message'], equals('Your task deadline is at {time}'));

        // Check other keys
        expect(result['tasks.add_button.tooltip'], equals('Add new task'));
        expect(result['tasks.all_tasks_done'], equals('All tasks completed!'));
        expect(result['tasks.pomodoro.notifications.break_completed'], equals('Break session completed!'));
      });
    });

    group('Translation with Arguments', () {
      test('should replace named arguments correctly', () {
        // Setup mock translation cache
        service.setTranslationCacheForTest({
          'en': {
            'tasks.notifications.reminder_title': 'Task Reminder: {title}',
            'tasks.notifications.planned_message': 'Your task is planned for {time}',
          }
        });
        service.setCurrentLocaleForTest('en');

        final result1 = service.translate(
          'tasks.notifications.reminder_title',
          namedArgs: {'title': 'Complete Project'},
        );
        expect(result1, equals('Task Reminder: Complete Project'));

        final result2 = service.translate(
          'tasks.notifications.planned_message',
          namedArgs: {'time': '14:30'},
        );
        expect(result2, equals('Your task is planned for 14:30'));
      });

      test('should handle multiple arguments', () {
        service.setTranslationCacheForTest({
          'en': {
            'test.message': 'Hello {name}, you have {count} messages',
          }
        });
        service.setCurrentLocaleForTest('en');

        final result = service.translate(
          'test.message',
          namedArgs: {'name': 'John', 'count': '5'},
        );
        expect(result, equals('Hello John, you have 5 messages'));
      });
    });

    group('Locale Fallback', () {
      test('should fallback to English when Turkish translation not found', () {
        service.setTranslationCacheForTest({
          'tr': {
            'tasks.notifications.reminder_title': 'Görev Hatırlatıcı: {title}',
          },
          'en': {
            'tasks.notifications.reminder_title': 'Task Reminder: {title}',
            'tasks.notifications.planned_message': 'Your task is planned for {time}',
          }
        });
        service.setCurrentLocaleForTest('tr');

        // Should find Turkish translation
        final result1 = service.translate('tasks.notifications.reminder_title');
        expect(result1, equals('Görev Hatırlatıcı: {title}'));

        // Should fallback to English
        final result2 = service.translate('tasks.notifications.planned_message');
        expect(result2, equals('Your task is planned for {time}'));
      });

      test('should return key when no translation found', () {
        service.setTranslationCacheForTest({
          'en': {
            'tasks.notifications.reminder_title': 'Task Reminder: {title}',
          }
        });
        service.setCurrentLocaleForTest('en');

        final result = service.translate('tasks.notifications.nonexistent_key');
        expect(result, equals('tasks.notifications.nonexistent_key'));
      });
    });

    group('Notification Translation Keys', () {
      test('should handle typical notification translation keys', () {
        service.setTranslationCacheForTest({
          'en': {
            'tasks.notifications.reminder_title': 'Task Reminder: {title}',
            'tasks.notifications.planned_message': 'Your task is planned for {time}',
            'tasks.notifications.deadline_title': 'Task Deadline: {title}',
            'tasks.notifications.deadline_message': 'Your task deadline is at {time}',
            'habits.notifications.reminder_title': 'Habit Reminder: {name}',
            'habits.notifications.reminder_message': 'Time for your habit: {name}',
          },
          'tr': {
            'tasks.notifications.reminder_title': 'Görev Hatırlatıcı: {title}',
            'tasks.notifications.planned_message': 'Göreviniz için planlanan zaman: {time}',
            'tasks.notifications.deadline_title': 'Görev Son Tarih: {title}',
            'tasks.notifications.deadline_message': 'Görevinizin son tarihi: {time}',
            'habits.notifications.reminder_title': 'Alışkanlık Hatırlatıcı: {name}',
            'habits.notifications.reminder_message': 'Alışkanlığınızın zamanı: {name}',
          }
        });

        // Test English translations
        service.setCurrentLocaleForTest('en');
        expect(service.translate('tasks.notifications.reminder_title', namedArgs: {'title': 'My Task'}),
            equals('Task Reminder: My Task'));
        expect(service.translate('tasks.notifications.planned_message', namedArgs: {'time': '15:30'}),
            equals('Your task is planned for 15:30'));

        // Test Turkish translations
        service.setCurrentLocaleForTest('tr');
        expect(service.translate('tasks.notifications.reminder_title', namedArgs: {'title': 'Benim Görevim'}),
            equals('Görev Hatırlatıcı: Benim Görevim'));
        expect(service.translate('habits.notifications.reminder_message', namedArgs: {'name': 'Egzersiz'}),
            equals('Alışkanlığınızın zamanı: Egzersiz'));
      });
    });

    group('Edge Cases', () {
      test('should handle empty YAML', () {
        const yamlContent = '';
        final result = service.parseSimpleYamlForTest(yamlContent);
        expect(result, isEmpty);
      });

      test('should handle YAML with only comments', () {
        const yamlContent = '''
# This is a comment
# Another comment
''';
        final result = service.parseSimpleYamlForTest(yamlContent);
        expect(result, isEmpty);
      });

      test('should handle malformed YAML gracefully', () {
        const yamlContent = '''
tasks:
  notifications
    reminder_title: "Task Reminder: {title}"
''';
        final result = service.parseSimpleYamlForTest(yamlContent);
        // Should not crash and should skip malformed lines
        // The malformed "notifications" line should be skipped,
        // but "reminder_title" should still be parsed with the "tasks" prefix
        expect(result.containsKey('tasks.reminder_title'), isTrue);
        expect(result['tasks.reminder_title'], equals('Task Reminder: {title}'));
      });

      test('should handle translation when cache is not initialized', () {
        // Clear cache to ensure we start fresh
        service.clearCacheForTest();
        service.setCurrentLocaleForTest('en');

        final result = service.translate('tasks.notifications.reminder_title');
        expect(result, equals('tasks.notifications.reminder_title')); // Should return key
      });
    });
  });
}
