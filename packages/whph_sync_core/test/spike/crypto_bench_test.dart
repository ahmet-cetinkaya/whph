// S4 spike: crypto throughput benchmark (numbers only, `[S4]`-prefixed).
//
// Tagged `spike-bench` and skipped in the default package run (see
// dart_test.yaml). Run it with:
//   fvm dart test -P spike-bench test/spike/crypto_bench_test.dart
// Override the end-to-end sample size with S4_BENCH_N (default 20000).
@Tags(['spike-bench'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:whph_sync_core/spike.dart';

void main() {
  test('S4 crypto throughput', () async {
    final n = int.tryParse(Platform.environment['S4_BENCH_N'] ?? '') ?? 20000;
    final result = await runCryptoBench(CryptoBenchConfig(changes: n));
    for (final line in result.toLines()) {
      // ignore: avoid_print
      print(line);
    }
    expect(result.metrics['e2e_changes'], n);
    expect(result.metrics['projected_seconds'], greaterThan(0));
  });
}
