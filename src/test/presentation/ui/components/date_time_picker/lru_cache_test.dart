import 'package:flutter_test/flutter_test.dart';
import 'package:acore/utils/lru_cache.dart';

void main() {
  group('LRUCache Tests', () {
    late LRUCache<String, String> cache;

    setUp(() {
      cache = LRUCache<String, String>(3);
    });

    test('LRUCache stores and retrieves values correctly', () {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2');

      expect(cache.get('key1'), equals('value1'));
      expect(cache.get('key2'), equals('value2'));
      expect(cache.get('nonexistent'), isNull);
    });

    test('LRUCache respects size limits and evicts least recently used items', () {
      // Fill cache to capacity
      cache.put('key1', 'value1');
      cache.put('key2', 'value2');
      cache.put('key3', 'value3');

      expect(cache.length, equals(3));

      // Access key1 to make it most recently used
      cache.get('key1');

      // Add new item, should evict key2 (least recently used)
      cache.put('key4', 'value4');

      expect(cache.length, equals(3));
      expect(cache.get('key1'), equals('value1')); // Still exists (was accessed)
      expect(cache.get('key2'), isNull); // Evicted
      expect(cache.get('key3'), equals('value3'));
      expect(cache.get('key4'), equals('value4'));
    });

    test('LRUCache updates existing items', () {
      cache.put('key1', 'value1');
      cache.put('key1', 'updated_value1');

      expect(cache.get('key1'), equals('updated_value1'));
      expect(cache.length, equals(1));
    });

    test('LRUCache handles containsKey correctly', () {
      expect(cache.containsKey('key1'), isFalse);

      cache.put('key1', 'value1');
      expect(cache.containsKey('key1'), isTrue);

      cache.remove('key1');
      expect(cache.containsKey('key1'), isFalse);
    });

    test('LRUCache removes items correctly', () {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2');

      expect(cache.remove('key1'), equals('value1'));
      expect(cache.get('key1'), isNull);
      expect(cache.length, equals(1));
      expect(cache.remove('nonexistent'), isNull);
    });

    test('LRUCache clears all items', () {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2');
      cache.put('key3', 'value3');

      expect(cache.length, equals(3));

      cache.clear();

      expect(cache.length, equals(0));
      expect(cache.isEmpty, isTrue);
      expect(cache.get('key1'), isNull);
    });

    test('LRUCache provides correct statistics', () {
      expect(cache.isEmpty, isTrue);
      expect(cache.isFull, isFalse);

      cache.put('key1', 'value1');
      expect(cache.stats.size, equals(1));
      expect(cache.stats.utilizationRatio, closeTo(0.33, 0.01));

      cache.put('key2', 'value2');
      cache.put('key3', 'value3');

      expect(cache.isFull, isTrue);
      expect(cache.stats.utilizationRatio, equals(1.0));
    });

    test('LRUCache handles complex access patterns', () {
      // Fill cache
      cache.put('a', '1');
      cache.put('b', '2');
      cache.put('c', '3');

      // Access pattern: a, b, a, c, d
      cache.get('a'); // a becomes most recent
      cache.get('b'); // b becomes most recent
      cache.get('a'); // a becomes most recent again
      cache.get('c'); // c becomes most recent
      cache.put('d', '4'); // Should evict b (least recent)

      expect(cache.get('a'), equals('1'));
      expect(cache.get('b'), isNull); // Evicted
      expect(cache.get('c'), equals('3'));
      expect(cache.get('d'), equals('4'));
    });

    test('LRUCache works with different key/value types', () {
      final intCache = LRUCache<int, DateTime>(2);

      final now = DateTime.now();
      intCache.put(1, now);
      intCache.put(2, now.add(const Duration(days: 1)));

      expect(intCache.get(1), equals(now));
      expect(intCache.length, equals(2));
    });

    test('LRUCache handles edge cases gracefully', () {
      // Test with cache size of 1
      final singleItemCache = LRUCache<String, String>(1);
      singleItemCache.put('key1', 'value1');
      expect(singleItemCache.get('key1'), equals('value1'));

      singleItemCache.put('key2', 'value2');
      expect(singleItemCache.get('key1'), isNull);
      expect(singleItemCache.get('key2'), equals('value2'));

      // Test empty cache operations
      expect(singleItemCache.remove('nonexistent'), isNull);
      expect(singleItemCache.isEmpty, isFalse);

      singleItemCache.clear();
      expect(singleItemCache.isEmpty, isTrue);
    });

    group('LRUCache Performance Tests', () {
      test('LRUCache operations complete efficiently', () {
        final largeCache = LRUCache<int, String>(1000);
        final stopwatch = Stopwatch()..start();

        // Add 1000 items
        for (int i = 0; i < 1000; i++) {
          largeCache.put(i, 'value$i');
        }

        stopwatch.stop();

        // Should complete within reasonable time (less than 100ms)
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
        expect(largeCache.length, equals(1000));
        expect(largeCache.isFull, isTrue);
      });

      test('LRUCache handles rapid access patterns efficiently', () {
        final cache = LRUCache<int, int>(100);
        final stopwatch = Stopwatch()..start();

        // Fill cache
        for (int i = 0; i < 100; i++) {
          cache.put(i, i * 2);
        }

        // Rapid access pattern
        for (int i = 0; i < 1000; i++) {
          final key = i % 100;
          final value = cache.get(key);
          expect(value, equals(key * 2));
        }

        stopwatch.stop();

        // Should complete within reasonable time (less than 50ms)
        expect(stopwatch.elapsedMilliseconds, lessThan(50));
      });
    });
  });
}
