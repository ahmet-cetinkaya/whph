import 'package:flutter_test/flutter_test.dart';
import 'package:whph/presentation/ui/shared/utils/error_report_formatter.dart';

void main() {
  group('describeError', () {
    test('names the runtime type of a null check failure', () {
      // Reproduces the production report "Null check operator used on a null
      // value", which arrived with no indication it was a TypeError.
      Object? captured;
      try {
        final Object? value = null;
        value!.toString();
      } catch (e) {
        captured = e;
      }

      final described = describeError(captured);

      expect(described, contains('Null check operator used on a null value'));
      expect(described, contains('TypeError'));
    });

    test('does not disguise an Error as an Exception', () {
      final described = describeError(StateError('boom'));

      expect(described, isNot(startsWith('Exception:')));
      expect(described, contains('boom'));
    });

    test('keeps the type of a plain exception', () {
      final described = describeError(FormatException('bad input'));

      expect(described, contains('FormatException'));
      expect(described, contains('bad input'));
    });

    test('reports a placeholder for a null error', () {
      expect(describeError(null), 'Unknown error');
    });
  });

  group('describeStackTrace', () {
    test('marks a missing trace instead of writing nothing', () {
      expect(describeStackTrace(null), noStackTraceMarker);
    });

    test('marks an empty trace instead of writing nothing', () {
      expect(describeStackTrace(StackTrace.empty), noStackTraceMarker);
    });

    test('keeps a short trace verbatim', () {
      final trace = StackTrace.fromString('#0 first\n#1 second');

      expect(describeStackTrace(trace), '#0 first\n#1 second');
    });

    test('truncates a long trace but keeps the frames nearest the failure', () {
      final frames = List.generate(120, (i) => '#$i frame');
      final trace = StackTrace.fromString(frames.join('\n'));

      final described = describeStackTrace(trace);

      expect(described, contains('#0 frame'));
      expect(described, contains('#49 frame'));
      expect(described, isNot(contains('#50 frame')));
      expect(described, contains('70 more frame(s) omitted'));
    });
  });
}
