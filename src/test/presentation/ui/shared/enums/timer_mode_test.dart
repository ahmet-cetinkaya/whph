import 'package:flutter_test/flutter_test.dart';
import 'package:whph/presentation/ui/shared/enums/timer_mode.dart';

void main() {
  group('TimerMode', () {
    test('should have correct values', () {
      expect(TimerMode.normal.value, equals('normal'));
      expect(TimerMode.pomodoro.value, equals('pomodoro'));
      expect(TimerMode.stopwatch.value, equals('stopwatch'));
    });

    test('should parse from string correctly', () {
      expect(TimerMode.fromString('normal'), equals(TimerMode.normal));
      expect(TimerMode.fromString('pomodoro'), equals(TimerMode.pomodoro));
      expect(TimerMode.fromString('stopwatch'), equals(TimerMode.stopwatch));
    });

    test('should default to pomodoro for unknown values', () {
      expect(TimerMode.fromString('invalid'), equals(TimerMode.pomodoro));
      expect(TimerMode.fromString(''), equals(TimerMode.pomodoro));
    });
  });
}