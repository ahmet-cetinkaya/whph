/// Generates the synthetic schema-v37 sync fixtures (plan T2).
///
/// Usage (from `src/`):
/// ```
/// fvm dart run test/fixtures/sync/generate_fixtures.dart --out <dir> [--seed <int>] [--only <name>[,<name>...]]
/// ```
///
/// Fixtures: large_usage, duplicates, duplicates_shuffled, empty, large_realistic. Output is
/// `<dir>/<name>.sqlite` (+ `<name>.manifest.json` for the duplicates
/// fixtures). Synthetic data only; do not commit the generated files.
library;

import 'dart:io';

import 'package:crypto/crypto.dart';

import 'fixture_builder.dart';

Future<void> main(List<String> args) async {
  String? out;
  var seed = defaultFixtureSeed;
  var names = fixtureNames;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    String value() {
      if (i + 1 >= args.length) _usage('Missing value for $arg');
      return args[++i];
    }

    switch (arg) {
      case '--out':
        out = value();
      case '--seed':
        final parsed = int.tryParse(value());
        if (parsed == null) _usage('--seed must be an integer');
        seed = parsed;
      case '--only':
        names = value().split(',').map((n) => n.trim()).where((n) => n.isNotEmpty).toList();
        final unknown = names.where((n) => !fixtureNames.contains(n)).toList();
        if (unknown.isNotEmpty) _usage('Unknown fixture(s): ${unknown.join(', ')}');
      case '-h' || '--help':
        _usage(null);
      default:
        _usage('Unknown argument: $arg');
    }
  }
  if (out == null) _usage('--out is required');

  final outDir = Directory(out);
  stdout.writeln('Generating ${names.join(', ')} (seed $seed) into ${outDir.absolute.path}');
  for (final name in names) {
    final result = await buildFixture(name, seed: seed, out: outDir);
    final digest = sha256.convert(result.database.readAsBytesSync());
    stdout.writeln('$name: ${result.totalRows} rows, ${result.elapsed.inMilliseconds} ms, '
        'sha256 $digest, ${result.database.path}${result.manifest != null ? ' (+ ${result.manifest!.path})' : ''}');
  }
}

Never _usage(String? error) {
  if (error != null) stderr.writeln('error: $error');
  (error == null ? stdout : stderr).writeln(
    'Usage: fvm dart run test/fixtures/sync/generate_fixtures.dart --out <dir> '
    '[--seed <int>] [--only <name>[,<name>...]]\n'
    'Fixtures: ${fixtureNames.join(', ')}. Default seed: $defaultFixtureSeed.',
  );
  exit(error == null ? 0 : 64);
}
