import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/shared/utils/group_key_result.dart';

void main() {
  group('GroupKeyResult', () {
    test('recognized carries its value (non-null)', () {
      const result = Recognized<int>(42);
      expect(result, isA<GroupKeyResult<int>>());
      expect(result, isA<Recognized<int>>());
      expect(result.value, 42);
    });

    test('recognized may carry a null value for "no value" groups', () {
      const result = Recognized<DateTime?>(null);
      expect(result, isA<GroupKeyResult<DateTime?>>());
      expect(result, isA<Recognized<DateTime?>>());
      expect(result.value, isNull);
    });

    test('unrecognized carries no value', () {
      const result = Unrecognized<String>();
      expect(result, isA<GroupKeyResult<String>>());
      expect(result, isA<Unrecognized<String>>());
    });

    test('factory constructors produce the concrete subtypes', () {
      final GroupKeyResult<int> r1 = GroupKeyResult.recognized(1);
      final GroupKeyResult<int> r2 = GroupKeyResult.unrecognized();
      expect(r1, isA<Recognized<int>>());
      expect((r1 as Recognized<int>).value, 1);
      expect(r2, isA<Unrecognized<int>>());
    });

    test('recognized and unrecognized are exhaustive over GroupKeyResult', () {
      const GroupKeyResult<int> a = Recognized<int>(1);
      const GroupKeyResult<int> b = Unrecognized<int>();
      final values = [a, b];
      for (final v in values) {
        switch (v) {
          case Recognized(:final value):
            expect(value, isA<int>());
          case Unrecognized():
            // Empty payload; nothing to assert.
            expect(true, isTrue);
        }
      }
    });
  });
}
