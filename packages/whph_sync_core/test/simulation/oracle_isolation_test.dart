import 'dart:io';

import 'package:test/test.dart';

/// The reference oracle must stay independent of the implementation under
/// test: no file under `test/simulation/oracle/` may import, export or `part`
/// anything from `package:whph_sync_core/src/` (or reach `lib/src/` by path).
final _forbiddenDirective = RegExp(
  r'''^\s*(import|export|part)\s+['"]([^'"]*(package:whph_sync_core/src/|lib/src/)[^'"]*)['"]''',
  multiLine: true,
);

/// Forbidden URIs referenced by [source].
List<String> forbiddenImports(String source) => [for (final m in _forbiddenDirective.allMatches(source)) m.group(2)!];

void main() {
  test('the detector flags src imports and accepts others', () {
    expect(forbiddenImports("import 'package:whph_sync_core/src/store/replica_store.dart';"), hasLength(1));
    expect(forbiddenImports('export "package:whph_sync_core/src/x.dart" show Y;'), hasLength(1));
    expect(forbiddenImports("import '../../../lib/src/store/replica_store.dart';"), hasLength(1));
    expect(forbiddenImports("import 'package:whph_sync_core/whph_sync_core.dart';"), isEmpty);
    expect(forbiddenImports("import 'oracle_hlc.dart';\n// package:whph_sync_core/src/ in a comment"), isEmpty);
  });

  test('no oracle file imports package:whph_sync_core/src/', () {
    final dir = Directory('test/simulation/oracle');
    expect(dir.existsSync(), isTrue, reason: 'run from the package root');
    final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
    expect(files, isNotEmpty);
    final offenders = <String>[];
    for (final file in files) {
      for (final uri in forbiddenImports(file.readAsStringSync())) {
        offenders.add('${file.path}: $uri');
      }
    }
    expect(offenders, isEmpty, reason: 'the oracle must stay independent of the engine under test');
  });
}
